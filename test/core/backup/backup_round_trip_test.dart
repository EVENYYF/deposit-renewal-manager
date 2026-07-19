import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:deposit_renewal_manager/core/backup/backup_service.dart';
import 'package:deposit_renewal_manager/core/backup/backup_manifest.dart';
import 'package:deposit_renewal_manager/core/backup/safe_zip_reader.dart';
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

  test(
    'restore impact counts current records absent from backup by id',
    () async {
      await CustomerDao(
        target,
        sourceDeviceId: 'windows',
        nowUtc: () => DateTime.utc(2026, 7, 20),
      ).create(const CustomerDraft(id: 'local-only', name: '本机客户'));
      final exporter = BackupService(
        database: source,
        sourceDevice: 'Android',
        snapshotsDirectory: temp,
      );
      final path = (await exporter.exportBackup(
        outputPath: '${temp.path}${Platform.pathSeparator}impact.drbackup',
      )).path;
      final importer = BackupService(
        database: target,
        sourceDevice: 'Windows',
        snapshotsDirectory: temp,
      );
      final inspected = await importer.inspectBackup(path);

      final impact = await importer.inspectRestoreImpact(inspected);

      expect(impact.lostRecords['customers'], 1);
      expect(impact.lostRecords['audit_history'], 1);
      expect(impact.lostRecords['business_settings'], 0);
      expect(impact.totalLost, 2);
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

  test('rejects unknown manifest fields and fractional counts', () async {
    final service = BackupService(
      database: source,
      sourceDevice: 'Android',
      snapshotsDirectory: temp,
    );
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (manifest) => manifest['unexpected'] = true,
      (manifest) => (manifest['counts'] as Map)['customers'] = 0.5,
    ]) {
      final path = (await service.exportBackup(
        outputPath:
            '${temp.path}${Platform.pathSeparator}strict-${DateTime.now().microsecondsSinceEpoch}.drbackup',
      )).path;
      await _rewriteBackup(path, mutateManifest: mutation);
      await expectLater(
        service.inspectBackup(path),
        throwsA(isA<BackupIntegrityException>()),
      );
    }
  });

  test('inspected data is deeply immutable', () async {
    final service = BackupService(
      database: source,
      sourceDevice: 'Android',
      snapshotsDirectory: temp,
    );
    final backup = await service.inspectBackup(
      (await service.exportBackup(
        outputPath: '${temp.path}${Platform.pathSeparator}immutable.drbackup',
      )).path,
    );
    expect(() => backup.data['customers']!.clear(), throwsUnsupportedError);
    expect(
      () => backup.data['customers']!.single['name'] = 'tampered',
      throwsUnsupportedError,
    );
    expect(() => backup.manifest.counts.clear(), throwsUnsupportedError);
  });

  test('rejects archive length and abnormal compression ratio', () async {
    final path = '${temp.path}${Platform.pathSeparator}bounded.drbackup';
    await File(path).writeAsBytes(List.filled(128, 0));
    await expectLater(
      BackupService(
        database: source,
        sourceDevice: 'Android',
        snapshotsDirectory: temp,
        limits: const BackupLimits(maxArchiveBytes: 64),
      ).inspectBackup(path),
      throwsA(isA<BackupIntegrityException>()),
    );
    final valid =
        await BackupService(
          database: source,
          sourceDevice: 'Android',
          snapshotsDirectory: temp,
        ).exportBackup(
          outputPath: '${temp.path}${Platform.pathSeparator}ratio.drbackup',
        );
    await expectLater(
      BackupService(
        database: source,
        sourceDevice: 'Android',
        snapshotsDirectory: temp,
        limits: const BackupLimits(maxCompressionRatio: 1),
      ).inspectBackup(valid.path),
      throwsA(isA<BackupIntegrityException>()),
    );
  });

  test('rejects symlink metadata and forged uncompressed size', () async {
    final service = BackupService(
      database: source,
      sourceDevice: 'Android',
      snapshotsDirectory: temp,
    );
    final original = await service.exportBackup(
      outputPath: '${temp.path}${Platform.pathSeparator}metadata.drbackup',
    );
    final symlink = await original.readAsBytes();
    _patchCentralEntry(symlink, 'data.json', externalMode: 0xa000);
    final symlinkPath = '${temp.path}${Platform.pathSeparator}symlink.drbackup';
    await File(symlinkPath).writeAsBytes(symlink);
    await expectLater(
      service.inspectBackup(symlinkPath),
      throwsA(isA<BackupIntegrityException>()),
    );

    final forged = await original.readAsBytes();
    _patchCentralEntry(forged, 'data.json', uncompressedSize: 16);
    final forgedPath = '${temp.path}${Platform.pathSeparator}forged.drbackup';
    await File(forgedPath).writeAsBytes(forged);
    await expectLater(
      service.inspectBackup(forgedPath),
      throwsA(isA<BackupIntegrityException>()),
    );

    final descriptor = await original.readAsBytes();
    _patchCentralEntry(descriptor, 'data.json', flags: 0x808);
    final descriptorPath =
        '${temp.path}${Platform.pathSeparator}descriptor.drbackup';
    await File(descriptorPath).writeAsBytes(descriptor);
    await expectLater(
      service.inspectBackup(descriptorPath),
      throwsA(isA<BackupIntegrityException>()),
    );
  });

  test('rejects escaped duplicate JSON object keys', () async {
    final service = BackupService(
      database: source,
      sourceDevice: 'Android',
      snapshotsDirectory: temp,
    );
    final path = (await service.exportBackup(
      outputPath: '${temp.path}${Platform.pathSeparator}duplicate-key.drbackup',
    )).path;
    await _rewriteBackup(
      path,
      mutateData: (bytes) {
        final text = utf8.decode(bytes);
        return utf8.encode(
          text.replaceFirst(
            '"customers":',
            '"cust\\u006fmers":[],"customers":',
          ),
        );
      },
      repairHash: true,
    );
    await expectLater(
      service.inspectBackup(path),
      throwsA(isA<BackupIntegrityException>()),
    );
  });

  test('rejects deep JSON and invalid business invariants', () async {
    final regular = BackupService(
      database: source,
      sourceDevice: 'Android',
      snapshotsDirectory: temp,
    );
    final deepPath = (await regular.exportBackup(
      outputPath: '${temp.path}${Platform.pathSeparator}deep.drbackup',
    )).path;
    await _rewriteBackup(
      deepPath,
      mutateDecodedData: (data) => data['unknown'] = [
        [
          [
            [
              [0],
            ],
          ],
        ],
      ],
      repairHash: true,
    );
    await expectLater(
      BackupService(
        database: source,
        sourceDevice: 'Android',
        snapshotsDirectory: temp,
        limits: const BackupLimits(maxJsonDepth: 4),
      ).inspectBackup(deepPath),
      throwsA(isA<BackupIntegrityException>()),
    );

    for (final mutation in <void Function(Map<String, dynamic>)>[
      (data) => (data['business_settings'] as List).clear(),
      (data) {
        final settings = data['business_settings'] as List;
        settings.add(Map<String, dynamic>.from(settings.single as Map));
      },
      (data) => ((data['customers'] as List).single as Map)['name'] = '   ',
      (data) => ((data['customers'] as List).single as Map)['name'] = null,
      (data) {
        _populateValidRows(data);
        ((data['deposits'] as List).first as Map)['amount_cents'] = 1.5;
      },
      (data) {
        _populateValidRows(data);
        ((data['renewals'] as List).single as Map)['renewed_at_utc'] = 0;
      },
      (data) {
        _populateValidRows(data);
        ((data['audit_history'] as List).single as Map)['business_revision'] =
            0;
      },
      (data) {
        _populateValidRows(data);
        ((data['message_templates'] as List).single as Map)['is_active'] = 2;
      },
      (data) {
        _populateValidRows(data);
        ((data['message_templates'] as List).single as Map)['is_default'] = 2;
      },
      (data) {
        _populateValidRows(data);
        ((data['import_batches'] as List).single as Map)['imported_rows'] = -1;
      },
      (data) =>
          ((data['business_settings'] as List).single as Map)['singleton_id'] =
              2,
    ]) {
      final path = (await regular.exportBackup(
        outputPath:
            '${temp.path}${Platform.pathSeparator}invariant-${DateTime.now().microsecondsSinceEpoch}.drbackup',
      )).path;
      await _rewriteBackup(
        path,
        mutateDecodedData: mutation,
        repairHash: true,
        repairCounts: true,
      );
      await expectLater(
        regular.inspectBackup(path),
        throwsA(isA<BackupIntegrityException>()),
      );
    }
  });

  test('export limit failure does not create a file', () async {
    final path = '${temp.path}${Platform.pathSeparator}must-not-exist.drbackup';
    await expectLater(
      BackupService(
        database: source,
        sourceDevice: 'Android',
        snapshotsDirectory: temp,
        limits: const BackupLimits(maxRowsPerTable: 0),
      ).exportBackup(outputPath: path),
      throwsA(isA<BackupIntegrityException>()),
    );
    expect(await File(path).exists(), isFalse);
  });
}

