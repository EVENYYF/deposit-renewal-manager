import 'dart:io';

import 'backup_manifest.dart';
import 'backup_service.dart';
import '../database/app_database.dart';

typedef SnapshotCreator = Future<File> Function();

class RestoreService {
  const RestoreService({
    required this.database,
    required this.createAutomaticSnapshot,
  });
  final AppDatabase database;
  final SnapshotCreator createAutomaticSnapshot;

  Future<void> restore(InspectedBackup backup) async {
    await createAutomaticSnapshot();
    try {
      await database.replaceBusinessData(backup.data);
    } catch (e) {
      throw BackupIntegrityException(
        'Restore failed; database transaction rolled back: $e',
      );
    }
  }
}
