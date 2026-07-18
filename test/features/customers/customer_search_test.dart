import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/core/database/daos/deposit_dao.dart';
import 'package:deposit_renewal_manager/features/customers/application/customer_search_service.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/customers/domain/name_search_index.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CustomerDao customers;
  late DepositDao deposits;
  late CustomerSearchService service;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    customers = CustomerDao(
      database,
      sourceDeviceId: 'search-test',
      nowUtc: () => DateTime.utc(2026, 7, 18),
    );
    deposits = DepositDao(
      database,
      sourceDeviceId: 'search-test',
      nowUtc: () => DateTime.utc(2026, 7, 18),
    );
    service = CustomerSearchService(customers);
  });

  tearDown(() => database.close());

  test(
    'builds normalized Chinese name, pinyin, initials and phone indexes',
    () {
      final index = buildNameIndex(' 张-三 ');

      expect(index.normalizedName, '张三');
      expect(index.fullPinyin, 'zhangsan');
      expect(index.initials, 'zs');
      expect(normalizePhone('138 0013-8000'), '13800138000');
    },
  );

  test('ranks exact, prefix and contains matches in stable order', () async {
    await _seedCustomers(customers, ['张三', '张三丰', '李张三', '张三峰']);

    final result = await service.search(
      const CustomerQuery(text: ' ZHANG-SAN '),
    );

    expect(result.map((item) => item.customer.name), [
      '张三',
      '张三丰',
      '张三峰',
      '李张三',
    ]);
  });

  test('searches Chinese name, initials and normalized phone', () async {
    await customers.create(
      const CustomerDraft(id: 'one', name: '王小明', phone: '138-0013 8000'),
    );
    await customers.create(
      const CustomerDraft(id: 'two', name: '李王小', phone: '13900000000'),
    );

    expect(
      (await service.search(
        const CustomerQuery(text: '王小'),
      )).map((item) => item.customer.id),
      ['one', 'two'],
    );
    expect(
      (await service.search(
        const CustomerQuery(text: 'wxm'),
      )).single.customer.id,
      'one',
    );
    expect(
      (await service.search(
        const CustomerQuery(text: '0013-8000'),
      )).single.customer.id,
      'one',
    );
  });

  test(
    'updates all search indexes in the customer update transaction',
    () async {
      await customers.create(
        const CustomerDraft(id: 'one', name: '张三', phone: '13800138000'),
      );
      await customers.update(
        'one',
        const CustomerDraft(id: 'ignored', name: '李四', phone: '139-0000-0000'),
      );

      expect(
        await service.search(const CustomerQuery(text: 'zhangsan')),
        isEmpty,
      );
      expect(
        (await service.search(
          const CustomerQuery(text: 'lisi'),
        )).single.customer.id,
        'one',
      );
      expect(
        (await service.search(
          const CustomerQuery(text: '1390000'),
        )).single.customer.id,
        'one',
      );
    },
  );

  test(
    'applies bank, date, lifecycle and overdue filters to one deposit',
    () async {
      await _seedCustomers(customers, ['张三', '李四']);
      await deposits.create(
        _deposit(
          id: 'matching',
          customerId: 'customer-0',
          bankName: '中国银行',
          expiry: LocalDate(2026, 7, 17),
        ),
      );
      await deposits.create(
        _deposit(
          id: 'wrong-bank',
          customerId: 'customer-0',
          bankName: '建设银行',
          expiry: LocalDate(2026, 7, 17),
        ),
      );
      await deposits.create(
        _deposit(
          id: 'wrong-date',
          customerId: 'customer-1',
          bankName: '中国银行',
          expiry: LocalDate(2026, 7, 20),
        ),
      );

      final result = await service.search(
        CustomerQuery(
          bank: '中国银行',
          expiryFrom: LocalDate(2026, 7, 1),
          expiryTo: LocalDate(2026, 7, 18),
          lifecycle: DepositLifecycle.active,
          overdueOnly: true,
          today: LocalDate(2026, 7, 18),
        ),
      );

      expect(result, hasLength(1));
      expect(result.single.customer.name, '张三');
      expect(result.single.deposits.map((deposit) => deposit.id), ['matching']);
    },
  );

  test('overdue filtering requires today', () {
    expect(
      () => service.search(const CustomerQuery(overdueOnly: true)),
      throwsArgumentError,
    );
  });

  test('prefix lookup has a verifiable SQLite search index', () async {
    final plan = await database
        .customSelect(
          "EXPLAIN QUERY PLAN SELECT id FROM customers "
          "WHERE full_pinyin LIKE 'zhang%'",
        )
        .get();

    expect(
      plan.map((row) => row.read<String>('detail')).join('\n'),
      contains('customers_full_pinyin_idx'),
    );
  });
}

Future<void> _seedCustomers(CustomerDao customers, List<String> names) async {
  for (var index = 0; index < names.length; index++) {
    await customers.create(
      CustomerDraft(id: 'customer-$index', name: names[index]),
    );
  }
}

DepositDraft _deposit({
  required String id,
  required String customerId,
  required String bankName,
  required LocalDate expiry,
}) => DepositDraft(
  id: id,
  customerId: customerId,
  amountCents: 100000,
  bankName: bankName,
  interestRateScaled: 215,
  ratePrecision: 4,
  startDate: LocalDate(2026, 1, 1),
  calculatedExpiryDate: expiry,
  finalExpiryDate: expiry,
);
