import 'package:deposit_renewal_manager/features/deposits/domain/expiry_calculator.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/text_import/application/parse_deposit_text.dart';
import 'package:deposit_renewal_manager/features/text_import/domain/text_deposit_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = TextDepositParser();

  test('extracts structured fields and preserves remaining text', () {
    final result = parser.parse(
      '张三 13800138000 工行 定期10万元 2026年7月18日存 '
      '1年 利率1.5% 到期联系',
    );

    expect(result.original, contains('张三'));
    expect(result.name, '张三');
    expect(result.phone, '13800138000');
    expect(result.amountCents, 10000000);
    expect(result.bank, '工商银行');
    expect(result.product, '定期');
    expect(result.interestRatePercent, 1.5);
    expect(result.depositDate, LocalDate(2026, 7, 18));
    expect(result.term, isA<YearTerm>());
    expect(result.term?.value, 1);
    expect(result.remainingText, contains('到期联系'));
    expect(result.candidates, isNotEmpty);
    expect(
      result.candidates.every(
        (candidate) =>
            candidate.source.isNotEmpty &&
            candidate.confidence >= 0 &&
            candidate.confidence <= 1,
      ),
      isTrue,
    );
  });

  test('normalizes full-width text and common amount/date formats', () {
    final fullWidth = parser.parse(
      '姓名：李四 手机：１３９００１３９０００ 金额：１０万元 '
      '存入日：２０２６／０７／１８ 到期日：２０２７．０７．１８',
    );
    final commaAmount = parser.parse('王五 13700137000 建行 100,000元 存期12个月');

    expect(fullWidth.name, '李四');
    expect(fullWidth.phone, '13900139000');
    expect(fullWidth.amountCents, 10000000);
    expect(fullWidth.depositDate, LocalDate(2026, 7, 18));
    expect(fullWidth.expiryDate, LocalDate(2027, 7, 18));
    expect(commaAmount.amountCents, 10000000);
    expect(commaAmount.term, isA<MonthTerm>());
    expect(commaAmount.term?.value, 12);
  });

  test('recognizes an unlabeled leading name separated by punctuation', () {
    final result = parser.parse('孙七，13500135000，中行，金额8万元');

    expect(result.name, '孙七');
    expect(result.phone, '13500135000');
    expect(result.bank, '中国银行');
  });

  test('recognizes day, month, and year terms', () {
    final days = parser.parse('存期30日');
    final months = parser.parse('存期12个月');
    final years = parser.parse('期限1年');

    expect(days.term, isA<DayTerm>());
    expect(days.term?.value, 30);
    expect(months.term, isA<MonthTerm>());
    expect(months.term?.value, 12);
    expect(years.term, isA<YearTerm>());
    expect(years.term?.value, 1);
  });

  test('reports distinct phone and amount candidates as conflicts', () {
    final result = parser.parse('张三 13800138000 13900139000 金额10万元，另记100,000元');

    expect(result.phone, isNull);
    expect(result.amountCents, 10000000);
    expect(
      result.conflicts.map((conflict) => conflict.field),
      contains(ParseField.phone),
    );
    expect(
      result.conflicts.map((conflict) => conflict.field),
      isNot(contains(ParseField.amount)),
      reason: '同值的不同金额写法不应产生冲突',
    );

    final amountConflict = parser.parse('金额10万元，复核金额20万元');
    expect(amountConflict.amountCents, isNull);
    expect(
      amountConflict.conflicts.map((conflict) => conflict.field),
      contains(ParseField.amount),
    );
  });

  test('preserves and marks invalid dates and amounts', () {
    final result = parser.parse('存入日2026年2月30日 金额abc元 备注待核对');
    final invalidDate = result.candidates.singleWhere(
      (candidate) => candidate.field == ParseField.depositDate,
    );
    final invalidAmount = result.candidates.singleWhere(
      (candidate) => candidate.field == ParseField.amount,
    );

    expect(result.depositDate, isNull);
    expect(invalidDate.source, contains('2026年2月30日'));
    expect(invalidDate.error, contains('无效日期'));
    expect(invalidAmount.source, contains('abc元'));
    expect(invalidAmount.error, contains('无效金额'));
    expect(result.remainingText, contains('备注待核对'));
  });

  test('application use case delegates without repository capability', () {
    final useCase = ParseDepositText(parser);
    final result = useCase('赵六 13600136000 农行 5万元');

    expect(result.name, '赵六');
    expect(result.bank, '农业银行');
  });

  group('strict amount parsing', () {
    test('converts yuan and ten-thousand-yuan decimals exactly', () {
      expect(parser.parse('金额0.29元').amountCents, 29);
      expect(parser.parse('存款0.29万元').amountCents, 290000);
      expect(parser.parse('定期0.000001万元').amountCents, 1);
    });

    test('requires financial context and validates lexical boundaries', () {
      expect(
        parser
            .parse('今天花了100元')
            .candidates
            .where((candidate) => candidate.field == ParseField.amount),
        isEmpty,
      );
      expect(parser.parse('定期10万元').amountCents, 10000000);
      expect(parser.parse('金额1,000元').amountCents, 100000);
    });

    test('preserves malformed grouping and fractional cents as errors', () {
      for (final source in ['金额1,,000元', '金额10,00元', '金额0.001元']) {
        final candidate = parser
            .parse(source)
            .candidates
            .singleWhere((item) => item.field == ParseField.amount);
        expect(candidate.value, isNull, reason: source);
        expect(candidate.error, contains('无效金额'), reason: source);
        expect(candidate.source, source, reason: source);
      }
    });
  });

  group('strict term parsing', () {
    test('requires explicit term context', () {
      for (final source in ['2026年计划', '7月回访', '2026年7月']) {
        expect(
          parser
              .parse(source)
              .candidates
              .where((candidate) => candidate.field == ParseField.term),
          isEmpty,
          reason: source,
        );
      }

      expect(parser.parse('存期3650日').term?.value, 3650);
      expect(parser.parse('期限120个月').term?.value, 120);
      expect(parser.parse('定期30日').term?.value, 30);
      expect(parser.parse('存30年').term?.value, 30);
    });

    test('marks zero, excessive, and non-numeric labeled terms invalid', () {
      for (final source in [
        '存期0日',
        '存期3651日',
        '期限121个月',
        '定期31年',
        '存期一年',
        '存期abc',
      ]) {
        final candidate = parser
            .parse(source)
            .candidates
            .singleWhere((item) => item.field == ParseField.term);
        expect(candidate.value, isNull, reason: source);
        expect(candidate.error, contains('无效存期'), reason: source);
        expect(candidate.source, source, reason: source);
      }
    });
  });

  group('strict identity and rate parsing', () {
    test('extracts every labeled name without consuming the next label', () {
      final result = parser.parse('姓名张三手机13800138000，客户李四电话13900139000');
      final names = result.candidates
          .where((candidate) => candidate.field == ParseField.name)
          .map((candidate) => candidate.value)
          .toList();

      expect(names, ['张三', '李四']);
      expect(result.name, isNull);
      expect(
        result.conflicts.map((conflict) => conflict.field),
        contains(ParseField.name),
      );
    });

    test(
      'normalizes formatted phones and rejects embedded or invalid tokens',
      () {
        expect(parser.parse('手机138 0013 8000').phone, '13800138000');
        expect(parser.parse('电话138-0013-8000').phone, '13800138000');
        expect(
          parser
              .parse('A13800138000B')
              .candidates
              .where((candidate) => candidate.field == ParseField.phone),
          isEmpty,
        );

        final invalid = parser
            .parse('手机12345')
            .candidates
            .singleWhere((candidate) => candidate.field == ParseField.phone);
        expect(invalid.value, isNull);
        expect(invalid.error, contains('无效手机号'));
        expect(invalid.source, '手机12345');

        final nonNumeric = parser
            .parse('手机abc')
            .candidates
            .singleWhere((candidate) => candidate.field == ParseField.phone);
        expect(nonNumeric.value, isNull);
        expect(nonNumeric.error, contains('无效手机号'));
      },
    );

    test('validates every labeled interest rate token', () {
      expect(parser.parse('利率0.29%').interestRatePercent, 0.29);
      for (final source in ['年利率abc', '利率0%', '利率999%']) {
        final candidate = parser
            .parse(source)
            .candidates
            .singleWhere((item) => item.field == ParseField.interestRate);
        expect(candidate.value, isNull, reason: source);
        expect(candidate.error, contains('无效利率'), reason: source);
        expect(candidate.source, source, reason: source);
      }
    });

    test('validates the complete labeled interest rate token', () {
      for (final source in ['利率1abc', '利率1.5%%', '利率-1%', '利率.5%']) {
        final candidate = parser
            .parse(source)
            .candidates
            .singleWhere((item) => item.field == ParseField.interestRate);
        expect(candidate.value, isNull, reason: source);
        expect(candidate.error, contains('无效利率'), reason: source);
        expect(candidate.source, source, reason: source);
      }
    });

    test('validates the complete labeled phone token', () {
      for (final source in ['手机13800138000A', '手机138 0013 800']) {
        final candidate = parser
            .parse(source)
            .candidates
            .singleWhere((item) => item.field == ParseField.phone);
        expect(candidate.value, isNull, reason: source);
        expect(candidate.error, contains('无效手机号'), reason: source);
        expect(candidate.source, source, reason: source);
      }
    });

    test(
      'keeps adjacent labeled mobile fields as separate complete tokens',
      () {
        for (final source in [
          '手机138--0013-8000电话13900139000',
          '手机138--0013-8000：电话13900139000',
        ]) {
          final phones = parser
              .parse(source)
              .candidates
              .where((item) => item.field == ParseField.phone)
              .toList();
          expect(phones, hasLength(2), reason: source);
          expect(phones[0].value, isNull, reason: source);
          expect(
            phones[0].source,
            startsWith('手机138--0013-8000'),
            reason: source,
          );
          expect(phones[1].value, '13900139000', reason: source);
        }
      },
    );

    test('uses the same mobile prefix rule for labeled and bare tokens', () {
      for (final source in ['手机11000000000', '12000000000']) {
        final candidate = parser
            .parse(source)
            .candidates
            .singleWhere((item) => item.field == ParseField.phone);
        expect(candidate.value, isNull, reason: source);
        expect(candidate.error, contains('无效手机号'), reason: source);
        expect(candidate.source, source, reason: source);
      }
    });

    test(
      'preserves repeated separators in the complete labeled phone token',
      () {
        for (final source in ['手机138--0013-8000', '手机138  0013 8000']) {
          final candidate = parser
              .parse(source)
              .candidates
              .singleWhere((item) => item.field == ParseField.phone);
          expect(candidate.value, isNull, reason: source);
          expect(candidate.error, contains('无效手机号'), reason: source);
          expect(candidate.source, source, reason: source);
        }
      },
    );
  });

  test('product phrases never produce invalid term candidates', () {
    for (final source in ['定期存款', '定期储蓄']) {
      expect(
        parser
            .parse(source)
            .candidates
            .where((candidate) => candidate.field == ParseField.term),
        isEmpty,
        reason: source,
      );
    }
    expect(parser.parse('定期存款').product, '定期');
  });
}
