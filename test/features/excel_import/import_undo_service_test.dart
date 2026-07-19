import 'dart:io';

import 'package:deposit_renewal_manager/core/backup/backup_manifest.dart';
import 'package:deposit_renewal_manager/core/backup/backup_service.dart';
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/features/excel_import/application/import_undo_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory snapshots;

  setUp(() async {
    snapshots = await Directory.systemTemp.createTemp('import-undo-test-');
  });

  tearDown(() async {
    if (await snapshots.exists()) await snapshots.delete(recursive: true);
  });

  test(
    'restores the latest import when no later business write exists',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final backups = _backups(database, snapshots);
      final preImport = await backups.createAutomaticSnapshot('pre-import');
      await _recordImport(database, preImport.path);

      await ImportUndoService(
        database: database,
        backupService: backups,
      ).undoLatest();

      expect(await database.select(database.customers).get(), isEmpty);
      expect(await database.select(database.importBatches).get(), isEmpty);
      expect(await database.select(database.auditHistory).get(), isEmpty);
      expect(await database.businessRevision(), 0);
    },
  );

  test(
    'write injected in the guard window is retained and blocks restore',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final normal = _backups(database, snapshots);
      final preImport = await normal.createAutomaticSnapshot('pre-import');
      await _recordImport(database, preImport.path);
      final injecting = _InjectingBackupService(
        databaseForWrite: database,
        snapshotsDirectory: snapshots,
      );

      await expectLater(
        ImportUndoService(
          database: database,
          backupService: injecting,
        ).undoLatest(),
        throwsStateError,
      );

      expect(await _customerExists(database, 'later-write'), isTrue);
      expect(await _customerExists(database, 'imported'), isTrue);
      expect(await database.businessRevision(), 2);
    },
  );

  test(
    'restore failure leaves revision, audit and business rows unchanged',
    () async {
      final database = _FailingRestoreDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final backups = _backups(database, snapshots);
      final preImport = await backups.createAutomaticSnapshot('pre-import');
      await _recordImport(database, preImport.path);
      final revision = await database.businessRevision();
      final auditCount = await database.auditEntryCount();

      await expectLater(
        ImportUndoService(
          database: database,
          backupService: backups,
        ).undoLatest(),
        throwsA(isA<BackupIntegrityException>()),
      );

      expect(await _customerExists(database, 'imported'), isTrue);
      expect(await database.businessRevision(), revision);
      expect(await database.auditEntryCount(), auditCount);
    },
  );

  test(
    'missing latest snapshot does not fall back to an older import',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final backups = _backups(database, snapshots);
      final firstSnapshot = await backups.createAutomaticSnapshot('pre-import');
      await _recordImport(database, firstSnapshot.path);
      await _recordImport(
        database,
        '${snapshots.path}${Platform.pathSeparator}missing.drbackup',
        batchId: 'batch-2',
        customerId: 'imported-2',
        hash: _hashB,
      );

      await expectLater(
        ImportUndoService(
          database: database,
          backupService: backups,
        ).undoLatest(),
        throwsStateError,
      );

      expect(await _customerExists(database, 'imported'), isTrue);
      expect(await _customerExists(database, 'imported-2'), isTrue);
      expect(await database.businessRevision(), 2);
    },
  );
}

BackupService _backups(AppDatabase database, Directory directory) =>
    BackupService(
      database: database,
      sourceDevice: 'test-device',
      snapshotsDirectory: directory,
    );

Future<void> _recordImport(
  AppDatabase database,
  String snapshotPath, {
  String batchId = 'batch-1',
  String customerId = 'imported',
  String hash = _hashA,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await database.transaction(() async {
    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: customerId,
            name: customerId,
            normalizedName: Value(customerId),
            fullPinyin: Value(customerId),
            initials: Value(customerId[0]),
            normalizedPhone: const Value(''),
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
    final revision = await database.incrementBusinessRevision();
    await database
        .into(database.importBatches)
        .insert(
          ImportBatchesCompanion.insert(
            id: batchId,
            fileName: '$batchId.xlsx',
            contentHash: hash,
            importedAtUtc: now,
            sourceDeviceId: 'test-device',
          ),
        );
    await database
        .into(database.auditHistory)
        .insert(
          AuditHistoryCompanion.insert(
            id: 'audit-$batchId',
            entityType: 'import_batch',
            entityId: batchId,
            operation: 'excel-import',
            afterJson: Value(
              '{"preSnapshotId":${_jsonString(snapshotPath)},"completedRevision":$revision}',
            ),
            occurredAtUtc: now + revision,
            sourceDeviceId: 'test-device',
            businessRevision: revision,
          ),
        );
  });
}

String _jsonString(String value) => '"${value.replaceAll(r'\', r'\\')}"';

Future<bool> _customerExists(AppDatabase database, String id) async =>
    (await (database.select(
      database.customers,
    )..where((c) => c.id.equals(id))).getSingleOrNull()) !=
    null;

class _InjectingBackupService extends BackupService {
  _InjectingBackupService({
    required this.databaseForWrite,
    required super.snapshotsDirectory,
  }) : super(database: databaseForWrite, sourceDevice: 'test-device');

  final AppDatabase databaseForWrite;
  bool injected = false;

  @override
  Future<File> createAutomaticSnapshot(String operation) async {
    final snapshot = await super.createAutomaticSnapshot(operation);
    if (operation == 'import-undo' && !injected) {
      injected = true;
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await databaseForWrite.transaction(() async {
        await databaseForWrite
            .into(databaseForWrite.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'later-write',
                name: 'Later',
                normalizedName: const Value('later'),
                fullPinyin: const Value('later'),
                initials: const Value('l'),
                normalizedPhone: const Value(''),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
        await databaseForWrite.incrementBusinessRevision();
      });
    }
    return snapshot;
  }
}

class _FailingRestoreDatabase extends AppDatabase {
  _FailingRestoreDatabase(super.executor);

  @override
  Future<bool> restoreLatestExcelImportAtomically({
    required String expectedAuditId,
    required int expectedBusinessRevision,
    required Map<String, List<Map<String, Object?>>> data,
  }) async {
    throw StateError('injected restore failure');
  }
}

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
