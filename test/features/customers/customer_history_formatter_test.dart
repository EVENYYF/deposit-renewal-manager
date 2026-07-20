import 'package:deposit_renewal_manager/features/customers/application/customer_history_service.dart';
import 'package:deposit_renewal_manager/features/customers/presentation/customer_history_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats camel and snake case fields with Chinese values', () {
    final changes = CustomerHistoryFormatter.formatEntry(
      CustomerHistoryEntry(
        operation: 'update',
        occurredAt: DateTime(2026, 7, 20),
        beforeJson: '{"amountCents":100000,"lifecycle":"active"}',
        afterJson: '{"amountCents":125000,"lifecycle":"renewed"}',
      ),
    );

    expect(changes.map((change) => change.label), ['金额', '状态']);
    expect(changes.first.before, '¥1000.00');
    expect(changes.first.after, '¥1250.00');
    expect(changes.last.before, '生效中');
    expect(changes.last.after, '已续期');
  });

  test('formats rates, terms, dates and empty values', () {
    final changes = CustomerHistoryFormatter.formatEntry(
      CustomerHistoryEntry(
        operation: 'update',
        occurredAt: DateTime(2026, 7, 20),
        beforeJson:
            '{"interest_rate_scaled":215,"rate_precision":2,"term_unit":"month","start_date":"2026-01-01"}',
        afterJson:
            '{"interest_rate_scaled":225,"rate_precision":2,"term_unit":"year","start_date":"2026-02-01"}',
      ),
    );

    expect(changes.map((change) => change.label), ['年利率', '存入日期', '期限单位']);
    expect(changes.first.before, '2.15%');
    expect(changes.first.after, '2.25%');
    expect(changes[1].before, '2026-01-01');
    expect(changes[1].after, '2026-02-01');
    expect(changes[2].before, '个月');
    expect(changes[2].after, '年');
  });

  test('hides internal names for unknown fields and empty values', () {
    final changes = CustomerHistoryFormatter.formatEntry(
      CustomerHistoryEntry(
        operation: 'update',
        occurredAt: DateTime(2026, 7, 20),
        beforeJson: '{"newInternalField":null}',
        afterJson: '{"newInternalField":"value"}',
      ),
    );

    expect(changes.single.label, '其他字段');
    expect(changes.single.before, '未填写');
    expect(changes.single.after, 'value');
  });
}
