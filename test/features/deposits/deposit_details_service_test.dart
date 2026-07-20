import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/core/database/daos/deposit_dao.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/application/deposit_details_service.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CustomerDao customers;
  late DepositDao deposits;
  late RepositoryDepositDetailsUseCases useCases;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    customers = CustomerDao(database, sourceDeviceId: 'test');
    deposits = DepositDao(database, sourceDeviceId: 'test');
    useCases = RepositoryDepositDetailsUseCases(deposits, customers);
  });

  tearDown(() => database.close());

  test('加载活跃存款详情并生成可编辑草稿', () async {
    await customers.create(
      const CustomerDraft(id: 'c1', name: '张三', phone: '13800000000'),
    );
    await deposits.create(_draft('d1'));

    final record = await useCases.load('d1');

    expect(record?.data.customerName, '张三');
    expect(record?.data.customerPhone, '13800000000');
    expect(record?.data.productName, '稳健一年');
    expect(record?.editableDraft?.id, 'd1');
    expect(record?.editableDraft?.customerId, 'c1');
  });

  test('已停止存款仅返回只读详情', () async {
    await customers.create(const CustomerDraft(id: 'c1', name: '张三'));
    await deposits.create(_draft('d1'));
    await deposits.stopRenewal('d1');

    final record = await useCases.load('d1');

    expect(record, isNotNull);
    expect(record?.editableDraft, isNull);
  });

  test('存款不存在时返回空', () async {
    expect(await useCases.load('missing'), isNull);
  });
}

DepositDraft _draft(String id) => DepositDraft(
  id: id,
  customerId: 'c1',
  amountCents: 120000,
  bankName: '建设银行',
  productName: '稳健一年',
  interestRateScaled: 215,
  ratePrecision: 2,
  startDate: LocalDate(2026, 7, 20),
  calculatedExpiryDate: LocalDate(2027, 7, 20),
  finalExpiryDate: LocalDate(2027, 7, 20),
);
