import 'dart:io';

import 'package:deposit_renewal_manager/core/backup/backup_service.dart';
import 'package:deposit_renewal_manager/core/backup/snapshot_policy_service.dart';
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late Directory directory;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp('snapshot-policy-');
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'scheduled snapshot requires due interval and revision change',
    () async {
      var now = DateTime.utc(2026, 7, 20);
      final backup = BackupService(
        database: database,
        sourceDevice: 'test-device',
        snapshotsDirectory: directory,
        nowUtc: () => now,
      );
      final policy = SnapshotPolicyService(
        database: database,
        backupService: backup,
        nowUtc: () => now,
      );

      expect(await policy.isDue(), isFalse);
      await database.incrementBusinessRevision();
      expect(await policy.isDue(), isTrue);
      await policy.reconcile();
      expect(await backup.listSnapshots(), hasLength(1));

      await database.incrementBusinessRevision();
      expect(await policy.isDue(), isFalse);
      now = now.add(const Duration(days: 1));
      expect(await policy.isDue(), isTrue);
    },
  );

  test('disabled policy skips scheduled snapshots', () async {
    final backup = BackupService(
      database: database,
      sourceDevice: 'test-device',
      snapshotsDirectory: directory,
    );
    final policy = SnapshotPolicyService(
      database: database,
      backupService: backup,
    );
    await policy.update(enabled: false);
    await database.incrementBusinessRevision();

    await policy.reconcile();

    expect(await backup.listSnapshots(), isEmpty);
  });
}
