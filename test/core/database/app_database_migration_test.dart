import 'dart:io';

import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

void main() {
  test('migrates a real v1 file database and backfills search data', () async {
    final file = await _createV1File();
    addTearDown(() => _deleteDatabaseFiles(file));

    final database = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(database.close);

    final customers = await database
        .customSelect(
          'SELECT id, normalized_name, full_pinyin, initials, normalized_phone '
          'FROM customers ORDER BY id',
        )
        .get();
    expect(customers[0].read<String>('normalized_name'), 'alice');
    expect(customers[0].read<String>('full_pinyin'), 'alice');
    expect(customers[1].read<String>('normalized_name'), '\u5f20\u4e09');
    expect(customers[1].read<String>('full_pinyin'), 'zhangsan');
    expect(customers[1].read<String>('initials'), 'zs');
    expect(customers[1].read<String>('normalized_phone'), '13800138000');

    final deposit = await database
        .customSelect("SELECT bank_name FROM deposits WHERE id = 'old-deposit'")
        .getSingle();
    expect(deposit.read<String>('bank_name'), isEmpty);

    final indexes = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')),
      containsAll(<String>{
        'customers_normalized_name_idx',
        'customers_full_pinyin_idx',
        'customers_initials_idx',
        'customers_normalized_phone_idx',
        'deposits_bank_name_idx',
        'deposits_expiry_lifecycle_customer_idx',
      }),
    );
    final bankIndex = await database
        .customSelect(
          "SELECT sql FROM sqlite_master "
          "WHERE name = 'deposits_bank_name_idx'",
        )
        .getSingle();
    expect(bankIndex.read<String>('sql'), contains('COLLATE NOCASE'));
  });

  test('failed v1 migration leaves no partial schema changes', () async {
    final file = await _createV1File(conflictingIndex: true);
    addTearDown(() => _deleteDatabaseFiles(file));

    final database = AppDatabase.forTesting(NativeDatabase(file));
    await expectLater(
      database.customSelect('SELECT 1').get(),
      throwsA(isA<Exception>()),
    );
    await database.close();

    final raw = sqlite.sqlite3.open(file.path);
    addTearDown(raw.dispose);
    final columns = raw.select('PRAGMA table_info(customers)');
    expect(columns.map((row) => row['name']), isNot(contains('full_pinyin')));
    expect(raw.select('PRAGMA user_version').single['user_version'], 1);
  });

  test(
    'migrates v2 hashes, deduplicates batches and cleans audit history',
    () async {
      final file = await _createV2File();
      addTearDown(() => _deleteDatabaseFiles(file));

      final database = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(database.close);
      final index = await database
          .customSelect(
            "SELECT sql FROM sqlite_master "
            "WHERE name = 'import_batches_content_hash_idx'",
          )
          .getSingle();
      expect(index.read<String>('sql'), contains('COLLATE NOCASE'));

      final batches = await database
          .customSelect(
            'SELECT id, content_hash FROM import_batches ORDER BY id',
          )
          .get();
      expect(batches, hasLength(2));
      expect(batches[0].read<String>('id'), 'batch-3');
      expect(batches[0].read<String>('content_hash'), _hashB);
      expect(batches[1].read<String>('id'), 'batch-a');
      expect(batches[1].read<String>('content_hash'), _hashA);

      final audits = await database
          .customSelect('SELECT id FROM audit_history ORDER BY id')
          .get();
      expect(audits.map((row) => row.read<String>('id')), [
        'audit-a',
        'audit-other',
      ]);
    },
  );

  test(
    'v2 migration rejects invalid hashes without changing version',
    () async {
      final file = await _createV2File(invalidHash: true);
      addTearDown(() => _deleteDatabaseFiles(file));

      final database = AppDatabase.forTesting(NativeDatabase(file));
      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('invalid SHA-256 content_hash'),
          ),
        ),
      );
      await database.close();

      final raw = sqlite.sqlite3.open(file.path);
      addTearDown(raw.dispose);
      expect(raw.select('PRAGMA user_version').single['user_version'], 2);
      expect(
        raw.select(
          "SELECT name FROM sqlite_master "
          "WHERE name = 'import_batches_content_hash_idx'",
        ),
        isEmpty,
      );
      expect(
        raw
            .select('SELECT COUNT(*) AS count FROM import_batches')
            .single['count'],
        4,
      );
      expect(
        raw
            .select('SELECT COUNT(*) AS count FROM audit_history')
            .single['count'],
        4,
      );
    },
  );

  test(
    'migrates v3 templates with no default and enforces one default',
    () async {
      final file = await _createV3File();
      addTearDown(() => _deleteDatabaseFiles(file));

      final database = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(database.close);
      final migrated = await database
          .customSelect(
            'SELECT id, is_default FROM message_templates ORDER BY id',
          )
          .get();
      expect(migrated.map((row) => row.read<int>('is_default')), [0, 0]);
      final index = await database
          .customSelect(
            "SELECT sql FROM sqlite_master "
            "WHERE name = 'message_templates_single_default_idx'",
          )
          .getSingle();
      expect(index.read<String>('sql'), contains('WHERE is_default = 1'));

      await database.customUpdate(
        "UPDATE message_templates SET is_default = 1 WHERE id = 'a'",
        updates: {database.messageTemplates},
      );
      await expectLater(
        database.customUpdate(
          "UPDATE message_templates SET is_default = 1 WHERE id = 'b'",
          updates: {database.messageTemplates},
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'migrates a real v6 file and creates an empty product catalog',
    () async {
      final file = await _createV6File();
      addTearDown(() => _deleteDatabaseFiles(file));

      final database = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(database.close);

      expect(database.schemaVersion, 7);
      expect(
        await database.customSelect('SELECT name FROM customers').get(),
        hasLength(1),
      );
      expect(
        await database.customSelect('SELECT id FROM deposits').get(),
        hasLength(1),
      );
      expect(
        await database.customSelect('SELECT id FROM deposit_presets').get(),
        hasLength(1),
      );
      final productCount = await database
          .customSelect('SELECT COUNT(*) AS count FROM products')
          .getSingle();
      final rateCount = await database
          .customSelect('SELECT COUNT(*) AS count FROM product_rate_versions')
          .getSingle();
      expect(productCount.read<int>('count'), 0);
      expect(rateCount.read<int>('count'), 0);

      final indexes = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      expect(
        indexes.map((row) => row.read<String>('name')),
        containsAll(<String>[
          'products_bank_name_product_name_idx',
          'product_rate_versions_product_date_idx',
          'product_rate_versions_product_id_idx',
        ]),
      );
    },
  );
}

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Future<File> _createV3File() async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'deposit-v3-${const Uuid().v4()}.sqlite',
  );
  final raw = sqlite.sqlite3.open(file.path);
  raw.execute('''
CREATE TABLE message_templates (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  content TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL
);
INSERT INTO message_templates VALUES
  ('a', 'A', 'content-a', 1, 1, 1),
  ('b', 'B', 'content-b', 0, 1, 1);
PRAGMA user_version = 3;
''');
  raw.dispose();
  return file;
}

