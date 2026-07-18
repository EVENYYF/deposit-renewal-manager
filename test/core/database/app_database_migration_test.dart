import 'dart:io';

import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('migrates a real v1 file database and backfills search data', () async {
    final file = await _createV1File();
    addTearDown(() async {
      if (file.existsSync()) file.deleteSync();
    });

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
        .customSelect(
          "SELECT bank_name FROM deposits WHERE id = 'old-deposit'",
        )
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
  });

  test('failed v1 migration leaves no partial schema changes', () async {
    final file = await _createV1File(conflictingIndex: true);
    addTearDown(() async {
      if (file.existsSync()) file.deleteSync();
    });

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
}

Future<File> _createV1File({bool conflictingIndex = false}) async {
  final directory = await Directory.systemTemp.createTemp('deposit-v1-');
  final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');
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
