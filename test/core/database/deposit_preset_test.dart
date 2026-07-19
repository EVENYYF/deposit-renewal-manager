import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/core/database/daos/deposit_dao.dart';
import 'package:deposit_renewal_manager/core/database/daos/deposit_preset_dao.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_preset_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await CustomerDao(
      database,
      sourceDeviceId: 'test',
    ).create(const CustomerDraft(id: 'customer-1', name: '王芳'));
  });

  tearDown(() => database.close());

  test('presets are unique per field and ordered newest first', () async {
    final presets = DepositPresetDao(database);
    final first = await presets.add(DepositPresetField.bank, '工商银行');
    final duplicate = await presets.add(DepositPresetField.bank, ' 工商银行 ');
    expect(duplicate.id, first.id);
    await presets.add(DepositPresetField.product, '整存整取');
    expect((await presets.list(DepositPresetField.bank)).map((e) => e.value), [
      '工商银行',
    ]);
    expect(
      (await presets.list(DepositPresetField.product)).single.value,
      '整存整取',
    );
  });

  test('successful product saves learn a local product candidate', () async {
    final deposits = DepositDao(
      database,
      sourceDeviceId: 'test',
      nowUtc: () => DateTime.utc(2026, 7, 20),
    );
    await deposits.create(
      DepositDraft(
        id: 'deposit-1',
        customerId: 'customer-1',
        amountCents: 100,
        productName: '整存整取',
        interestRateScaled: 200,
        ratePrecision: 2,
        termValue: 12,
        termUnit: DepositTermUnit.month,
        startDate: LocalDate(2026, 7, 20),
        calculatedExpiryDate: LocalDate(2027, 7, 20),
        finalExpiryDate: LocalDate(2027, 7, 20),
      ),
    );
    final row = await database.select(database.deposits).getSingle();
    expect(row.termValue, 12);
    expect(row.termUnit, 'month');
    expect(
      (await DepositPresetDao(
        database,
      ).list(DepositPresetField.product)).single.value,
      '整存整取',
    );
  });
}