Future<File> _createV6File() async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'deposit-v6-${const Uuid().v4()}.sqlite',
  );
  final raw = sqlite.sqlite3.open(file.path);
  raw.execute('''
CREATE TABLE customers (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  normalized_name TEXT NOT NULL DEFAULT '',
  full_pinyin TEXT NOT NULL DEFAULT '',
  initials TEXT NOT NULL DEFAULT '',
  normalized_phone TEXT NOT NULL DEFAULT '',
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL
);
CREATE TABLE deposits (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES customers(id),
  amount_cents INTEGER NOT NULL,
  bank_name TEXT NOT NULL DEFAULT '',
  product_name TEXT NOT NULL DEFAULT '',
  term_value INTEGER,
  term_unit TEXT,
  interest_rate_scaled INTEGER NOT NULL,
  rate_precision INTEGER NOT NULL,
  start_date TEXT NOT NULL,
  calculated_expiry_date TEXT,
  final_expiry_date TEXT NOT NULL,
  lifecycle TEXT NOT NULL,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  source_device_id TEXT NOT NULL
);
CREATE TABLE deposit_presets (
  id TEXT NOT NULL PRIMARY KEY,
  field_type TEXT NOT NULL,
  value TEXT NOT NULL,
  created_at_utc INTEGER NOT NULL
);
INSERT INTO customers VALUES ('c1', 'Legacy', NULL, '', '', '', '', 1, 1, 1);
INSERT INTO deposits VALUES ('d1', 'c1', 100, 'Bank', 'Product', NULL, NULL, 10, 2,
  '2026-01-01', NULL, '2027-01-01', 'active', 1, 1, 'legacy');
INSERT INTO deposit_presets VALUES ('preset-1', 'bank', 'Bank', 1);
PRAGMA user_version = 6;
''');
  raw.dispose();
  return file;
}

