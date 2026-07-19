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
    DeviceSettings,
    NotificationIdMappings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'deposit_renewal_manager'));

  AppDatabase.forTesting(QueryExecutor executor) : this(executor);

  @override
  int get schemaVersion => 5;

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
      await into(
        deviceSettings,
      ).insert(DeviceSettingsCompanion.insert(singletonId: const Value(1)));
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
      if (from < 3) {
        await transaction(() async {
          final table = await customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' "
            "AND name = 'import_batches'",
          ).get();
          if (table.isEmpty) return;

          final invalidHashes = await customSelect(
            'SELECT id, content_hash FROM import_batches '
            "WHERE length(trim(content_hash)) != 64 "
            "OR trim(content_hash) GLOB '*[^0-9A-Fa-f]*' LIMIT 1",
          ).get();
          if (invalidHashes.isNotEmpty) {
            final row = invalidHashes.single;
            throw StateError(
              'Cannot migrate import_batches: invalid SHA-256 content_hash '
              'for batch ${row.read<String>('id')}',
            );
          }

          const duplicateBatchIds = '''
SELECT id FROM (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY lower(trim(content_hash))
           ORDER BY imported_at_utc, id
         ) AS duplicate_rank
  FROM import_batches
)
WHERE duplicate_rank > 1
''';
          await customStatement(
            "DELETE FROM audit_history WHERE entity_type = 'import_batch' "
            'AND entity_id IN ($duplicateBatchIds)',
          );
          await customStatement(
            'DELETE FROM import_batches WHERE id IN ($duplicateBatchIds)',
          );
          await customStatement(
            'UPDATE import_batches SET content_hash = lower(trim(content_hash))',
          );
          await customStatement(
            'CREATE UNIQUE INDEX import_batches_content_hash_idx '
            'ON import_batches (content_hash COLLATE NOCASE)',
          );
        });
      }
      if (from < 4) {
        await transaction(() async {
          final table = await customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' "
            "AND name = 'message_templates'",
          ).get();
          if (table.isEmpty) {
            await migrator.createTable(messageTemplates);
          } else {
            await migrator.addColumn(
              messageTemplates,
              messageTemplates.isDefault,
            );
          }
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS '
            'message_templates_single_default_idx '
            'ON message_templates (is_default) WHERE is_default = 1',
          );
        });
      }
      if (from < 5) {
        await transaction(() async {
          final depositsTable = await customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' "
            "AND name = 'deposits'",
          ).get();
          if (depositsTable.isNotEmpty) {
            await migrator.addColumn(deposits, deposits.productName);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS deposits_product_name_idx '
              'ON deposits (product_name COLLATE NOCASE)',
            );
          }
          await migrator.createTable(deviceSettings);
          await into(
            deviceSettings,
          ).insert(DeviceSettingsCompanion.insert(singletonId: const Value(1)));
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
      'CREATE INDEX deposits_bank_name_idx '
      'ON deposits (bank_name COLLATE NOCASE)',
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

  /// Exports only cross-device business tables as raw, deterministic-friendly maps.
  Future<Map<String, List<Map<String, Object?>>>> exportBusinessData() async {
    const tables = <String, String>{
      'customers': 'id',
      'deposits': 'id',
      'renewals': 'id',
      'audit_history': 'id',
      'message_templates': 'id',
      'import_batches': 'id',
      'business_settings': 'singleton_id',
    };
    return transaction(() async {
      final result = <String, List<Map<String, Object?>>>{};
      for (final table in tables.entries) {
        final rows = await customSelect(
          'SELECT * FROM ${table.key} ORDER BY ${table.value}',
        ).get();
        result[table.key] = rows
            .map((row) => row.data.map((k, v) => MapEntry(k, v)))
            .toList();
      }
      return result;
    });
  }

  Future<void> replaceBusinessData(
    Map<String, List<Map<String, Object?>>> data,
  ) async {
    await transaction(() => _replaceBusinessDataWithoutTransaction(data));
  }

  Future<bool> replaceBusinessDataIfRevision({
    required Map<String, List<Map<String, Object?>>> data,
    required int expectedBusinessRevision,
  }) => transaction(() async {
    final locked = await customUpdate(
      'UPDATE business_settings SET business_revision = business_revision '
      'WHERE singleton_id = 1',
      updates: {businessSettings},
    );
    if (locked != 1) {
      throw StateError('Business revision singleton is missing');
    }
    if (await businessRevision() != expectedBusinessRevision) return false;
    await _replaceBusinessDataWithoutTransaction(data);
    return true;
  });

  /// Restores [data] only while the expected import is still the latest write.
  ///
  /// The no-op update acquires SQLite's write lock before either guard is read,
  /// so another connection cannot commit a business write between comparison
  /// and replacement.
  Future<bool> restoreLatestExcelImportAtomically({
    required String expectedAuditId,
    required int expectedBusinessRevision,
    required Map<String, List<Map<String, Object?>>> data,
  }) {
    return transaction(() async {
      final locked = await customUpdate(
        'UPDATE business_settings SET business_revision = business_revision '
        'WHERE singleton_id = 1',
        updates: {businessSettings},
      );
      if (locked != 1) {
        throw StateError('Business revision singleton is missing');
      }

      final currentRevision = await businessRevision();
      final latestImport =
          await (select(auditHistory)
                ..where(
                  (entry) =>
                      entry.entityType.equals('import_batch') &
                      entry.operation.equals('excel-import'),
                )
                ..orderBy([
                  (entry) => OrderingTerm.desc(entry.businessRevision),
                  (entry) => OrderingTerm.desc(entry.occurredAtUtc),
                  (entry) => OrderingTerm.desc(entry.id),
                ])
                ..limit(1))
              .getSingleOrNull();
      if (currentRevision != expectedBusinessRevision ||
          latestImport?.id != expectedAuditId ||
          latestImport?.businessRevision != expectedBusinessRevision) {
        return false;
      }

      await _replaceBusinessDataWithoutTransaction(data);
      return true;
    });
  }

  Future<void> _replaceBusinessDataWithoutTransaction(
    Map<String, List<Map<String, Object?>>> data,
  ) async {
    const tables = <String>[
      'customers',
      'deposits',
      'renewals',
      'audit_history',
      'message_templates',
      'import_batches',
      'business_settings',
    ];
    for (final table in const [
      'renewals',
      'audit_history',
      'deposits',
      'customers',
      'message_templates',
      'import_batches',
      'business_settings',
    ]) {
      await customStatement('DELETE FROM $table');
    }
    for (final table in tables) {
      for (final row in data[table] ?? const []) {
        final columns = row.keys.toList()..sort();
        final placeholders = List.filled(columns.length, '?').join(', ');
        await customStatement(
          'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
          columns.map((column) => row[column]).toList(),
        );
      }
    }
    await customStatement('REINDEX');
  }
}
