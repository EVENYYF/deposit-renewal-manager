import 'dart:async';
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
        preview: _preview(row, duplicate: true),
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
        preview: _preview(row, duplicate: true),
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
        preview: _preview(row, duplicate: true),
        decisions: {2: DuplicateDecision.skip},
      );
      expect(skipped.skippedRows, 1);
      expect(await database.select(database.deposits).get(), isEmpty);

      final created = await service.commit(
        fileName: 'separate.xlsx',
        fileBytes: [4],
        preview: _preview(row, duplicate: true),
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
        throwsA(isA<DuplicateImportException>()),
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

  test('requires resolved preview and explicit duplicate decision', () async {
    final row = _row(name: 'New', phone: '13900139000');
    await expectLater(
      service.commit(
        fileName: 'unresolved.xlsx',
        fileBytes: [10],
        preview: ImportPreview(rows: [row], mapping: const {}),
      ),
      throwsStateError,
    );
    await expectLater(
      service.commit(
        fileName: 'missing-decision.xlsx',
        fileBytes: [11],
        preview: _preview(row, duplicate: true),
      ),
      throwsStateError,
    );
  });

  test('rejects unknown rows and choices for non-attach decisions', () async {
    final row = _row(name: 'New Name', phone: '13800138000');
    final duplicate = _preview(row, duplicate: true);
    await expectLater(
      service.commit(
        fileName: 'unknown-row.xlsx',
        fileBytes: [12],
        preview: duplicate,
        decisions: {999: DuplicateDecision.skip},
      ),
      throwsStateError,
    );
    for (final decision in [
      DuplicateDecision.skip,
      DuplicateDecision.createSeparate,
    ]) {
      await expectLater(
        service.commit(
          fileName: 'choices-$decision.xlsx',
          fileBytes: [13, decision.index],
          preview: duplicate,
          decisions: {2: decision},
          fieldChoices: {
            2: {'name': true},
          },
        ),
        throwsStateError,
      );
    }
    await expectLater(
      service.commit(
        fileName: 'not-conflict.xlsx',
        fileBytes: [14],
        preview: duplicate,
        decisions: {2: DuplicateDecision.attachToExisting},
        fieldChoices: {
          2: {'bankName': true},
        },
      ),
      throwsStateError,
    );
  });

  test('concurrent commits with one content hash have one winner', () async {
    final bothSnapshotsStarted = Completer<void>();
    var snapshotCalls = 0;
    Future<File> snapshot() async {
      snapshotCalls++;
      if (snapshotCalls == 2) bothSnapshotsStarted.complete();
      await bothSnapshotsStarted.future;
      return File('pre-import-$snapshotCalls.drbackup');
    }

    final first = ImportCommitService(
      database: database,
      sourceDeviceId: 'test-device',
      createSnapshot: snapshot,
    );
    final second = ImportCommitService(
      database: database,
      sourceDeviceId: 'test-device',
      createSnapshot: snapshot,
    );
    final preview = _preview(_row(name: 'Race', phone: '13900139000'));
    final outcomes = await Future.wait<Object>([
      first
          .commit(fileName: 'race-a.xlsx', fileBytes: [99], preview: preview)
          .then<Object>((value) => value, onError: (Object error) => error),
      second
          .commit(fileName: 'race-b.xlsx', fileBytes: [99], preview: preview)
          .then<Object>((value) => value, onError: (Object error) => error),
    ]);

    expect(outcomes.whereType<ImportResult>(), hasLength(1));
    expect(outcomes.whereType<DuplicateImportException>(), hasLength(1));
    expect(await database.select(database.importBatches).get(), hasLength(1));
    expect(await database.select(database.deposits).get(), hasLength(1));
  });
}

ImportPreview _preview(ImportRow row, {bool duplicate = false}) =>
    ImportPreview(
      rows: [row],
      mapping: const {},
      duplicatesResolved: true,
      candidates: duplicate
          ? [
              DuplicateCandidate(
                row: row,
                existingCustomerId: 'existing',
                fieldConflicts: {
                  'name': (
                    oldValue: 'Old Name',
                    newValue: row.normalized['name'],
                  ),
                  'phone': (
                    oldValue: '13800138000',
                    newValue: row.normalized['phone'],
                  ),
                },
              ),
            ]
          : const [],
    );

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
