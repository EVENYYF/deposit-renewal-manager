import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'backup_manifest.dart';
import 'restore_service.dart';
import 'snapshot_store.dart';

class InspectedBackup {
  const InspectedBackup({
    required this.path,
    required this.manifest,
    required this.data,
  });
  final String path;
  final BackupManifest manifest;
  final Map<String, List<Map<String, Object?>>> data;
}

class BackupService {
  BackupService({
    required this.database,
    required this.sourceDevice,
    Directory? snapshotsDirectory,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => clock.now().toUtc()),
       snapshots = SnapshotStore(
         snapshotsDirectory ??
             Directory(
               p.join(Directory.systemTemp.path, 'deposit_renewal_snapshots'),
             ),
       );

  final AppDatabase database;
  final String sourceDevice;
  final DateTime Function() _nowUtc;
  final SnapshotStore snapshots;

  Future<File> exportBackup({
    String? outputPath,
    bool automatic = false,
    String automaticOperation = 'export',
  }) async {
    final now = _nowUtc().toUtc();
    final file = outputPath == null
        ? (automatic
              ? await snapshots.allocateAutomatic(now, automaticOperation)
              : File(
                  p.join(
                    snapshots.directory.path,
                    'manual_${now.microsecondsSinceEpoch}.drbackup',
                  ),
                ))
        : File(outputPath);
    await file.parent.create(recursive: true);
    final data = await database.exportBusinessData();
    final payload = utf8.encode(_encodeDeterministic(data));
    final counts = {
      for (final entry in data.entries) entry.key: entry.value.length,
    };
    final manifest = BackupManifest(
      formatVersion: 1,
      schemaVersion: database.schemaVersion,
      sourceDevice: sourceDevice,
      createdAtUtc: now,
      counts: counts,
      payloadSha256: sha256.convert(payload).toString(),
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'manifest.json',
          utf8.encode(manifest.encode()).length,
          utf8.encode(manifest.encode()),
        ),
      )
      ..addFile(ArchiveFile('data.json', payload.length, payload));
    await file.writeAsBytes(ZipEncoder().encode(archive)!, flush: true);
    if (automatic) await snapshots.pruneAutomatic();
    return file;
  }

  Future<InspectedBackup> inspectBackup(String path) async {
    final bytes = await File(path).readAsBytes();
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      if (archive.files.length != 2 ||
          archive.files.any(
            (file) => file.name != 'manifest.json' && file.name != 'data.json',
          )) {
        throw const BackupIntegrityException('Unexpected archive entries');
      }
      final manifestEntry = archive.files
          .where((f) => f.name == 'manifest.json')
          .single;
      final dataEntry = archive.files
          .where((f) => f.name == 'data.json')
          .single;
      final manifest = BackupManifest.fromJson(
        jsonDecode(utf8.decode(manifestEntry.content)) as Map<String, dynamic>,
      );
      if (manifest.formatVersion != 1) {
        throw const BackupIntegrityException('Unsupported format version');
      }
      if (manifest.schemaVersion != database.schemaVersion) {
        throw const BackupIntegrityException('Unsupported schema version');
      }
      final payload = dataEntry.content;
      if (sha256.convert(payload).toString() != manifest.payloadSha256) {
        throw const BackupIntegrityException('Payload hash mismatch');
      }
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is! Map) {
        throw const BackupIntegrityException('Invalid payload structure');
      }
      final data = <String, List<Map<String, Object?>>>{};
      for (final entry in decoded.entries) {
        if (entry.value is! List) {
          throw const BackupIntegrityException('Invalid table payload');
        }
        data[entry.key.toString()] = [
          for (final row in entry.value as List)
            Map<String, Object?>.from(row as Map),
        ];
      }
      const expected = {
        'customers',
        'deposits',
        'renewals',
        'audit_history',
        'message_templates',
        'import_batches',
        'business_settings',
      };
      if (!data.keys.toSet().containsAll(expected) ||
          data.keys.any((k) => !expected.contains(k))) {
        throw const BackupIntegrityException('Unexpected tables');
      }
      for (final table in expected) {
        if (manifest.counts[table] != data[table]!.length) {
          throw const BackupIntegrityException('Row count mismatch');
        }
      }
      _validateRows(data);
      return InspectedBackup(path: path, manifest: manifest, data: data);
    } on BackupIntegrityException {
      rethrow;
    } catch (e) {
      throw BackupIntegrityException('Invalid backup archive: $e');
    }
  }

  Future<void> restore(InspectedBackup backup) async {
    final restorer = RestoreService(
      database: database,
      createAutomaticSnapshot: () => createAutomaticSnapshot('restore'),
    );
    await restorer.restore(backup);
  }

  Future<File> createAutomaticSnapshot(String operation) =>
      exportBackup(automatic: true, automaticOperation: operation);

  Future<List<SnapshotInfo>> listSnapshots() => snapshots.listAutomatic();

  void _validateRows(Map<String, List<Map<String, Object?>>> data) {
    const columns = <String, Set<String>>{
      'customers': {
        'id',
        'name',
        'phone',
        'normalized_name',
        'full_pinyin',
        'initials',
        'normalized_phone',
        'is_active',
        'created_at_utc',
        'updated_at_utc',
      },
      'deposits': {
        'id',
        'customer_id',
        'amount_cents',
        'bank_name',
        'interest_rate_scaled',
        'rate_precision',
        'start_date',
        'calculated_expiry_date',
        'final_expiry_date',
        'lifecycle',
        'created_at_utc',
        'updated_at_utc',
        'source_device_id',
      },
      'renewals': {
        'id',
        'source_deposit_id',
        'target_deposit_id',
        'renewed_at_utc',
        'source_device_id',
      },
      'audit_history': {
        'id',
        'entity_type',
        'entity_id',
        'operation',
        'before_json',
        'after_json',
        'occurred_at_utc',
        'source_device_id',
        'business_revision',
      },
      'message_templates': {
        'id',
        'name',
        'content',
        'is_active',
        'created_at_utc',
        'updated_at_utc',
      },
      'import_batches': {
        'id',
        'file_name',
        'content_hash',
        'imported_rows',
        'rejected_rows',
        'imported_at_utc',
        'source_device_id',
      },
      'business_settings': {'singleton_id', 'business_revision'},
    };
    for (final table in columns.entries) {
      for (final row in data[table.key]!) {
        if (row.keys.toSet().length != table.value.length ||
            !row.keys.toSet().containsAll(table.value) ||
            row.values.any(
              (value) =>
                  value is! String &&
                  value is! num &&
                  value is! bool &&
                  value != null,
            )) {
          throw BackupIntegrityException(
            'Invalid row structure in ${table.key}',
          );
        }
      }
    }
  }

  String _encodeDeterministic(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return '{${entries.map((e) => '${jsonEncode(e.key.toString())}:${_encodeDeterministic(e.value)}').join(',')}}';
    }
    if (value is List) return '[${value.map(_encodeDeterministic).join(',')}]';
    return jsonEncode(value);
  }
}
