import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/backup/backup_service.dart';
import '../core/backup/snapshot_policy_service.dart';
import '../core/database/app_database.dart';
import '../core/database/daos/customer_dao.dart';
import '../core/database/daos/deposit_dao.dart';
import '../core/database/daos/deposit_preset_dao.dart';
import '../core/database/daos/product_catalog_dao.dart';
import '../core/notifications/notification_scheduler.dart';
import '../features/customers/application/customer_controller.dart';
import '../features/customers/application/customer_history_service.dart';
import '../features/customers/application/customer_search_service.dart';
import '../features/customers/domain/customer_repository.dart';
import '../features/customers/domain/name_search_index.dart';
import '../features/dashboard/application/dashboard_controller.dart';
import '../features/deposits/application/deposit_workflow_controller.dart';
import '../features/deposits/application/deposit_preset_service.dart';
import '../features/deposits/application/deposit_details_service.dart';
import '../features/deposits/application/product_catalog_service.dart';
import '../features/deposits/domain/deposit.dart' as domain;
import '../features/deposits/domain/deposit_repository.dart';
import '../features/deposits/domain/expiry_calculator.dart';
import '../features/deposits/domain/local_date.dart';
import '../features/deposits/domain/reminder_buckets.dart';
import '../features/excel_import/application/duplicate_resolver.dart';
import '../features/excel_import/application/import_commit_service.dart';
import '../features/excel_import/application/xlsx_preview_service.dart';
import '../features/excel_import/presentation/import_wizard.dart';
import '../features/statistics/application/deposit_statistics.dart';
import '../features/text_import/domain/text_deposit_parser.dart';
import '../features/templates/application/template_repository.dart';
import '../features/templates/domain/message_template.dart' as template_domain;
import '../features/templates/presentation/templates_page.dart';

const String localSourceDeviceId = 'local-device';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('Application database is not configured'),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => throw StateError('Backup service is not configured'),
);

final snapshotPolicyServiceProvider = Provider<SnapshotPolicyService>(
  (ref) => SnapshotPolicyService(
    database: ref.read(appDatabaseProvider),
    backupService: ref.read(backupServiceProvider),
  ),
);

final depositPresetServiceProvider = Provider<DepositPresetService>(
  (ref) => throw StateError('Deposit presets are not configured'),
);

final productCatalogServiceProvider = Provider<ProductCatalogService>(
  (ref) => throw StateError('Product catalog is not configured'),
);

final excelImportBindingsProvider = Provider<ExcelImportBindings>(
  (ref) => throw StateError('Excel import is not configured'),
);

typedef ConfirmedTextImport = Future<void> Function(ParseResult result);

final confirmedTextImportProvider = Provider<ConfirmedTextImport>(
  (ref) => throw StateError('Text import is not configured'),
);

final templateBindingsProvider = Provider<TemplateBindings>(
  (ref) => TemplateBindings(
    load: () async => const [
      template_domain.MessageTemplate(
        name: '到期提醒',
        body: '{{customerName}}您好，您的存款将于{{expiryDate}}到期。',
        isDefault: true,
      ),
    ],
    save: (template) async => template,
  ),
);