Future<File> _createV2File({bool invalidHash = false}) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'deposit-v2-${const Uuid().v4()}.sqlite',
  );
  final raw = sqlite.sqlite3.open(file.path);
  raw.execute('''
CREATE TABLE import_batches (
  id TEXT NOT NULL PRIMARY KEY,
  file_name TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  imported_rows INTEGER NOT NULL DEFAULT 0,
  rejected_rows INTEGER NOT NULL DEFAULT 0,
  imported_at_utc INTEGER NOT NULL,
  source_device_id TEXT NOT NULL
);
INSERT INTO import_batches VALUES
  ('batch-z', 'z.xlsx', '${invalidHash ? 'invalid' : _hashA.toUpperCase()}', 1, 0, 2, 'test'),
  ('batch-b', 'b.xlsx', '$_hashA', 1, 0, 1, 'test'),
  ('batch-a', 'a.xlsx', ' $_hashA ', 1, 0, 1, 'test'),
  ('batch-3', 'c.xlsx', '$_hashB', 1, 0, 3, 'test');
CREATE TABLE audit_history (
  id TEXT NOT NULL PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  before_json TEXT,
  after_json TEXT,
  occurred_at_utc INTEGER NOT NULL,
  source_device_id TEXT NOT NULL,
  business_revision INTEGER NOT NULL
);
INSERT INTO audit_history VALUES
  ('audit-a', 'import_batch', 'batch-a', 'excel-import', NULL, NULL, 1, 'test', 1),
  ('audit-b', 'import_batch', 'batch-b', 'excel-import', NULL, NULL, 1, 'test', 2),
  ('audit-z', 'import_batch', 'batch-z', 'excel-import', NULL, NULL, 2, 'test', 3),
  ('audit-other', 'deposit', 'batch-b', 'create', NULL, NULL, 1, 'test', 4);
PRAGMA user_version = 2;
''');
  raw.dispose();
  return file;
}

Future<File> _createV1File({bool conflictingIndex = false}) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'deposit-v1-${const Uuid().v4()}.sqlite',
  );
  final raw = sqlite.sqlite3.open(file.path);
  raw.execute('''
CREATE TABLE customers (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL
);
CREATE TABLE deposits (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES customers(id),
  amount_cents INTEGER NOT NULL,
  interest_rate_scaled INTEGER NOT NULL,
  rate_precision INTEGER NOT NULL,
  start_date TEXT NOT NULL,
  calculated_expiry_date TEXT,
  final_expiry_date TEXT NOT NULL,
  lifecycle TEXT NOT NULL,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  source_device_id TEXT NOT NULL
);
INSERT INTO customers VALUES
  ('a', 'Alice', NULL, 1, 1, 1),
  ('z', '\u5f20\u4e09', '138 0013-8000', 1, 1, 1);
INSERT INTO deposits VALUES
  ('old-deposit', 'z', 10000, 215, 4, '2026-01-01', NULL,
   '2027-01-01', 'active', 1, 1, 'v1-device');
PRAGMA user_version = 1;
''');
  if (conflictingIndex) {
    raw.execute(
      'CREATE INDEX customers_normalized_name_idx ON customers (name)',
    );
  }
  raw.dispose();
  return file;
}

Future<void> _deleteDatabaseFiles(File databaseFile) async {
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final file = File('${databaseFile.path}$suffix');
    if (await file.exists()) await file.delete();
  }
}
