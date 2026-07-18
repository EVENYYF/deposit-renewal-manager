import '../../deposits/domain/expiry_calculator.dart';
import '../../deposits/domain/local_date.dart';
import 'package:decimal/decimal.dart';

enum ParseField {
  name,
  phone,
  amount,
  bank,
  product,
  interestRate,
  depositDate,
  expiryDate,
  term,
}

final class ParseCandidate {
  const ParseCandidate({
    required this.field,
    required this.value,
    required this.source,
    required this.confidence,
    required this.sourceStart,
    required this.sourceEnd,
    this.error,
  });

  final ParseField field;
  final Object? value;
  final String source;
  final double confidence;
  final int sourceStart;
  final int sourceEnd;
  final String? error;

  bool get isValid => error == null && value != null;
}

final class ParseConflict {
  const ParseConflict({required this.field, required this.candidates});

  final ParseField field;
  final List<ParseCandidate> candidates;
}

final class ParseResult {
  const ParseResult({
    required this.original,
    required this.candidates,
    required this.conflicts,
    required this.remainingText,
  });

  final String original;
  final List<ParseCandidate> candidates;
  final List<ParseConflict> conflicts;
  final String remainingText;

  String? get name => _value<String>(ParseField.name);
  String? get phone => _value<String>(ParseField.phone);
  int? get amountCents => _value<int>(ParseField.amount);
  String? get bank => _value<String>(ParseField.bank);
  String? get product => _value<String>(ParseField.product);
  double? get interestRatePercent => _value<double>(ParseField.interestRate);
  LocalDate? get depositDate => _value<LocalDate>(ParseField.depositDate);
  LocalDate? get expiryDate => _value<LocalDate>(ParseField.expiryDate);
  DepositTerm? get term => _value<DepositTerm>(ParseField.term);

  T? _value<T>(ParseField field) {
    if (conflicts.any((conflict) => conflict.field == field)) return null;
    for (final candidate in candidates) {
      if (candidate.field == field && candidate.isValid) {
        return candidate.value as T;
      }
    }
    return null;
  }
}

final class TextDepositParser {
  ParseResult parse(String source) {
    final normalized = _normalize(source);
    final located = <_LocatedCandidate>[];

    _extractPhones(source, normalized, located);
    _extractDates(source, normalized, located);
    _extractAmounts(source, normalized, located);
    _extractInterestRates(source, normalized, located);
    _extractTerms(source, normalized, located);
    _extractBanks(source, normalized, located);
    _extractProducts(source, normalized, located);
    _extractNames(source, normalized, located);

    located.sort((left, right) => left.start.compareTo(right.start));
    final candidates = List<ParseCandidate>.unmodifiable(
      located.map((item) => item.candidate),
    );
    return ParseResult(
      original: source,
      candidates: candidates,
      conflicts: List<ParseConflict>.unmodifiable(_findConflicts(candidates)),
      remainingText: _remainingText(source, located),
    );
  }

  static String _normalize(String source) {
    final result = StringBuffer();
    for (final rune in source.runes) {
      if (rune == 0x3000) {
        result.write(' ');
      } else if (rune >= 0xff01 && rune <= 0xff5e) {
        result.writeCharCode(rune - 0xfee0);
      } else {
        result.writeCharCode(rune);
      }
    }
    return result.toString();
  }

