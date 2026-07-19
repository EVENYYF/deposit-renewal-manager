import 'dart:convert';
import 'dart:io';
import 'dart:collection';

import 'package:archive/archive.dart';
import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'backup_manifest.dart';
import 'restore_service.dart';
import 'safe_zip_reader.dart';
import 'snapshot_store.dart';

class InspectedBackup {
  InspectedBackup({
    required this.path,
    required this.manifest,
    required Map<String, List<Map<String, Object?>>> data,
  }) : data = _deepFreeze(data),
       _token = null;
  InspectedBackup._trusted({
    required this.path,
    required this.manifest,
    required Map<String, List<Map<String, Object?>>> data,
  }) : data = _deepFreeze(data),
       _token = _secret;
  static final Object _secret = Object();
  final Object? _token;
  final String path;
  final BackupManifest manifest;
  final Map<String, List<Map<String, Object?>>> data;
  bool get _trustedToken => identical(_token, _secret);

  static Map<String, List<Map<String, Object?>>> _deepFreeze(
    Map<String, List<Map<String, Object?>>> source,
  ) => UnmodifiableMapView({
    for (final e in source.entries)
      e.key: UnmodifiableListView([
        for (final row in e.value) UnmodifiableMapView(row),
      ]),
  });
}

final class RestoreImpact {
  RestoreImpact({required Map<String, int> lostRecords})
    : lostRecords = UnmodifiableMapView(Map<String, int>.from(lostRecords));

  final Map<String, int> lostRecords;
  int get totalLost => lostRecords.values.fold(0, (sum, value) => sum + value);
}

class BackupService {
  BackupService({
    required this.database,
    required this.sourceDevice,
    Directory? snapshotsDirectory,
    DateTime Function()? nowUtc,
    this.limits = const BackupLimits(),
    RealPathResolver? realPathResolver,
    Future<File> Function(File source, String target)? renameFile,
  }) : _nowUtc = nowUtc ?? (() => clock.now().toUtc()),
       _renameFile = renameFile ?? _defaultRename,
       snapshots = SnapshotStore(
         snapshotsDirectory ??
             Directory(
               p.join(Directory.systemTemp.path, 'deposit_renewal_snapshots'),
             ),
         realPathResolver: realPathResolver,
       );

  final AppDatabase database;
  final String sourceDevice;
  final DateTime Function() _nowUtc;
  final SnapshotStore snapshots;
  final BackupLimits limits;
  final Future<File> Function(File source, String target) _renameFile;

  static Future<File> _defaultRename(File source, String target) =>
      source.rename(target);

