import 'dart:io';

import 'package:deposit_renewal_manager/core/backup/backup_service.dart';
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late AppDatabase database;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('backup-snapshot-');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await CustomerDao(
      database,
      sourceDeviceId: 'device',
      nowUtc: () => DateTime.utc(2026, 7, 19),
    ).create(const CustomerDraft(id: 'c1', name: 'Alice'));
  });

  tearDown(() async {
    await database.close();
    await temp.delete(recursive: true);
  });

  test(
    'keeps only ten automatic snapshots and preserves manual exports',
    () async {
      final service = BackupService(
        database: database,
        sourceDevice: 'device',
        snapshotsDirectory: temp,
        nowUtc: () => DateTime.utc(2026, 7, 19, 10),
      );
      for (var i = 0; i < 12; i++) {
        await service.exportBackup(automatic: true);
      }
      expect(await service.listSnapshots(), hasLength(10));
      final manual = await service.exportBackup(
        outputPath: '${temp.path}${Platform.pathSeparator}manual.drbackup',
      );
      expect(await manual.exists(), isTrue);
    },
  );

  test(
    'failed restore leaves original data unchanged after pre-restore snapshot',
    () async {
      final service = BackupService(
        database: database,
        sourceDevice: 'device',
        snapshotsDirectory: temp,
      );
      final valid = await service.inspectBackup(
        (await service.exportBackup(
          outputPath: '${temp.path}${Platform.pathSeparator}source.drbackup',
        )).path,
      );
      final brokenData = <String, List<Map<String, Object?>>>{
        for (final entry in valid.data.entries)
          entry.key: [
            for (final row in entry.value) Map<String, Object?>.from(row),
          ],
      };
      brokenData['deposits']!.add({
        'id': 'bad',
        'customer_id': 'missing',
        'amount_cents': 1,
        'bank_name': '',
        'interest_rate_scaled': 1,
        'rate_precision': 1,
        'start_date': '2026-07-19',
        'calculated_expiry_date': null,
        'final_expiry_date': '2026-07-19',
        'lifecycle': 'active',
        'created_at_utc': 1,
        'updated_at_utc': 1,
        'source_device_id': 'x',
      });
      await expectLater(
        service.restore(
          InspectedBackup(
            path: valid.path,
            manifest: valid.manifest,
            data: brokenData,
          ),
        ),
        throwsA(isA<Exception>()),
      );
      expect((await database.select(database.customers).get()).single.id, 'c1');
      expect(await service.listSnapshots(), hasLength(1));
    },
  );
}