  static void _extractPhones(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final labeledPattern = RegExp(
      r'(?:联系电话|手机号码|手机号|手机|电话)\s*[:：]?\s*'
      r'(1[3-9]\d(?:[ -]?\d){8})(?![ -]?\d)',
    );
    for (final match in labeledPattern.allMatches(normalized)) {
      final value = match.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
      _add(output, source, match.start, match.end, ParseField.phone, value, 1);
    }

    final invalidLabeledPattern = RegExp(
      r'(?:联系电话|手机号码|手机号|手机|电话)\s*[:：]?\s*'
      r'([^\s，。；;]+)',
    );
    for (final match in invalidLabeledPattern.allMatches(normalized)) {
      if (_overlapsAny(match.start, match.end, output)) continue;
      _add(
        output,
        source,
        match.start,
        match.end,
        ParseField.phone,
        null,
        0,
        error: '无效手机号：${source.substring(match.start, match.end).trim()}',
      );
    }

    final unlabelledPattern = RegExp(r'1[3-9]\d(?:[ -]?\d){8}');
    for (final match in unlabelledPattern.allMatches(normalized)) {
      if (_overlapsAny(match.start, match.end, output) ||
          _hasAsciiAlphaNumericAt(normalized, match.start - 1) ||
          _hasAsciiAlphaNumericAt(normalized, match.end)) {
        continue;
      }
      final value = match.group(0)!.replaceAll(RegExp(r'[ -]'), '');
      _add(output, source, match.start, match.end, ParseField.phone, value, 1);
    }
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  static bool _hasAsciiAlphaNumericAt(String value, int index) {
    if (index < 0 || index >= value.length) return false;
    final codeUnit = value.codeUnitAt(index);
    return _isDigit(codeUnit) ||
        (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a);
  }

  static void _extractDates(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final pattern = RegExp(
      r'(?:(存入日|存款日|存日|到期日|到期)\s*[:：]?\s*)?'
      r'(\d{4})\s*(年|[-/.])\s*(\d{1,2})\s*(月|[-/.])\s*'
      r'(\d{1,2})(?:\s*(?:日|号))?(存入|存|到期)?',
    );
    for (final match in pattern.allMatches(normalized)) {
      final prefix = match.group(1);
      final suffix = match.group(7);
      final field = (prefix?.contains('到期') ?? false) || suffix == '到期'
          ? ParseField.expiryDate
          : ParseField.depositDate;
      final year = int.parse(match.group(2)!);
      final month = int.parse(match.group(4)!);
      final day = int.parse(match.group(6)!);
      LocalDate? value;
      String? error;
      try {
        value = LocalDate(year, month, day);
      } on ArgumentError {
        error = '无效日期：${source.substring(match.start, match.end).trim()}';
      }
      _add(
        output,
        source,
        match.start,
        match.end,
        field,
        value,
        error == null ? 0.98 : 0,
        error: error,
      );
    }
  }

  static void _extractAmounts(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final contextualPattern = RegExp(
      r'(?:金额|本金|存款|定期)\s*[:：]?\s*'
      r'([^\s，。；;]+?)\s*(万元|万|元)',
    );
    for (final match in contextualPattern.allMatches(normalized)) {
      _addAmountCandidate(source, match, output);
    }

    final barePattern = RegExp(r'(\d[\d,]*(?:\.\d+)?)\s*(万元|万|元)');
    for (final match in barePattern.allMatches(normalized)) {
      if (_overlapsAny(match.start, match.end, output)) continue;
      if (!_hasStrictTokenBoundary(normalized, match.start, match.end)) {
        continue;
      }
      _addAmountCandidate(source, match, output);
    }
  }

  static void _addAmountCandidate(
    String source,
    RegExpMatch match,
    List<_LocatedCandidate> output,
  ) {
    final numberToken = match.group(1)!;
    final unit = match.group(2)!;
    final cents = _parseAmountCents(numberToken, unit);
    _add(
      output,
      source,
      match.start,
      match.end,
      ParseField.amount,
      cents,
      cents == null ? 0 : 0.98,
      error: cents == null
          ? '无效金额：${source.substring(match.start, match.end).trim()}'
          : null,
    );
  }

  static int? _parseAmountCents(String token, String unit) {
    final lexical = RegExp(
      r'^(?:(?:0|[1-9]\d*)|(?:[1-9]\d{0,2}(?:,\d{3})+))'
      r'(?:\.(\d+))?$',
    ).firstMatch(token);
    if (lexical == null) return null;

    final scale = unit.startsWith('万') ? 6 : 2;
    final pieces = token.replaceAll(',', '').split('.');
    final whole = pieces.first;
    final fraction = pieces.length == 1 ? '' : pieces[1];
    if (fraction.length > scale &&
        fraction.substring(scale).contains(RegExp('[1-9]'))) {
      return null;
    }
    final scaledFraction = fraction.length >= scale
        ? fraction.substring(0, scale)
        : fraction.padRight(scale, '0');
    final value = BigInt.parse('$whole$scaledFraction');
    if (value <= BigInt.zero || value > BigInt.from(0x7fffffffffffffff)) {
      return null;
    }
    return value.toInt();
  }

  static bool _hasStrictTokenBoundary(String value, int start, int end) {
    bool isSeparatorAt(int index) {
      if (index < 0 || index >= value.length) return true;
      return RegExp(r'[\s,，。；;:：]').hasMatch(value[index]);
    }

    return isSeparatorAt(start - 1) && isSeparatorAt(end);
  }

  static void _extractInterestRates(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final labeledPattern = RegExp(
      r'(?:年利率|利率)\s*[:：]?\s*([A-Za-z]+|[0-9][0-9.,]*%?)',
    );
    for (final match in labeledPattern.allMatches(normalized)) {
      _addInterestRateCandidate(source, match, output);
    }

    final barePattern = RegExp(r'(\d+(?:\.\d+)?)%');
    for (final match in barePattern.allMatches(normalized)) {
      if (_overlapsAny(match.start, match.end, output) ||
          !_hasStrictTokenBoundary(normalized, match.start, match.end)) {
        continue;
      }
      _addInterestRateCandidate(source, match, output);
    }
  }

  static void _addInterestRateCandidate(
    String source,
    RegExpMatch match,
    List<_LocatedCandidate> output,
  ) {
    final token = match.group(1)!;
    final numeric = token.endsWith('%')
        ? token.substring(0, token.length - 1)
        : token;
    final decimal = Decimal.tryParse(numeric);
    final valid =
        decimal != null &&
        decimal > Decimal.zero &&
        decimal <= Decimal.fromInt(100);
    _add(
      output,
      source,
      match.start,
      match.end,
      ParseField.interestRate,
      valid ? decimal.toDouble() : null,
      valid ? 0.98 : 0,
      error: valid
          ? null
          : '无效利率：${source.substring(match.start, match.end).trim()}',
    );
  }

  static void _extractTerms(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final pattern = RegExp(
      r'(?:存期|期限|定期|存(?!入|款|期|日))\s*[:：]?\s*'
      r'([^\s，。；;]+?)\s*(天|日|个月|月|年)(?:存期)?',
    );
    for (final match in pattern.allMatches(normalized)) {
      final token = match.group(1)!;
      final unit = match.group(2)!;
      final count = RegExp(r'^\d+$').hasMatch(token)
          ? int.tryParse(token)
          : null;
      final limit = switch (unit) {
        '天' || '日' => 3650,
        '个月' || '月' => 120,
        _ => 30,
      };
      final valid = count != null && count >= 1 && count <= limit;
      final term = valid
          ? switch (unit) {
              '天' || '日' => DepositTerm.days(count),
              '个月' || '月' => DepositTerm.months(count),
              _ => DepositTerm.years(count),
            }
          : null;
      _add(
        output,
        source,
        match.start,
        match.end,
        ParseField.term,
        term,
        valid ? 0.96 : 0,
        error: valid
            ? null
            : '无效存期：${source.substring(match.start, match.end).trim()}',
      );
    }

    final invalidLabeledPattern = RegExp(
      r'(?:存期|期限|定期|存(?!入|款|期|日))\s*[:：]?\s*'
      r'([^\s，。；;]+)',
    );
    for (final match in invalidLabeledPattern.allMatches(normalized)) {
      if (_overlapsField(match.start, match.end, output, ParseField.term) ||
          _overlapsField(match.start, match.end, output, ParseField.amount)) {
        continue;
      }
      _add(
        output,
        source,
        match.start,
        match.end,
        ParseField.term,
        null,
        0,
        error: '无效存期：${source.substring(match.start, match.end).trim()}',
      );
    }
  }

  static const _bankAliases = <String, String>{
    '中国工商银行': '工商银行',
    '工商银行': '工商银行',
    '工行': '工商银行',
    '中国农业银行': '农业银行',
    '农业银行': '农业银行',
    '农行': '农业银行',
    '中国建设银行': '建设银行',
    '建设银行': '建设银行',
    '建行': '建设银行',
    '中国银行': '中国银行',
    '中行': '中国银行',
    '交通银行': '交通银行',
    '交行': '交通银行',
    '中国邮政储蓄银行': '邮政储蓄银行',
    '邮政储蓄银行': '邮政储蓄银行',
    '邮储银行': '邮政储蓄银行',
    '邮储': '邮政储蓄银行',
    '招商银行': '招商银行',
    '招行': '招商银行',
    '兴业银行': '兴业银行',
    '兴业': '兴业银行',
    '浦发银行': '浦发银行',
    '浦发': '浦发银行',
    '民生银行': '民生银行',
    '民生': '民生银行',
    '光大银行': '光大银行',
    '光大': '光大银行',
    '平安银行': '平安银行',
    '平安': '平安银行',
    '广发银行': '广发银行',
    '广发': '广发银行',
  };

  static void _extractBanks(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final aliases = _bankAliases.keys.toList()
      ..sort((left, right) => right.length.compareTo(left.length));
    final pattern = RegExp(aliases.map(RegExp.escape).join('|'));
    for (final match in pattern.allMatches(normalized)) {
      if (_overlapsField(match.start, match.end, output, ParseField.bank)) {
        continue;
      }
      _add(
        output,
        source,
        match.start,
        match.end,
        ParseField.bank,
        _bankAliases[match.group(0)]!,
        0.97,
      );
    }
  }

  static void _extractProducts(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final pattern = RegExp(r'大额存单|结构性存款|定期存款|定期|活期');
    for (final match in pattern.allMatches(normalized)) {
      if (_overlapsField(match.start, match.end, output, ParseField.product)) {
        continue;
      }
      _add(
        output,
        source,
        match.start,
        match.end,
        ParseField.product,
        match.group(0) == '定期存款' ? '定期' : match.group(0),
        0.94,
      );
    }
  }

  static void _extractNames(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final labeledPattern = RegExp(
      r'(?:姓名|客户)\s*[:：]?\s*([\u4e00-\u9fff·]{2,8}?)'
      r'(?=\s*(?:联系电话|手机号|手机|电话|金额|本金|存款|年利率|利率|银行|产品|'
      r'存入日|到期日|存期|期限|姓名|客户|[,，;；。]|\d|$))',
    );
    var hasLabeledName = false;
    for (final labeled in labeledPattern.allMatches(normalized)) {
      hasLabeledName = true;
      _add(
        output,
        source,
        labeled.start,
        labeled.end,
        ParseField.name,
        labeled.group(1),
        0.99,
      );
    }
    if (hasLabeledName) return;

    final reserved = RegExp(r'^(存入日|存款日|到期日|金额|本金|利率|存期|期限|备注|定期|活期|到期联系)$');
    final leading = RegExp(
      r'^\s*([\u4e00-\u9fff·]{2,4})(?=\s|[,，;；:：]|\d)',
    ).firstMatch(normalized);
    if (leading == null) return;
    final word = leading.group(1)!;
    if (reserved.hasMatch(word) || _bankAliases.containsKey(word)) return;
    final start = leading.start + leading.group(0)!.indexOf(word);
    final end = start + word.length;
    if (_overlapsAny(start, end, output)) return;
    _add(output, source, start, end, ParseField.name, word, 0.72);
  }

  static List<ParseConflict> _findConflicts(List<ParseCandidate> candidates) {
    final conflicts = <ParseConflict>[];
    for (final field in ParseField.values) {
      final valid = candidates
          .where((candidate) => candidate.field == field && candidate.isValid)
          .toList();
      final keys = valid.map((candidate) => _valueKey(candidate.value)).toSet();
      if (keys.length > 1) {
        conflicts.add(
          ParseConflict(field: field, candidates: List.unmodifiable(valid)),
        );
      }
    }
    return conflicts;
  }

  static Object _valueKey(Object? value) => switch (value) {
    DayTerm(:final value) => 'days:$value',
    MonthTerm(:final value) => 'months:$value',
    YearTerm(:final value) => 'years:$value',
    _ => value ?? '<null>',
  };

  static String _remainingText(String source, List<_LocatedCandidate> located) {
    final consumed = List<bool>.filled(source.length, false);
    for (final item in located) {
      for (var index = item.start; index < item.end; index++) {
        consumed[index] = true;
      }
    }
    final remaining = StringBuffer();
    for (var index = 0; index < source.length; index++) {
      remaining.write(consumed[index] ? ' ' : source[index]);
    }
    return remaining.toString().replaceAll(RegExp(r'[\s，,。；;：:]+'), ' ').trim();
  }

  static bool _overlapsAny(
    int start,
    int end,
    List<_LocatedCandidate> candidates,
  ) => candidates.any((item) => start < item.end && end > item.start);

  static bool _overlapsField(
    int start,
    int end,
    List<_LocatedCandidate> candidates,
    ParseField field,
  ) => candidates.any(
    (item) =>
        item.candidate.field == field && start < item.end && end > item.start,
  );

  static void _add(
    List<_LocatedCandidate> output,
    String source,
    int start,
    int end,
    ParseField field,
    Object? value,
    double confidence, {
    String? error,
  }) {
    final candidate = ParseCandidate(
      field: field,
      value: value,
      source: source.substring(start, end).trim(),
      confidence: confidence,
      sourceStart: start,
      sourceEnd: end,
      error: error,
    );
    output.add(_LocatedCandidate(candidate, start, end));
  }
}

final class _LocatedCandidate {
  const _LocatedCandidate(this.candidate, this.start, this.end);

  final ParseCandidate candidate;
  final int start;
  final int end;
}