Future<void> _rewriteBackup(
  String path, {
  void Function(Map<String, dynamic>)? mutateManifest,
  List<int> Function(List<int>)? mutateData,
  void Function(Map<String, dynamic>)? mutateDecodedData,
  bool repairHash = false,
  bool repairCounts = false,
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
  if (repairCounts) {
    manifest['counts'] = {
      for (final entry in (jsonDecode(utf8.decode(data)) as Map).entries)
        entry.key: (entry.value as List).length,
    };
  }
  if (repairHash) manifest['payloadSha256'] = sha256.convert(data).toString();
  final manifestBytes = utf8.encode(jsonEncode(manifest));
  final archive = Archive()
    ..addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes))
    ..addFile(ArchiveFile('data.json', data.length, data));
  await File(path).writeAsBytes(ZipEncoder().encode(archive)!);
}

void _patchCentralEntry(
  List<int> bytes,
  String target, {
  int? externalMode,
  int? uncompressedSize,
  int? flags,
}) {
  for (var i = 0; i + 46 <= bytes.length; i++) {
    if (_u32(bytes, i) != 0x02014b50) continue;
    final nameLength = _u16(bytes, i + 28);
    final name = utf8.decode(bytes.sublist(i + 46, i + 46 + nameLength));
    if (name != target) continue;
    if (externalMode != null) _writeU32(bytes, i + 38, externalMode << 16);
    if (uncompressedSize != null) {
      _writeU32(bytes, i + 24, uncompressedSize);
      _writeU32(bytes, _u32(bytes, i + 42) + 22, uncompressedSize);
    }
    if (flags != null) {
      _writeU16(bytes, i + 8, flags);
      _writeU16(bytes, _u32(bytes, i + 42) + 6, flags);
    }
    return;
  }
  fail('Central directory entry not found: $target');
}