  Future<File> exportBackup({
    String? outputPath,
    bool automatic = false,
    String automaticOperation = 'export',
  }) async {
    final now = _nowUtc().toUtc();
    final file = outputPath == null
        ? File(
            p.join(
              snapshots.directory.path,
              'manual_${now.microsecondsSinceEpoch}.drbackup',
            ),
          )
        : File(outputPath);
    if (!automatic && await snapshots.isInAutomaticDirectory(file)) {
      throw const BackupIntegrityException(
        'Manual backups cannot be written to the automatic snapshot directory',
      );
    }
    if (!automatic && await file.exists()) {
      throw BackupTargetExistsException(file.path);
    }
    final data = await database.exportBusinessData();
    _validateRows(data);
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
    BackupManifest.fromJson(manifest.toJson());
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'manifest.json',
          utf8.encode(manifest.encode()).length,
          utf8.encode(manifest.encode()),
        ),
      )
      ..addFile(ArchiveFile('data.json', payload.length, payload));
    final encoded = ZipEncoder().encode(archive)!;
    _inspectEncodedEntries(
      SafeZipReader(limits).readBytes(encoded),
      path: file.path,
    );
    if (automatic) {
      return snapshots.writeAutomatic(encoded, now, automaticOperation, (
        temporary,
      ) async {
        await inspectBackup(temporary.path);
      });
    }
    await _writeAtomically(file, encoded);
    return file;
  }

  Future<InspectedBackup> inspectBackup(String path) async {
    try {
      final entries = await SafeZipReader(limits).read(File(path));
      return _inspectEncodedEntries(entries, path: path);
    } on BackupIntegrityException {
      rethrow;
    } catch (e) {
      throw BackupIntegrityException('Invalid backup archive: $e');
    }
  }

  InspectedBackup _inspectEncodedEntries(
    Map<String, List<int>> entries, {
    required String path,
  }) {
    try {
      final manifestText = utf8.decode(entries['manifest.json']!);
      _preflightJson(manifestText);
      final manifest = BackupManifest.fromJson(
        jsonDecode(manifestText) as Map<String, dynamic>,
      );
      if (manifest.formatVersion != 1) {
        throw const BackupIntegrityException('Unsupported format version');
      }
      if (manifest.schemaVersion != database.schemaVersion) {
        throw const BackupIntegrityException('Unsupported schema version');
      }
      final payload = entries['data.json']!;
      if (sha256.convert(payload).toString() != manifest.payloadSha256) {
        throw const BackupIntegrityException('Payload hash mismatch');
      }
      final payloadText = utf8.decode(payload);
      _preflightJson(payloadText);
      final decoded = jsonDecode(payloadText);
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
      return InspectedBackup._trusted(
        path: path,
        manifest: manifest,
        data: data,
      );
    } on BackupIntegrityException {
      rethrow;
    } catch (e) {
      throw BackupIntegrityException('Invalid backup archive: $e');
    }
  }

  Future<void> restore(InspectedBackup backup) async {
    if (!backup._trustedToken) {
      throw const BackupIntegrityException('Backup was not inspected');
    }
    final restorer = RestoreService(
      database: database,
      createAutomaticSnapshot: () => createAutomaticSnapshot('restore'),
    );
    await restorer.restore(backup);
  }

  Future<RestoreImpact> inspectRestoreImpact(InspectedBackup backup) async {
    if (!backup._trustedToken) {
      throw const BackupIntegrityException('Backup was not inspected');
    }
    const primaryKeys = <String, String>{
      'customers': 'id',
      'deposits': 'id',
      'renewals': 'id',
      'audit_history': 'id',
      'message_templates': 'id',
      'import_batches': 'id',
      'business_settings': 'singleton_id',
    };
    final current = await database.exportBusinessData();
    final lost = <String, int>{};
    for (final entry in primaryKeys.entries) {
      final backupKeys = backup.data[entry.key]!
          .map((row) => row[entry.value])
          .toSet();
      lost[entry.key] = current[entry.key]!
          .where((row) => !backupKeys.contains(row[entry.value]))
          .length;
    }
    return RestoreImpact(lostRecords: lost);
  }

  Future<File> createAutomaticSnapshot(String operation) =>
      exportBackup(automatic: true, automaticOperation: operation);

  Future<List<SnapshotInfo>> listSnapshots() => snapshots.listAutomatic();

  Future<void> _writeAtomically(File target, List<int> bytes) async {
    await target.parent.create(recursive: true);
    await _withTargetLock(target, () async {
      if (await target.exists()) {
        throw BackupTargetExistsException(target.path);
      }
      final temp = File(
        '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      try {
        await temp.writeAsBytes(bytes, flush: true);
        await inspectBackup(temp.path);
        if (await target.exists()) {
          throw BackupTargetExistsException(target.path);
        }
        await _renameFile(temp, target.path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    });
  }

  Future<T> _withTargetLock<T>(File target, Future<T> Function() action) async {
    final lock = await File(
      p.join(target.parent.path, '.${p.basename(target.path)}.lock'),
    ).open(mode: FileMode.append);
    var acquired = false;
    try {
      for (var attempt = 0; attempt < 400; attempt++) {
        try {
          await lock.lock(FileLock.exclusive);
          acquired = true;
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }
      if (!acquired) {
        throw const FileSystemException(
          'Timed out acquiring backup target lock',
        );
      }
      return await action();
    } finally {
      if (acquired) await lock.unlock();
      await lock.close();
    }
  }

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
        'is_default',
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
      if (data[table.key]!.length > limits.maxRowsPerTable) {
        throw const BackupIntegrityException('Too many rows');
      }
      for (final row in data[table.key]!) {
        if (row.keys.toSet().length != table.value.length ||
            !row.keys.toSet().containsAll(table.value) ||
            !_validateRowTypes(table.key, row)) {
          throw BackupIntegrityException(
            'Invalid row structure in ${table.key}',
          );
        }
      }
    }
    if (data['business_settings']!.length != 1) {
      throw const BackupIntegrityException(
        'business_settings must contain exactly one row',
      );
    }
  }

  bool _validateRowTypes(String table, Map<String, Object?> row) {
    const ints = {
      'created_at_utc',
      'updated_at_utc',
      'amount_cents',
      'interest_rate_scaled',
      'rate_precision',
      'renewed_at_utc',
      'occurred_at_utc',
      'imported_at_utc',
      'business_revision',
      'imported_rows',
      'rejected_rows',
      'singleton_id',
      'is_active',
      'is_default',
    };
    const nullable = {
      'phone',
      'calculated_expiry_date',
      'before_json',
      'after_json',
    };
    for (final e in row.entries) {
      final v = e.value;
      if (ints.contains(e.key) && v is! int) return false;
      if ((e.key == 'is_active' || e.key == 'is_default') && v != 0 && v != 1) {
        return false;
      }
      if (!ints.contains(e.key) && v != null && v is! String) return false;
      if (v == null && !nullable.contains(e.key)) return false;
      if (v is String && v.length > 1024 * 1024) return false;
      if (e.key.endsWith('_utc') &&
          v is int &&
          (v <= 0 || v > 4102444800000000)) {
        return false;
      }
    }
    if (table == 'deposits') {
      final p = row['rate_precision'];
      if (p is! int || p < 0 || p > 9) return false;
      if (row['amount_cents'] is! int || (row['amount_cents'] as int) <= 0) {
        return false;
      }
      if ((row['interest_rate_scaled'] as int) < 0) return false;
      if (row['lifecycle'] is! String ||
          !{'active', 'renewed', 'stopped'}.contains(row['lifecycle'])) {
        return false;
      }
      for (final key in [
        'start_date',
        'calculated_expiry_date',
        'final_expiry_date',
      ]) {
        final value = row[key];
        if (value != null && !_validDate(value as String)) return false;
      }
    }
    if (table == 'customers' && ((row['name'] as String).trim().isEmpty)) {
      return false;
    }
    for (final key in [
      'id',
      'customer_id',
      'source_deposit_id',
      'target_deposit_id',
    ]) {
      final value = row[key];
      if (value is String && value.isEmpty) return false;
    }
    for (final key in ['imported_rows', 'rejected_rows']) {
      final value = row[key];
      if (value is int && value < 0) return false;
    }
    if (table == 'business_settings' &&
        (row['singleton_id'] != 1 || (row['business_revision'] as int) < 0)) {
      return false;
    }
    if (table == 'audit_history' && (row['business_revision'] as int) <= 0) {
      return false;
    }
    return true;
  }

  bool _validDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    try {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final d = DateTime.utc(year, month, day);
      return year >= 1970 &&
          year <= 2100 &&
          d.year == year &&
          d.month == month &&
          d.day == day;
    } catch (_) {
      return false;
    }
  }

  void _preflightJson(String source) {
    var depth = 0;
    var tokens = 0;
    var inString = false;
    var escaped = false;
    var stringStart = -1;
    final containers = <Set<String>?>[];
    for (var i = 0; i < source.length; i++) {
      final code = source.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5c) {
          escaped = true;
        } else if (code == 0x22) {
          inString = false;
          tokens++;
          var next = i + 1;
          while (next < source.length &&
              const {
                0x20,
                0x09,
                0x0a,
                0x0d,
              }.contains(source.codeUnitAt(next))) {
            next++;
          }
          if (next < source.length &&
              source.codeUnitAt(next) == 0x3a &&
              containers.isNotEmpty &&
              containers.last != null) {
            final key = jsonDecode(source.substring(stringStart, i + 1));
            if (key is! String || !containers.last!.add(key)) {
              throw const BackupIntegrityException('Duplicate JSON object key');
            }
          }
        }
        continue;
      }
      if (code == 0x22) {
        inString = true;
        stringStart = i;
      } else if (code == 0x7b || code == 0x5b) {
        depth++;
        containers.add(code == 0x7b ? <String>{} : null);
        tokens++;
        if (depth > limits.maxJsonDepth) {
          throw const BackupIntegrityException('JSON too deep');
        }
      } else if (code == 0x7d || code == 0x5d) {
        depth--;
        tokens++;
        final closingObject = code == 0x7d;
        if (depth < 0 ||
            containers.isEmpty ||
            (closingObject != (containers.last != null))) {
          throw const BackupIntegrityException('Invalid JSON structure');
        }
        containers.removeLast();
      } else if (code == 0x2c || code == 0x3a) {
        tokens++;
      }
      if (tokens > limits.maxJsonTokens) {
        throw const BackupIntegrityException('JSON token limit exceeded');
      }
    }
    if (inString || escaped || depth != 0) {
      throw const BackupIntegrityException('Invalid JSON structure');
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
