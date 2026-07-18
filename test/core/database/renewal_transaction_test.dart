import 'dart:convert';

import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/core/database/daos/deposit_dao.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CustomerDao customers;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    customers = CustomerDao(
      database,
      sourceDeviceId: 'device-a',
      nowUtc: () => DateTime.utc(2026, 7, 18, 9),
    );
    await customers.create(const CustomerDraft(id: 'customer-1', name: '李明'));
  });

  tearDown(() => database.close());

  test(
    'renewal closes source and creates linked active deposit atomically',
    () async {
      final repository = _repository(database);
      await repository.create(_draft('source'));

      final result = await repository.renew('source', _draft('target'));

      expect(
        (await repository.get('source'))!.deposit.lifecycle,
        DepositLifecycle.renewed,
      );
      expect(
        (await repository.get(result.newDepositId))!.deposit.lifecycle,
        DepositLifecycle.active,
      );
      expect(await repository.renewalSourceOf(result.newDepositId), 'source');
      expect(await database.businessRevision(), 3);
      final sourceAudit = await database.auditEntriesFor('deposit', 'source');
      expect(jsonDecode(sourceAudit.last.afterJson!)['lifecycle'], 'renewed');
    },
  );

  for (final failurePoint in RenewalFailurePoint.values) {
    test(
      'fault at $failurePoint rolls back source target history and revision',
      () async {
        final stableRepository = _repository(database);
        await stableRepository.create(_draft('source'));
        final revisionBefore = await database.businessRevision();
        final auditCountBefore = await database.auditEntryCount();
        final failingRepository = _repository(
          database,
          failureInjector: (point) async {
            if (point == failurePoint) {
              throw StateError('injected failure');
            }
          },
        );

        await expectLater(
          failingRepository.renew('source', _draft('target')),
          throwsStateError,
        );

        expect(
          (await stableRepository.get('source'))!.deposit.lifecycle,
          DepositLifecycle.active,
        );
        expect(await stableRepository.get('target'), isNull);
        expect(await stableRepository.renewalSourceOf('target'), isNull);
        expect(await database.auditEntryCount(), auditCountBefore);
        expect(await database.businessRevision(), revisionBefore);
      },
    );
  }

  test('renew rejects inactive customer without partial writes', () async {
    final repository = _repository(database);
    await repository.create(_draft('source'));
    await (database.update(database.customers)
          ..where((row) => row.id.equals('customer-1')))
        .write(const CustomersCompanion(isActive: Value(false)));
    final revisionBefore = await database.businessRevision();
    final auditCountBefore = await database.auditEntryCount();

    await expectLater(
      repository.renew('source', _draft('target')),
      throwsA(isA<CustomerInactiveException>()),
    );

    expect(
      (await repository.get('source'))!.deposit.lifecycle,
      DepositLifecycle.active,
    );
    expect(await repository.get('target'), isNull);
    expect(await database.businessRevision(), revisionBefore);
    expect(await database.auditEntryCount(), auditCountBefore);
  });

  test('renew rejects duplicate and non-active source deposits', () async {
    final repository = _repository(database);
    await repository.create(_draft('source'));
    await repository.renew('source', _draft('target'));
    final revisionBefore = await database.businessRevision();
    final auditCountBefore = await database.auditEntryCount();

    await expectLater(
      repository.renew('source', _draft('another-target')),
      throwsA(isA<DepositNotActiveException>()),
    );
    await expectLater(
      repository.renew('target', _draft('source')),
      throwsA(isA<Exception>()),
    );

    expect(await database.businessRevision(), revisionBefore);
    expect(await database.auditEntryCount(), auditCountBefore);
  });

  test('stop renewal and its audit share one transaction', () async {
    final repository = _repository(database);
    await repository.create(_draft('source'));

    await repository.stopRenewal('source');

    expect(
      (await repository.get('source'))!.deposit.lifecycle,
      DepositLifecycle.stopped,
    );
    final audit = await database.auditEntriesFor('deposit', 'source');
    expect(jsonDecode(audit.last.beforeJson!)['lifecycle'], 'active');
    expect(jsonDecode(audit.last.afterJson!)['lifecycle'], 'stopped');
    expect(audit.last.sourceDeviceId, 'device-a');
  });
}

DepositDao _repository(
  AppDatabase database, {
  RenewalFailureInjector? failureInjector,
}) {
  return DepositDao(
    database,
    sourceDeviceId: 'device-a',
    nowUtc: () => DateTime.utc(2026, 7, 18, 9),
    failureInjector: failureInjector,
  );
}

DepositDraft _draft(String id) => DepositDraft(
  id: id,
  customerId: 'customer-1',
  amountCents: 100000,
  interestRateScaled: 215,
  ratePrecision: 4,
  startDate: LocalDate(2026, 7, 18),
  calculatedExpiryDate: LocalDate(2027, 7, 18),
  finalExpiryDate: LocalDate(2027, 7, 18),
);
