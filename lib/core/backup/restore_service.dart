import 'dart:io';

import 'backup_manifest.dart';
import 'backup_service.dart';
import '../database/app_database.dart';

typedef SnapshotCreator = Future<File> Function();

class RestoreService {
  const RestoreService({
    required this.database,
    required this.createAutomaticSnapshot,
    this.expectedBusinessRevision,
  });
  final AppDatabase database;
  final SnapshotCreator createAutomaticSnapshot;
  final int? expectedBusinessRevision;

  Future<void> restore(InspectedBackup backup) async {
    await createAutomaticSnapshot();
    try {
      final expected = expectedBusinessRevision;
      if (expected == null) {
        await database.replaceBusinessData(backup.data);
      } else {
        final restored = await database.replaceBusinessDataIfRevision(
          data: backup.data,
          expectedBusinessRevision: expected,
        );
        if (!restored) {
          throw StateError('Business data changed after restore preview');
        }
      }
    } catch (e) {
      throw BackupIntegrityException(
        'Restore failed; database transaction rolled back: $e',
      );
    }
  }
}
