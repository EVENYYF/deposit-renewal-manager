import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/features/statistics/application/deposit_statistics.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'excludes renewed principal and groups current active deposits',
    () async {
      await _addCustomer(database, 'c1', '王芳');
      await _addCustomer(database, 'c2', '李明');

      await _addDeposit(
        database,
        id: 'renewed-source',
        customerId: 'c1',
        amountCents: 100000,
        bank: '建设银行',
        product: '稳健一年',
        expiry: '2026-07-19',
        lifecycle: 'renewed',
      );
      await _addDeposit(
        database,
        id: 'renewed-target',
        customerId: 'c1',
        amountCents: 120000,
        bank: '建设银行',
        product: '稳健一年',
        expiry: '2027-07-20',
      );
      await _addDeposit(
        database,
        id: 'overdue',
        customerId: 'c1',
        amountCents: 50000,
        bank: '建设银行',
        product: '通知存款',
        expiry: '2026-07-19',
      );
      await _addDeposit(
        database,
        id: 'stopped',
        customerId: 'c2',
        amountCents: 70000,
        bank: '工商银行',
        product: '已停产品',
        expiry: '2027-07-20',
        lifecycle: 'stopped',
      );
      await _addDeposit(
        database,
        id: 'active',
        customerId: 'c2',
        amountCents: 30000,
        bank: '工商银行',
        product: '',
        expiry: '2027-07-20',
      );
      await database
          .into(database.renewals)
          .insert(
            RenewalsCompanion.insert(
              id: 'r1',
              sourceDepositId: 'renewed-source',
              targetDepositId: 'renewed-target',
              renewedAtUtc: _epoch,
              sourceDeviceId: 'test',
            ),
          );

      final snapshot = await SqliteDepositStatisticsUseCases(
        database,
      ).load(now: DateTime(2026, 7, 20));

      expect(snapshot.totalCount, 4);
      expect(snapshot.activeCount, 2);
      expect(snapshot.overdueCount, 1);
      expect(snapshot.renewedCount, 1);
      expect(snapshot.stoppedCount, 1);
      expect(snapshot.currentPrincipalCents, 200000);
      expect(snapshot.customerCount, 2);
      expect(snapshot.renewalCount, 1);
      expect(
        snapshot.byBank.map((row) => (row.name, row.amountCents)).toList(),
        [('建设银行', 170000), ('工商银行', 30000)],
      );
      expect(snapshot.byProduct.map((row) => row.name), ['稳健一年', '通知存款', '']);
      expect(snapshot.byBank.first.depositCount, 2);
      expect(snapshot.byBank.first.customerCount, 1);
    },
  );

  test('returns zero values and empty breakdowns without deposits', () async {
    final snapshot = await SqliteDepositStatisticsUseCases(database).load();

    expect(snapshot.totalCount, 0);
    expect(snapshot.currentPrincipalCents, 0);
    expect(snapshot.byBank, isEmpty);
    expect(snapshot.byProduct, isEmpty);
  });

  test(
    'loads active detail rows with stable sorting and empty categories',
    () async {
      await _addCustomer(database, 'c1', '王芳', phone: '13800000001');
      await _addCustomer(database, 'c2', '李明', phone: '13800000002');
      await _addCustomer(database, 'c3', '停用客户', isActive: false);
      await _addDeposit(
        database,
        id: 'd2',
        customerId: 'c1',
        amountCents: 20000,
        bank: '建设银行',
        product: '产品二',
        expiry: '2027-01-02',
      );
      await _addDeposit(
        database,
        id: 'd1',
        customerId: 'c2',
        amountCents: 10000,
        bank: '建设银行',
        product: '产品一',
        expiry: '2027-01-01',
      );
      await _addDeposit(
        database,
        id: 'd0',
        customerId: 'c2',
        amountCents: 30000,
        bank: '建设银行',
        product: '',
        expiry: '2027-01-01',
      );
      await _addDeposit(
        database,
        id: 'stopped',
        customerId: 'c1',
        amountCents: 40000,
        bank: '建设银行',
        product: '停用产品',
        expiry: '2027-01-01',
        lifecycle: 'stopped',
      );
      await _addDeposit(
        database,
        id: 'inactive-customer',
        customerId: 'c3',
        amountCents: 50000,
        bank: '建设银行',
        product: '停用客户产品',
        expiry: '2027-01-01',
      );

      final useCases = SqliteDepositStatisticsUseCases(database);
      final bankRows = await useCases.loadDetails(
        DepositStatisticsDimension.bank,
        '建设银行',
      );
      final emptyProductRows = await useCases.loadDetails(
        DepositStatisticsDimension.product,
        '',
      );

      expect(bankRows.map((row) => row.depositId), ['d0', 'd1', 'd2']);
      expect(bankRows.first.customerName, '李明');
      expect(bankRows.first.customerPhone, '13800000002');
      expect(bankRows.first.amountCents, 30000);
      expect(bankRows.first.interestRateScaled, 200);
      expect(bankRows.first.ratePrecision, 2);
      expect(bankRows.first.expiryDate, '2027-01-01');
      expect(emptyProductRows.map((row) => row.depositId), ['d0']);
    },
  );
}

const _epoch = 1784515200000000;

Future<void> _addCustomer(
  AppDatabase database,
  String id,
  String name, {
  String? phone,
  bool isActive = true,
}) => database
    .into(database.customers)
    .insert(
      CustomersCompanion.insert(
        id: id,
        name: name,
        phone: Value(phone),
        isActive: Value(isActive),
        createdAtUtc: _epoch,
        updatedAtUtc: _epoch,
      ),
    );

Future<void> _addDeposit(
  AppDatabase database, {
  required String id,
  required String customerId,
  required int amountCents,
  required String bank,
  required String product,
  required String expiry,
  String lifecycle = 'active',
}) => database
    .into(database.deposits)
    .insert(
      DepositsCompanion.insert(
        id: id,
        customerId: customerId,
        amountCents: amountCents,
        bankName: Value(bank),
        productName: Value(product),
        interestRateScaled: 200,
        ratePrecision: 2,
        startDate: '2026-01-01',
        finalExpiryDate: expiry,
        lifecycle: lifecycle,
        createdAtUtc: _epoch,
        updatedAtUtc: _epoch,
        sourceDeviceId: 'test',
      ),
    );
