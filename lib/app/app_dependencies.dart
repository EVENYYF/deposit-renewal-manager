import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/database/daos/customer_dao.dart';
import '../core/database/daos/deposit_dao.dart';
import '../core/notifications/notification_scheduler.dart';
import '../features/customers/application/customer_controller.dart';
import '../features/customers/application/customer_history_service.dart';
import '../features/customers/application/customer_search_service.dart';
import '../features/customers/domain/customer_repository.dart';
import '../features/customers/domain/name_search_index.dart';
import '../features/dashboard/application/dashboard_controller.dart';
import '../features/deposits/application/deposit_workflow_controller.dart';
import '../features/deposits/domain/deposit.dart' as domain;
import '../features/deposits/domain/deposit_repository.dart';
import '../features/deposits/domain/local_date.dart';
import '../features/deposits/domain/reminder_buckets.dart';

const String localSourceDeviceId = 'local-device';

class ApplicationProviderScope extends StatelessWidget {
  const ApplicationProviderScope({
    required this.database,
    required this.notificationScheduler,
    required this.child,
    super.key,
  });
  final AppDatabase database;
  final NotificationScheduler notificationScheduler;
  final Widget child;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      notificationSchedulerProvider.overrideWithValue(notificationScheduler),
      customerUseCasesProvider.overrideWith(
        (ref) => SqliteCustomerUseCases(
          CustomerDao(database, sourceDeviceId: localSourceDeviceId),
        ),
      ),
      customerHistoryUseCasesProvider.overrideWith(
        (ref) => SqliteCustomerHistoryUseCases(database),
      ),
      depositWorkflowProvider.overrideWith(
        (ref) => DaoDepositWorkflow(
          DepositDao(
            database,
            sourceDeviceId: localSourceDeviceId,
            notificationCoordinator: ref.read(
              notificationMutationCoordinatorProvider,
            ),
          ),
        ),
      ),
      dashboardUseCasesProvider.overrideWith(
        (ref) => SqliteDashboardUseCases(database),
      ),
    ],
    child: child,
  );
}

final class SqliteCustomerUseCases implements CustomerUseCases {
  const SqliteCustomerUseCases(this._repository);

  final CustomerRepository _repository;

  @override
  Future<List<CustomerSearchResult>> load(String query) =>
      CustomerSearchService(_repository).search(CustomerQuery(text: query));

  @override
  Future<void> save(CustomerDraft draft) async {
    final existing = await _repository.get(draft.id);
    if (existing == null) {
      await _repository.create(draft);
    } else {
      await _repository.update(draft.id, draft);
    }
  }
}

final class DaoDepositWorkflow implements DepositWorkflow {
  const DaoDepositWorkflow(this._repository);

  final DepositRepository _repository;

  @override
  Future<void> create(DepositDraft draft) async {
    await _repository.create(draft);
  }

  @override
  Future<void> renew(String sourceDepositId, DepositDraft draft) async {
    await _repository.renew(sourceDepositId, draft);
  }

  @override
  Future<void> stop(String depositId) => _repository.stopRenewal(depositId);

  @override
  Future<void> update(String depositId, DepositDraft draft) async {
    await _repository.update(depositId, draft);
  }
}

final class SqliteDashboardUseCases implements DashboardUseCases {
  SqliteDashboardUseCases(this._database, {DateTime Function()? now})
    : _now = now ?? clock.now;

  final AppDatabase _database;
  final DateTime Function() _now;

  @override
  Future<DashboardSnapshot> load() async {
    final rows = await _database
        .customSelect(
          '''
SELECT d.id, d.customer_id, d.amount_cents, d.bank_name, d.start_date,
       d.interest_rate_scaled, d.rate_precision,
       d.calculated_expiry_date, d.final_expiry_date, d.lifecycle,
       c.name AS customer_name
FROM deposits d
JOIN customers c ON c.id = d.customer_id
WHERE d.lifecycle = 'active' AND c.is_active = 1
ORDER BY d.final_expiry_date, c.name
''',
          readsFrom: {_database.deposits, _database.customers},
        )
        .get();
    final entries = <String, DashboardReminder>{};
    final deposits = <domain.Deposit>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      final finalExpiry = _parseDate(row.read<String>('final_expiry_date'));
      final calculated = row.readNullable<String>('calculated_expiry_date');
      deposits.add(
        calculated == null
            ? domain.Deposit.direct(id: id, expiryDate: finalExpiry)
            : domain.Deposit.automatic(
                id: id,
                calculatedExpiryDate: _parseDate(calculated),
                finalExpiryDate: finalExpiry,
              ),
      );
      entries[id] = DashboardReminder(
        depositId: id,
        customerId: row.read<String>('customer_id'),
        customerName: row.read<String>('customer_name'),
        bankName: row.read<String>('bank_name'),
        amountCents: row.read<int>('amount_cents'),
        expiryDate: finalExpiry.toString(),
        startDate: row.read<String>('start_date'),
        calculatedExpiryDate: calculated,
        interestRateScaled: row.read<int>('interest_rate_scaled'),
        ratePrecision: row.read<int>('rate_precision'),
      );
    }
    final now = _now().toLocal();
    final today = LocalDate(now.year, now.month, now.day);
    final buckets = ReminderBuckets.build(deposits, today);
    final customerCount = await _database
        .customSelect(
          'SELECT COUNT(*) AS total FROM customers WHERE is_active = 1',
          readsFrom: {_database.customers},
        )
        .getSingle();
    List<DashboardReminder> map(List<domain.Deposit> values) =>
        values.map((value) => entries[value.id]!).toList(growable: false);
    return DashboardSnapshot(
      dueSoonCount:
          buckets.dueToday.length +
          buckets.nextThreeDays.length +
          buckets.thisWeek.length,
      overdueCount: buckets.overdue.length,
      customerCount: customerCount.read<int>('total'),
      today: map(buckets.dueToday),
      nextThreeDays: map(buckets.nextThreeDays),
      thisWeek: map(buckets.thisWeek),
      overdue: map(buckets.overdue),
    );
  }

  @override
  Future<void> save(DashboardCommand command) async {}

  LocalDate _parseDate(String value) {
    final parts = value.split('-');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

final class SqliteCustomerHistoryUseCases implements CustomerHistoryUseCases {
  const SqliteCustomerHistoryUseCases(this._database);
  final AppDatabase _database;

  @override
  Future<List<CustomerHistoryEntry>> load(String customerId) async {
    final rows = await _database
        .customSelect(
          '''
SELECT a.operation, a.occurred_at_utc
FROM audit_history a
WHERE (a.entity_type = 'customer' AND a.entity_id = ?)
   OR (a.entity_type = 'deposit' AND a.entity_id IN (
     SELECT id FROM deposits WHERE customer_id = ?
   ))
ORDER BY a.occurred_at_utc DESC
''',
          variables: [
            Variable.withString(customerId),
            Variable.withString(customerId),
          ],
          readsFrom: {_database.auditHistory, _database.deposits},
        )
        .get();
    return rows
        .map(
          (row) => CustomerHistoryEntry(
            operation: row.read<String>('operation'),
            occurredAt: DateTime.fromMicrosecondsSinceEpoch(
              row.read<int>('occurred_at_utc'),
              isUtc: true,
            ).toLocal(),
          ),
        )
        .toList(growable: false);
  }
}
