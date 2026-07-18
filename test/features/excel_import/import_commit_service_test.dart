import 'dart:io';

import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/features/excel_import/application/import_commit_service.dart';
import 'package:deposit_renewal_manager/features/excel_import/domain/import_models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ImportCommitService service;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    service = ImportCommitService(
      database: database,
      sourceDeviceId: 'test-device',
      createSnapshot: () async => File('pre-import.drbackup'),
    );
  });

  tearDown(() => database.close());

  test('resolver returns duplicate conflicts and all decisions', () async {
    await _insertCustomer(database, name: 'Old Name', phone: '13800138000');
    final row = _row(name: 'New Name', phone: '138-0013-8000');

    final candidates = await service.resolveDuplicates(_preview(row));

    expect(candidates, hasLength(1));
    expect(candidates.single.existingCustomerId, 'existing');
    expect(
      candidates.single.fieldConflicts.keys,
      containsAll(['name', 'phone']),
    );
    expect(
      candidates.single.availableDecisions,
      DuplicateDecision.values.toSet(),
    );
  });

  test(
    'attach preserves old fields by default and applies chosen conflicts',
    () async {
      await _insertCustomer(database, name: 'Old Name', phone: '13800138000');
      final row = _row(name: 'New Name', phone: '138-0013-8000');

      await service.commit(
        fileName: 'attach.xlsx',
        fileBytes: [1],
        preview: _preview(row),
        decisions: {2: DuplicateDecision.attachToExisting},
      );
      var customer = await (database.select(
        database.customers,
      )..where((c) => c.id.equals('existing'))).getSingle();
      expect(customer.name, 'Old Name');
      expect(customer.phone, '13800138000');

      await service.commit(
        fileName: 'override.xlsx',
        fileBytes: [2],
        preview: _preview(row),
        decisions: {2: DuplicateDecision.attachToExisting},
        fieldChoices: {
          2: {'name': true, 'phone': true},
        },
      );
      customer = await (database.select(
        database.customers,
      )..where((c) => c.id.equals('existing'))).getSingle();
      expect(customer.name, 'New Name');
      expect(customer.phone, '138-0013-8000');
      expect(customer.normalizedPhone, '13800138000');
      expect(customer.normalizedName, isNotEmpty);
    },
  );

  test(
    'skip duplicate and createSeparate with same phone are honored',
    () async {
      await _insertCustomer(database, name: 'Old Name', phone: '13800138000');
      final row = _row(name: 'New Name', phone: '13800138000');
      final skipped = await service.commit(
        fileName: 'skip.xlsx',
        fileBytes: [3],
        preview: _preview(row),
        decisions: {2: DuplicateDecision.skip},
      );
      expect(skipped.skippedRows, 1);
      expect(await database.select(database.deposits).get(), isEmpty);

      final created = await service.commit(
        fileName: 'separate.xlsx',
        fileBytes: [4],
        preview: _preview(row),
        decisions: {2: DuplicateDecision.createSeparate},
      );
      expect(created.importedRows, 1);
      expect(await database.select(database.customers).get(), hasLength(2));
    },
  );

  test(
    'strictly rejects decisions and choices that do not match duplicates',
    () async {
      final row = _row(name: 'New', phone: '13900139000');
      await expectLater(
        service.commit(
          fileName: 'bad-attach.xlsx',
          fileBytes: [5],
          preview: _preview(row),
          decisions: {2: DuplicateDecision.attachToExisting},
        ),
        throwsStateError,
      );
      await expectLater(
        service.commit(
          fileName: 'bad-skip.xlsx',
          fileBytes: [6],
          preview: _preview(row),
          decisions: {2: DuplicateDecision.skip},
        ),
        throwsStateError,
      );
      await expectLater(
        service.commit(
          fileName: 'bad-choice.xlsx',
          fileBytes: [7],
          preview: _preview(row),
          fieldChoices: {
            2: {'bankName': true},
          },
        ),
        throwsStateError,
      );
    },
  );

  test(
    'hash is idempotent and notification failure is returned as warning',
    () async {
      final failingHookService = ImportCommitService(
        database: database,
        sourceDeviceId: 'test-device',
        createSnapshot: () async => File('pre-import.drbackup'),
        notificationReconcile: (_) async => throw StateError('hook failed'),
      );
      final result = await failingHookService.commit(
        fileName: 'once.xlsx',
        fileBytes: [8],
        preview: _preview(_row(name: 'New', phone: '13900139000')),
      );
      expect(result.warnings.single, contains('hook failed'));
      await expectLater(
        failingHookService.commit(
          fileName: 'again.xlsx',
          fileBytes: [8],
          preview: _preview(_row(name: 'Other', phone: '13700137000')),
        ),
        throwsStateError,
      );
      expect(await database.select(database.importBatches).get(), hasLength(1));
    },
  );

  test('persists fixed-point interest rate and audit metadata', () async {
    final result = await service.commit(
      fileName: 'rate.xlsx',
      fileBytes: [9],
      preview: _preview(_row(name: 'New', phone: '13900139000')),
    );
    final deposit = await database.select(database.deposits).getSingle();
    expect(deposit.interestRateScaled, 125);
    expect(deposit.ratePrecision, 2);
    final audit = await database.select(database.auditHistory).getSingle();
    expect(audit.afterJson, contains('contentHash'));
    expect(audit.afterJson, contains(result.preSnapshotId));
  });
}

ImportPreview _preview(ImportRow row) =>
    ImportPreview(rows: [row], mapping: const {});

ImportRow _row({required String name, required String phone}) => ImportRow(
  rowNumber: 2,
  raw: const {},
  normalized: {
    'name': name,
    'phone': phone,
    'normalizedPhone': phone.replaceAll('-', ''),
    'amountCents': 10000,
    'startDate': '2026-01-01',
    'term': 12,
    'interestRateScaled': 125,
    'ratePrecision': 2,
  },
);

Future<void> _insertCustomer(
  AppDatabase database, {
  required String name,
  required String phone,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await database
      .into(database.customers)
      .insert(
        CustomersCompanion.insert(
          id: 'existing',
          name: name,
          phone: Value(phone),
          normalizedName: const Value('oldname'),
          fullPinyin: const Value('oldname'),
          initials: const Value('on'),
          normalizedPhone: Value(phone.replaceAll('-', '')),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
}
