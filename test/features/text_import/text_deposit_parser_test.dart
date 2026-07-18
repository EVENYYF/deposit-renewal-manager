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
    final commaAmount = parser.parse('王五 13700137000 建行 100,000元 12个月');

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
    final days = parser.parse('30日存期');
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
}