int _u16(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);
int _u32(List<int> bytes, int offset) =>
    _u16(bytes, offset) | (_u16(bytes, offset + 2) << 16);
void _writeU32(List<int> bytes, int offset, int value) {
  for (var i = 0; i < 4; i++) {
    bytes[offset + i] = (value >> (8 * i)) & 0xff;
  }
}

void _writeU16(List<int> bytes, int offset, int value) {
  bytes[offset] = value & 0xff;
  bytes[offset + 1] = (value >> 8) & 0xff;
}

void _populateValidRows(Map<String, dynamic> data) {
  const epoch = 1784419200000000;
  data['deposits'] = [
    {
      'id': 'd1',
      'customer_id': 'c1',
      'amount_cents': 100,
      'bank_name': 'Bank',
      'interest_rate_scaled': 10,
      'rate_precision': 2,
      'start_date': '2026-07-19',
      'calculated_expiry_date': null,
      'final_expiry_date': '2027-07-19',
      'lifecycle': 'active',
      'created_at_utc': epoch,
      'updated_at_utc': epoch,
      'source_device_id': 'device',
    },
    {
      'id': 'd2',
      'customer_id': 'c1',
      'amount_cents': 100,
      'bank_name': 'Bank',
      'interest_rate_scaled': 10,
      'rate_precision': 2,
      'start_date': '2027-07-19',
      'calculated_expiry_date': null,
      'final_expiry_date': '2028-07-19',
      'lifecycle': 'active',
      'created_at_utc': epoch,
      'updated_at_utc': epoch,
      'source_device_id': 'device',
    },
  ];
  data['renewals'] = [
    {
      'id': 'r1',
      'source_deposit_id': 'd1',
      'target_deposit_id': 'd2',
      'renewed_at_utc': epoch,
      'source_device_id': 'device',
    },
  ];
  data['audit_history'] = [
    {
      'id': 'a1',
      'entity_type': 'customer',
      'entity_id': 'c1',
      'operation': 'create',
      'before_json': null,
      'after_json': '{}',
      'occurred_at_utc': epoch,
      'source_device_id': 'device',
      'business_revision': 1,
    },
  ];
  data['message_templates'] = [
    {
      'id': 'm1',
      'name': 'Template',
      'content': 'Hello',
      'is_active': 1,
      'is_default': 0,
      'created_at_utc': epoch,
      'updated_at_utc': epoch,
    },
  ];
  data['import_batches'] = [
    {
      'id': 'i1',
      'file_name': 'input.xlsx',
      'content_hash': 'hash',
      'imported_rows': 1,
      'rejected_rows': 0,
      'imported_at_utc': epoch,
      'source_device_id': 'device',
    },
  ];
}
