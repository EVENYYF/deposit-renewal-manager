import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/business_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Customers,
    Deposits,
    Renewals,
    AuditHistory,
    MessageTemplates,
    ImportBatches,
    BusinessSettings,
    NotificationIdMappings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'deposit_renewal_manager'));

  AppDatabase.forTesting(QueryExecutor executor) : this(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await into(businessSettings).insert(
        BusinessSettingsCompanion.insert(
          singletonId: const Value(1),
          businessRevision: const Value(0),
        ),
      );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<int> businessRevision() async {
    final row = await (select(
      businessSettings,
    )..where((settings) => settings.singletonId.equals(1))).getSingle();
    return row.businessRevision;
  }

  Future<int> incrementBusinessRevision() async {
    final nextRevision = await businessRevision() + 1;
    await (update(
      businessSettings,
    )..where((settings) => settings.singletonId.equals(1))).write(
      BusinessSettingsCompanion(businessRevision: Value(nextRevision)),
    );
    return nextRevision;
  }

  Future<List<AuditHistoryData>> auditEntriesFor(
    String entityType,
    String entityId,
  ) {
    return (select(auditHistory)
          ..where(
            (entry) =>
                entry.entityType.equals(entityType) &
                entry.entityId.equals(entityId),
          )
          ..orderBy([(entry) => OrderingTerm.asc(entry.businessRevision)]))
        .get();
  }

  Future<int> auditEntryCount() async {
    final count = auditHistory.id.count();
    final row = await (selectOnly(
      auditHistory,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }
}
