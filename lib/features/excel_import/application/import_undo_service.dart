import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/backup/backup_manifest.dart';
import '../../../core/database/app_database.dart';

class ImportUndoService {
  const ImportUndoService({
    required this.database,
    required this.backupService,
  });
  final AppDatabase database;
  final BackupService backupService;

  Future<String?> canUndoLatest() async {
    final rows =
        await (database.select(database.auditHistory)
              ..where(
                (a) =>
                    a.entityType.equals('import_batch') &
                    a.operation.equals('excel-import'),
              )
              ..orderBy([(a) => OrderingTerm.desc(a.businessRevision)])
              ..limit(1))
            .get();
    if (rows.isEmpty) {
      return 'no import batch';
    }
    final entry = rows.first;
    final current = await database.businessRevision();
    if (current != entry.businessRevision) {
      return 'blocked: subsequent business writes exist';
    }
    return null;
  }

  Future<void> undoLatest() async {
    final entry =
        await (database.select(database.auditHistory)
              ..where(
                (a) =>
                    a.entityType.equals('import_batch') &
                    a.operation.equals('excel-import'),
              )
              ..orderBy([(a) => OrderingTerm.desc(a.businessRevision)])
              ..limit(1))
            .getSingle();
    final payload = jsonDecode(entry.afterJson ?? '{}') as Map<String, dynamic>;
    final path = payload['preSnapshotId'] as String?;
    if (path == null || !await File(path).exists()) {
      throw StateError('pre-import snapshot is unavailable');
    }
    final inspected = await backupService.inspectBackup(path);
    await backupService.createAutomaticSnapshot('import-undo');
    late final bool restored;
    try {
      restored = await database.restoreLatestExcelImportAtomically(
        expectedAuditId: entry.id,
        expectedBusinessRevision: entry.businessRevision,
        data: inspected.data,
      );
    } catch (e) {
      throw BackupIntegrityException(
        'Restore failed; database transaction rolled back: $e',
      );
    }
    if (!restored) {
      throw StateError('blocked: subsequent business writes exist');
    }
  }
}
