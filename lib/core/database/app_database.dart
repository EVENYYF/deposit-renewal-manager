import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/customers/domain/name_search_index.dart';
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
  int get schemaVersion => 2;

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
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await transaction(() async {
          await migrator.addColumn(customers, customers.normalizedName);
          await migrator.addColumn(customers, customers.fullPinyin);
          await migrator.addColumn(customers, customers.initials);
          await migrator.addColumn(customers, customers.normalizedPhone);
          await migrator.addColumn(deposits, deposits.bankName);
          await _backfillCustomerSearchIndexes();
          await _createSearchIndexes();
        });
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA case_sensitive_like = ON');
    },
  );

  Future<void> _backfillCustomerSearchIndexes() async {
    final rows = await customSelect(
      'SELECT id, name, phone FROM customers',
    ).get();
    for (final row in rows) {
      final index = buildNameIndex(row.read<String>('name'));
      final phone = row.readNullable<String>('phone');
      await customUpdate(
        'UPDATE customers SET normalized_name = ?, full_pinyin = ?, '
        'initials = ?, normalized_phone = ? WHERE id = ?',
        variables: [
          Variable.withString(index.normalizedName),
          Variable.withString(index.fullPinyin),
          Variable.withString(index.initials),
          Variable.withString(normalizePhone(phone ?? '')),
          Variable.withString(row.read<String>('id')),
        ],
        updates: {customers},
      );
    }
  }

  Future<void> _createSearchIndexes() async {
    await customStatement(
      'CREATE INDEX customers_normalized_name_idx '
      'ON customers (normalized_name)',
    );
    await customStatement(
      'CREATE INDEX customers_full_pinyin_idx ON customers (full_pinyin)',
    );
    await customStatement(
      'CREATE INDEX customers_initials_idx ON customers (initials)',
    );
    await customStatement(
      'CREATE INDEX customers_normalized_phone_idx '
      'ON customers (normalized_phone)',
    );
    await customStatement(
      'CREATE INDEX deposits_bank_name_idx ON deposits (bank_name)',
    );
    await customStatement(
      'CREATE INDEX deposits_expiry_lifecycle_customer_idx '
      'ON deposits (final_expiry_date, lifecycle, customer_id)',
    );
  }

  Future<int> businessRevision() async {
    final row = await (select(
      businessSettings,
    )..where((settings) => settings.singletonId.equals(1))).getSingle();
    return row.businessRevision;
  }

  Future<int> incrementBusinessRevision() async {
    final affectedRows = await customUpdate(
      'UPDATE business_settings '
      'SET business_revision = business_revision + 1 '
      'WHERE singleton_id = 1',
      updates: {businessSettings},
    );
    if (affectedRows != 1) {
      throw StateError('Business revision singleton is missing');
    }
    return businessRevision();
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
