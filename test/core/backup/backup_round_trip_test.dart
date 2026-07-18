import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:deposit_renewal_manager/core/backup/backup_service.dart';
import 'package:deposit_renewal_manager/core/backup/backup_manifest.dart';
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';

void main() {
  late Directory temp;
  late AppDatabase source;
  late AppDatabase target;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('backup-roundtrip-');
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
    await CustomerDao(
      source,
      sourceDeviceId: 'android',
      nowUtc: () => DateTime.utc(2026, 7, 19),
    ).create(const CustomerDraft(id: 'c1', name: 'Alice', phone: '123'));
    await target
        .into(target.notificationIdMappings)
        .insert(
          NotificationIdMappingsCompanion.insert(
            entityId: 'local',
            notificationId: 7,
            createdAtUtc: 1,
          ),
        );
  });

  tearDown(() async {
    await source.close();
    await target.close();
    await temp.delete(recursive: true);
  });

  test(
    'round trips business data and preserves device-local mappings',
    () async {
      final exporter = BackupService(
        database: source,
        sourceDevice: 'Android',
        snapshotsDirectory: temp,
      );
      final backup = await exporter.exportBackup(
        outputPath: '${temp.path}${Platform.pathSeparator}manual.drbackup',
      );
      final importer = BackupService(
        database: target,
        sourceDevice: 'Windows',
        snapshotsDirectory: temp,
      );
      await importer.restore(await importer.inspectBackup(backup.path));
      expect(
        (await target.select(target.customers).get()).map((r) => r.id),
        contains('c1'),
      );
      expect(
        (await target.select(target.notificationIdMappings).get())
            .single
            .notificationId,
        7,
      );
    },
  );

  test('rejects corrupt zip and payload hash mismatch', () async {
    final service = BackupService(
      database: source,
      sourceDevice: 'Android',
      snapshotsDirectory: temp,
    );
    final corruptPath = '${temp.path}${Platform.pathSeparator}corrupt.drbackup';
    await File(corruptPath).writeAsBytes([1, 2, 3]);
    await expectLater(
      service.inspectBackup(corruptPath),
      throwsA(isA<BackupIntegrityException>()),
    );

    final path = (await service.exportBackup(
      outputPath: '${temp.path}${Platform.pathSeparator}bad.drbackup',
    )).path;
    await _rewriteBackup(path, mutateData: (data) => [...data, 0]);
    await expectLater(
      service.inspectBackup(path),
      throwsA(isA<BackupIntegrityException>()),
    );
  });

  test('rejects unsupported format and schema versions', () async {
    final service = BackupService(
      database: source,
      sourceDevice: 'Android',
      snapshotsDirectory: temp,
    );
    for (final entry in {'formatVersion': 2, 'schemaVersion': 99}.entries) {
      final path = (await service.exportBackup(
        outputPath:
            '${temp.path}${Platform.pathSeparator}${entry.key}.drbackup',
      )).path;
      await _rewriteBackup(
        path,
        mutateManifest: (manifest) => manifest[entry.key] = entry.value,
      );
      await expectLater(
        service.inspectBackup(path),
        throwsA(isA<BackupIntegrityException>()),
      );
    }
  });

  test('rejects invalid row structure even with a valid hash', () async {
    final service = BackupService(
      database: source,
      sourceDevice: 'Android',
      snapshotsDirectory: temp,
    );
    final path = (await service.exportBackup(
      outputPath: '${temp.path}${Platform.pathSeparator}structure.drbackup',
    )).path;
    await _rewriteBackup(
      path,
      mutateDecodedData: (data) {
        final customers = data['customers']! as List;
        (customers.single as Map).remove('name');
      },
      repairHash: true,
    );
    await expectLater(
      service.inspectBackup(path),
      throwsA(isA<BackupIntegrityException>()),
    );
  });
}

Future<void> _rewriteBackup(
  String path, {
  void Function(Map<String, dynamic>)? mutateManifest,
  List<int> Function(List<int>)? mutateData,
  void Function(Map<String, dynamic>)? mutateDecodedData,
  bool repairHash = false,
}) async {
  final decoded = ZipDecoder().decodeBytes(await File(path).readAsBytes());
  final manifest =
      jsonDecode(utf8.decode(decoded.findFile('manifest.json')!.content))
          as Map<String, dynamic>;
  var data = List<int>.from(decoded.findFile('data.json')!.content);
  if (mutateDecodedData != null) {
    final payload = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    mutateDecodedData(payload);
    data = utf8.encode(jsonEncode(payload));
  }
  if (mutateData != null) data = mutateData(data);
  mutateManifest?.call(manifest);
  if (repairHash) manifest['payloadSha256'] = sha256.convert(data).toString();
  final manifestBytes = utf8.encode(jsonEncode(manifest));
  final archive = Archive()
    ..addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes))
    ..addFile(ArchiveFile('data.json', data.length, data));
  await File(path).writeAsBytes(ZipEncoder().encode(archive)!);
}
