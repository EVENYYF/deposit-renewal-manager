import '../../deposits/domain/expiry_calculator.dart';
import '../../deposits/domain/local_date.dart';

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
    for (final match in RegExp(r'1[3-9]\d{9}').allMatches(normalized)) {
      if (_hasDigitAt(normalized, match.start - 1) ||
          _hasDigitAt(normalized, match.end)) {
        continue;
      }
      _add(
        output,
        source,
        match.start,
        match.end,
        ParseField.phone,
        match.group(0),
        1,
      );
    }
  }

  static bool _hasDigitAt(String value, int index) =>
      index >= 0 && index < value.length && _isDigit(value.codeUnitAt(index));

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

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
    final validPattern = RegExp(
      r'(?:(?:金额|本金)\s*[:：]?\s*)?(\d[\d,]*(?:\.\d+)?)\s*(万元|万|元)',
    );
    for (final match in validPattern.allMatches(normalized)) {
      final number = double.parse(match.group(1)!.replaceAll(',', ''));
      final multiplier = match.group(2)!.startsWith('万') ? 1000000 : 100;
      final cents = number * multiplier;
      final isValid = number > 0 && cents.isFinite && cents == cents.round();
      _add(
        output,
        source,
        match.start,
        match.end,
        ParseField.amount,
        isValid ? cents.round() : null,
        isValid ? 0.98 : 0,
        error: isValid
            ? null
            : '无效金额：${source.substring(match.start, match.end).trim()}',
      );
    }

    final invalidPattern = RegExp(
      r'(?:金额|本金)\s*[:：]?\s*([^\s，,。；;]+(?:万元|万|元))',
    );
    for (final match in invalidPattern.allMatches(normalized)) {
      if (_overlapsAny(match.start, match.end, output)) continue;
      _add(
        output,
        source,
        match.start,
        match.end,
        ParseField.amount,
        null,
        0,
        error: '无效金额：${source.substring(match.start, match.end).trim()}',
      );
    }
  }

  static void _extractInterestRates(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final pattern = RegExp(r'(?:(?:利率|年利率)\s*[:：]?\s*)?(\d+(?:\.\d+)?)\s*%');
    for (final match in pattern.allMatches(normalized)) {
      _add(
        output,
        source,
        match.start,
        match.end,
        ParseField.interestRate,
        double.parse(match.group(1)!),
        0.98,
      );
    }
  }

  static void _extractTerms(
    String source,
    String normalized,
    List<_LocatedCandidate> output,
  ) {
    final pattern = RegExp(
      r'(?:(?:存期|期限)\s*[:：]?\s*)?(\d+)\s*(天|日|个月|月|年)(?:存期)?',
    );
    for (final match in pattern.allMatches(normalized)) {
      if (_overlapsAny(match.start, match.end, output)) continue;
      final count = int.parse(match.group(1)!);
      if (count <= 0) continue;
      final unit = match.group(2)!;
      final term = switch (unit) {
        '天' || '日' => DepositTerm.days(count),
        '个月' || '月' => DepositTerm.months(count),
        _ => DepositTerm.years(count),
      };
      _add(output, source, match.start, match.end, ParseField.term, term, 0.96);
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
    final labeled = RegExp(
      r'(?:姓名|客户)\s*[:：]?\s*([\u4e00-\u9fff·]{2,8})',
    ).firstMatch(normalized);
    if (labeled != null) {
      _add(
        output,
        source,
        labeled.start,
        labeled.end,
        ParseField.name,
        labeled.group(1),
        0.99,
      );
      return;
    }

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
