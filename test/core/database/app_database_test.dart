import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/core/database/daos/deposit_dao.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CustomerDao customers;
  late DepositDao deposits;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    customers = CustomerDao(
      database,
      sourceDeviceId: 'device-test',
      nowUtc: () => DateTime.utc(2026, 7, 18, 8, 30),
    );
    deposits = DepositDao(
      database,
      sourceDeviceId: 'device-test',
      nowUtc: () => DateTime.utc(2026, 7, 18, 8, 30),
    );
  });

  tearDown(() => database.close());

  test('schema version, primary keys and foreign keys are enabled', () async {
    expect(database.schemaVersion, 1);
    final pragma = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(pragma.read<int>('foreign_keys'), 1);

    final schemaRows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = schemaRows
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(
      tableNames,
      containsAll(<String>{
        'customers',
        'deposits',
        'renewals',
        'audit_history',
        'message_templates',
        'import_batches',
        'business_settings',
        'notification_id_mappings',
      }),
    );

    await customers.create(const CustomerDraft(id: 'customer-1', name: '王芳'));
    await expectLater(
      customers.create(const CustomerDraft(id: 'customer-1', name: '重复客户')),
      throwsA(isA<Exception>()),
    );
    expect(await database.businessRevision(), 1);
    expect(await database.auditEntryCount(), 1);
  });

  test('every persisted UTC field uses SQLite INTEGER storage', () async {
    const utcColumns = <String, List<String>>{
      'customers': ['created_at_utc', 'updated_at_utc'],
      'deposits': ['created_at_utc', 'updated_at_utc'],
      'renewals': ['renewed_at_utc'],
      'audit_history': ['occurred_at_utc'],
      'message_templates': ['created_at_utc', 'updated_at_utc'],
      'import_batches': ['imported_at_utc'],
      'notification_id_mappings': ['created_at_utc'],
    };

    for (final entry in utcColumns.entries) {
      final columns = await database
          .customSelect('PRAGMA table_info(${entry.key})')
          .get();
      final types = {
        for (final column in columns)
          column.read<String>('name'): column.read<String>('type'),
      };
      for (final column in entry.value) {
        expect(types[column], 'INTEGER', reason: '${entry.key}.$column');
      }
    }
  });

  test('schema enforces foreign keys and financial constraints', () async {
    await expectLater(
      database
          .into(database.deposits)
          .insert(
            DepositsCompanion.insert(
              id: 'orphan',
              customerId: 'missing',
              amountCents: 100,
              interestRateScaled: 1,
              ratePrecision: 1,
              startDate: '2026-07-18',
              calculatedExpiryDate: const Value(null),
              finalExpiryDate: '2027-07-18',
              lifecycle: 'active',
              createdAtUtc: _testEpoch,
              updatedAtUtc: _testEpoch,
              sourceDeviceId: 'test',
            ),
          ),
      throwsA(isA<Exception>()),
    );

    await customers.create(const CustomerDraft(id: 'customer-1', name: '王芳'));

    await expectLater(
      deposits.create(
        _draft(id: 'bad-amount', customerId: 'customer-1', amountCents: 0),
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      deposits.create(
        _draft(id: 'bad-rate', customerId: 'customer-1', ratePrecision: 10),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('customer with active deposits cannot be deactivated', () async {
    await customers.create(const CustomerDraft(id: 'customer-1', name: '王芳'));
    await deposits.create(_draft(id: 'deposit-1', customerId: 'customer-1'));

    await expectLater(
      customers.deactivate('customer-1'),
      throwsA(isA<CustomerHasActiveDepositsException>()),
    );

    expect((await customers.get('customer-1'))!.isActive, isTrue);
    expect(await database.businessRevision(), 2);
  });

  test(
    'inactive customer rejects deposit creation without partial writes',
    () async {
      await customers.create(
        const CustomerDraft(id: 'inactive', name: 'Inactive'),
      );
      await customers.deactivate('inactive');
      final revisionBefore = await database.businessRevision();
      final auditCountBefore = await database.auditEntryCount();

      await expectLater(
        deposits.create(_draft(id: 'rejected', customerId: 'inactive')),
        throwsA(isA<CustomerInactiveException>()),
      );

      expect(await deposits.get('rejected'), isNull);
      expect(await database.businessRevision(), revisionBefore);
      expect(await database.auditEntryCount(), auditCountBefore);
    },
  );

  test(
    'inactive customer rejects deposit transfer without partial writes',
    () async {
      await customers.create(const CustomerDraft(id: 'active', name: 'Active'));
      await customers.create(
        const CustomerDraft(id: 'inactive', name: 'Inactive'),
      );
      await customers.deactivate('inactive');
      await deposits.create(_draft(id: 'deposit-1', customerId: 'active'));
      final revisionBefore = await database.businessRevision();
      final auditCountBefore = await database.auditEntryCount();

      await expectLater(
        deposits.update(
          'deposit-1',
          _draft(id: 'ignored', customerId: 'inactive'),
        ),
        throwsA(isA<CustomerInactiveException>()),
      );

      expect((await deposits.get('deposit-1'))!.customerId, 'active');
      expect(await database.businessRevision(), revisionBefore);
      expect(await database.auditEntryCount(), auditCountBefore);
    },
  );

  test('schema rejects malformed date shapes', () async {
    await customers.create(
      const CustomerDraft(id: 'customer-1', name: 'Valid'),
    );

    await expectLater(
      database
          .into(database.deposits)
          .insert(
            DepositsCompanion.insert(
              id: 'bad-date',
              customerId: 'customer-1',
              amountCents: 100,
              interestRateScaled: 1,
              ratePrecision: 1,
              startDate: '2026-a7-18',
              calculatedExpiryDate: const Value(null),
              finalExpiryDate: '2027-07-18',
              lifecycle: 'active',
              createdAtUtc: _testEpoch,
              updatedAtUtc: _testEpoch,
              sourceDeviceId: 'test',
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('schema rejects invalid calendar dates at write time', () async {
    await customers.create(
      const CustomerDraft(id: 'customer-1', name: 'Valid'),
    );
    for (final date in [
      '2026-02-31',
      '2025-02-29',
      '2026-00-10',
      '2026-13-01',
      '2026-01-00',
      '2026-01-32',
    ]) {
      await expectLater(
        database
            .into(database.deposits)
            .insert(
              DepositsCompanion.insert(
                id: 'bad-$date',
                customerId: 'customer-1',
                amountCents: 100,
                interestRateScaled: 1,
                ratePrecision: 1,
                startDate: date,
                calculatedExpiryDate: const Value(null),
                finalExpiryDate: '2027-07-18',
                lifecycle: 'active',
                createdAtUtc: _testEpoch,
                updatedAtUtc: _testEpoch,
                sourceDeviceId: 'test',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    }
  });

  test('schema accepts Gregorian leap day and rejects fake UTC text', () async {
    await customers.create(
      const CustomerDraft(id: 'customer-1', name: 'Valid'),
    );
    await deposits.create(
      DepositDraft(
        id: 'leap-day',
        customerId: 'customer-1',
        amountCents: 100,
        interestRateScaled: 1,
        ratePrecision: 1,
        startDate: LocalDate(2024, 2, 29),
        calculatedExpiryDate: LocalDate(2024, 2, 29),
        finalExpiryDate: LocalDate(2024, 2, 29),
      ),
    );
    expect((await deposits.get('leap-day'))!.startDate, LocalDate(2024, 2, 29));

    await expectLater(
      database.customStatement(
        "INSERT INTO customers (id, name, created_at_utc, updated_at_utc) VALUES ('fake-time', 'Fake', '2026-07-18T08:30:00.000Z', '2026-07-18T08:30:00.000Z')",
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'zero-time',
              name: 'Zero',
              createdAtUtc: 0,
              updatedAtUtc: _testEpoch,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('foreign keys restrict deletion of referenced business rows', () async {
    await customers.create(
      const CustomerDraft(id: 'customer-1', name: 'Valid'),
    );
    await deposits.create(_draft(id: 'source', customerId: 'customer-1'));

    await expectLater(
      (database.delete(
        database.customers,
      )..where((row) => row.id.equals('customer-1'))).go(),
      throwsA(isA<Exception>()),
    );

    await deposits.renew(
      'source',
      _draft(id: 'target', customerId: 'customer-1'),
    );
    await expectLater(
      (database.delete(
        database.deposits,
      )..where((row) => row.id.equals('source'))).go(),
      throwsA(isA<Exception>()),
    );
  });

  test('business revision increases monotonically across operations', () async {
    expect(await database.businessRevision(), 0);
    await customers.create(const CustomerDraft(id: 'customer-1', name: 'One'));
    expect(await database.businessRevision(), 1);
    await customers.update(
      'customer-1',
      const CustomerDraft(id: 'ignored', name: 'Two'),
    );
    expect(await database.businessRevision(), 2);
    await deposits.create(_draft(id: 'deposit-1', customerId: 'customer-1'));
    expect(await database.businessRevision(), 3);
    await deposits.stopRenewal('deposit-1');
    expect(await database.businessRevision(), 4);
  });

  test(
    'create and update persist ISO dates and append revisioned audit',
    () async {
      await customers.create(const CustomerDraft(id: 'customer-1', name: '王芳'));
      await deposits.create(_draft(id: 'deposit-1', customerId: 'customer-1'));

      await deposits.update(
        'deposit-1',
        _draft(
          id: 'ignored',
          customerId: 'customer-1',
          amountCents: 250000,
          calculatedExpiryDate: LocalDate(2027, 7, 18),
          finalExpiryDate: LocalDate(2027, 7, 20),
        ),
      );

      final stored = await deposits.get('deposit-1');
      final audit = await database.auditEntriesFor('deposit', 'deposit-1');
      expect(stored!.amountCents, 250000);
      expect(stored.deposit.calculatedExpiryDate, LocalDate(2027, 7, 18));
      expect(stored.deposit.finalExpiryDate, LocalDate(2027, 7, 20));
      expect(await database.businessRevision(), 3);
      expect(audit, hasLength(2));
      expect(audit.last.beforeJson, contains('100000'));
      expect(audit.last.afterJson, contains('250000'));
      expect(
        DateTime.fromMicrosecondsSinceEpoch(
          audit.last.occurredAtUtc,
          isUtc: true,
        ),
        DateTime.utc(2026, 7, 18, 8, 30),
      );
      expect(audit.last.sourceDeviceId, 'device-test');
    },
  );
}

final int _testEpoch = DateTime.utc(2026, 7, 18, 8, 30).microsecondsSinceEpoch;

DepositDraft _draft({
  required String id,
  required String customerId,
  int amountCents = 100000,
  int ratePrecision = 4,
  LocalDate? calculatedExpiryDate,
  LocalDate? finalExpiryDate,
}) {
  return DepositDraft(
    id: id,
    customerId: customerId,
    amountCents: amountCents,
    interestRateScaled: 215,
    ratePrecision: ratePrecision,
    startDate: LocalDate(2026, 7, 18),
    calculatedExpiryDate: calculatedExpiryDate,
    finalExpiryDate: finalExpiryDate ?? LocalDate(2027, 7, 18),
  );
}