class ApplicationProviderScope extends StatelessWidget {
  const ApplicationProviderScope({
    required this.database,
    required this.notificationScheduler,
    required this.backupService,
    required this.child,
    super.key,
  });
  final AppDatabase database;
  final NotificationScheduler notificationScheduler;
  final BackupService backupService;
  final Widget child;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      backupServiceProvider.overrideWithValue(backupService),
      depositPresetServiceProvider.overrideWithValue(
        DepositPresetService(DepositPresetDao(database)),
      ),
      productCatalogServiceProvider.overrideWithValue(
        ProductCatalogService(ProductCatalogDao(database)),
      ),
      notificationSchedulerProvider.overrideWithValue(notificationScheduler),
      customerUseCasesProvider.overrideWith(
        (ref) => SqliteCustomerUseCases(
          CustomerDao(database, sourceDeviceId: localSourceDeviceId),
        ),
      ),
      customerHistoryUseCasesProvider.overrideWith(
        (ref) => SqliteCustomerHistoryUseCases(database),
      ),
      customerDepositHistoryUseCasesProvider.overrideWith(
        (ref) => SqliteCustomerDepositHistoryUseCases(database),
      ),
      depositWorkflowProvider.overrideWith((ref) {
        final customers = CustomerDao(
          database,
          sourceDeviceId: localSourceDeviceId,
        );
        return DaoDepositWorkflow.configured(
          DepositDao(
            database,
            sourceDeviceId: localSourceDeviceId,
            notificationCoordinator: ref.read(
              notificationMutationCoordinatorProvider,
            ),
          ),
          database,
          customers,
        );
      }),
      depositDetailsUseCasesProvider.overrideWithValue(
        RepositoryDepositDetailsUseCases(
          DepositDao(database, sourceDeviceId: localSourceDeviceId),
          CustomerDao(database, sourceDeviceId: localSourceDeviceId),
        ),
      ),
      dashboardUseCasesProvider.overrideWith(
        (ref) => SqliteDashboardUseCases(database),
      ),
      depositStatisticsUseCasesProvider.overrideWith(
        (ref) => SqliteDepositStatisticsUseCases(database),
      ),
      templateBindingsProvider.overrideWith((ref) {
        final repository = TemplateRepository(
          database,
          sourceDeviceId: localSourceDeviceId,
        );
        return TemplateBindings(load: repository.load, save: repository.save);
      }),
      excelImportBindingsProvider.overrideWith((ref) {
        final preview = const XlsxPreviewService();
        final resolver = DuplicateResolver(database);
        final commit = ImportCommitService(
          database: database,
          sourceDeviceId: localSourceDeviceId,
          createSnapshot: () =>
              backupService.createAutomaticSnapshot('excel_import'),
          notificationReconcile: (_) =>
              ref.read(notificationMutationCoordinatorProvider).reconcileAll(),
        );
        return ExcelImportBindings(
          preview: (bytes, {mapping}) =>
              preview.previewBytes(bytes, mapping: mapping),
          resolve: resolver.resolvePreview,
          commit: (file, result, decisions, skippedInvalidRows) async {
            final imported = await commit.commit(
              fileName: file.name,
              fileBytes: file.bytes,
              preview: result,
              decisions: decisions,
              skippedInvalidRows: skippedInvalidRows,
            );
            ref.invalidate(customerControllerProvider);
            ref.invalidate(dashboardControllerProvider);
            return imported;
          },
        );
      }),
      confirmedTextImportProvider.overrideWith((ref) {
        final customers = CustomerDao(
          database,
          sourceDeviceId: localSourceDeviceId,
        );
        final deposits = DepositDao(
          database,
          sourceDeviceId: localSourceDeviceId,
          notificationCoordinator: ref.read(
            notificationMutationCoordinatorProvider,
          ),
        );
        return (result) async {
          final name = result.name?.trim();
          final amount = result.amountCents;
          final start = result.depositDate;
          final calculated = result.term == null || start == null
              ? null
              : ExpiryCalculator().calculate(start, result.term!);
          final expiry = result.expiryDate ?? calculated;
          if (name == null ||
              name.isEmpty ||
              amount == null ||
              start == null ||
              expiry == null) {
            throw const FormatException('姓名、金额、存入日期和到期信息必须完整');
          }
          final customerId = const Uuid().v4();
          final depositId = const Uuid().v4();
          final rate = result.interestRatePercent ?? 0;
          await database.transaction(() async {
            await customers.create(
              CustomerDraft(id: customerId, name: name, phone: result.phone),
            );
            await deposits.create(
              DepositDraft(
                id: depositId,
                customerId: customerId,
                amountCents: amount,
                bankName: result.bank ?? '',
                productName: result.product ?? '',
                termValue: result.term?.value,
                termUnit: switch (result.term) {
                  DayTerm() => DepositTermUnit.day,
                  MonthTerm() => DepositTermUnit.month,
                  YearTerm() => DepositTermUnit.year,
                  null => null,
                },
                interestRateScaled: (rate * 100).round(),
                ratePrecision: 2,
                startDate: start,
                calculatedExpiryDate: calculated,
                finalExpiryDate: expiry,
              ),
            );
          });
          ref.invalidate(customerControllerProvider);
          ref.invalidate(dashboardControllerProvider);
        };
      }),
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
  const DaoDepositWorkflow(this._repository)
    : _database = null,
      _customers = null;

  const DaoDepositWorkflow.configured(
    this._repository,
    this._database,
    this._customers,
  );

  final AppDatabase? _database;
  final DepositRepository _repository;
  final CustomerRepository? _customers;

