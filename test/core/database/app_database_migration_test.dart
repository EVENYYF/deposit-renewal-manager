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

  test('migrates v2 import batches and creates a unique hash index', () async {
    final file = await _createV2File();
    addTearDown(() => _deleteDatabaseFiles(file));

    final database = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(database.close);
    expect(
      await database
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE name = 'import_batches_content_hash_idx'",
          )
          .get(),
      hasLength(1),
    );
    expect(
      await database.customSelect('SELECT * FROM import_batches').get(),
      hasLength(2),
    );
  });

  test(
    'v2 migration rejects duplicate hashes without changing version',
    () async {
      final file = await _createV2File(duplicateHash: true);
      addTearDown(() => _deleteDatabaseFiles(file));

      final database = AppDatabase.forTesting(NativeDatabase(file));
      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('duplicate content_hash'),
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
    },
  );
}

Future<File> _createV2File({bool duplicateHash = false}) async {
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
  ('batch-1', 'a.xlsx', 'hash-a', 1, 0, 1, 'test'),
  ('batch-2', 'b.xlsx', '${duplicateHash ? 'hash-a' : 'hash-b'}', 1, 0, 1, 'test');
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