  @override
  Future<void> create(DepositDraft draft) async {
    await _repository.create(draft);
  }

  @override
  Future<void> createWithCustomer(
    DepositDraft draft,
    CustomerDraft customer,
  ) async {
    final database = _database;
    final customers = _customers;
    if (database == null || customers == null) {
      throw StateError('Customer creation is not configured');
    }
    await database.transaction(() async {
      await customers.create(customer);
      await _repository.create(draft);
    });
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
SELECT d.id, d.customer_id, d.amount_cents, d.bank_name, d.product_name,
       d.term_value, d.term_unit, d.start_date,
       d.interest_rate_scaled, d.rate_precision,
       d.calculated_expiry_date, d.final_expiry_date, d.lifecycle,
       c.name AS customer_name, c.phone AS customer_phone
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
        customerPhone: row.readNullable<String>('customer_phone'),
        bankName: row.read<String>('bank_name'),
        productName: row.read<String>('product_name'),
        termValue: row.readNullable<int>('term_value'),
        termUnit: row.readNullable<String>('term_unit'),
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
SELECT a.entity_type, a.entity_id, a.operation, a.before_json,
       a.after_json, a.occurred_at_utc
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
            entityType: row.read<String>('entity_type'),
            entityId: row.read<String>('entity_id'),
            beforeJson: row.readNullable<String>('before_json'),
            afterJson: row.readNullable<String>('after_json'),
          ),
        )
        .toList(growable: false);
  }
}

final class SqliteCustomerDepositHistoryUseCases
    implements CustomerDepositHistoryUseCases {
  const SqliteCustomerDepositHistoryUseCases(this._database);

  final AppDatabase _database;

  @override
  Future<List<CustomerDepositChain>> load(CustomerSearchResult result) async {
    final rows =
        await (_database.select(_database.deposits)
              ..where(
                (deposit) => deposit.customerId.equals(result.customer.id),
              )
              ..orderBy([(deposit) => OrderingTerm.asc(deposit.startDate)]))
            .get();
    final links =
        await (_database.select(_database.renewals)..where(
              (renewal) => renewal.sourceDepositId.isIn(
                rows.map((row) => row.id).toList(growable: false),
              ),
            ))
            .get();
    final targetBySource = {
      for (final link in links) link.sourceDepositId: link.targetDepositId,
    };
    final rowsById = {for (final row in rows) row.id: row};
    final targeted = links.map((link) => link.targetDepositId).toSet();
    final roots = rows.where((row) => !targeted.contains(row.id));
    return [
      for (final root in roots)
        CustomerDepositChain(
          versions: _chain(root.id, rowsById, targetBySource),
        ),
    ];
  }

  List<CustomerDepositVersion> _chain(
    String rootId,
    Map<String, Deposit> rows,
    Map<String, String> targetBySource,
  ) {
    final versions = <CustomerDepositVersion>[];
    final seen = <String>{};
    String? current = rootId;
    while (current != null && seen.add(current)) {
      final row = rows[current];
      if (row == null) break;
      final calculated = row.calculatedExpiryDate;
      final start = _date(row.startDate);
      versions.add(
        CustomerDepositVersion(
          id: row.id,
          bankName: row.bankName,
          productName: row.productName,
          amountCents: row.amountCents,
          interestRateScaled: row.interestRateScaled,
          ratePrecision: row.ratePrecision,
          finalExpiryDate: _date(row.finalExpiryDate),
          startDate: start,
          lifecycle: domain.DepositLifecycle.values.byName(row.lifecycle),
          renewalSourceId: versions.isEmpty ? null : versions.last.id,
          editableDraft: row.lifecycle == 'active'
              ? DepositDraft(
                  id: row.id,
                  customerId: row.customerId,
                  amountCents: row.amountCents,
                  bankName: row.bankName,
                  productName: row.productName,
                  termValue: row.termValue,
                  termUnit: row.termUnit == null
                      ? null
                      : DepositTermUnit.values.byName(row.termUnit!),
                  interestRateScaled: row.interestRateScaled,
                  ratePrecision: row.ratePrecision,
                  startDate: start,
                  calculatedExpiryDate: calculated == null
                      ? null
                      : _date(calculated),
                  finalExpiryDate: _date(row.finalExpiryDate),
                )
              : null,
        ),
      );
      current = targetBySource[current];
    }
    return versions;
  }

  LocalDate _date(String value) {
    final parts = value.split('-');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
