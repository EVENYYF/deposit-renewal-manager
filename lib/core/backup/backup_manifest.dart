import 'dart:convert';
import 'dart:collection';

class BackupManifest {
  BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.sourceDevice,
    required this.createdAtUtc,
    required Map<String, int> counts,
    required this.payloadSha256,
  }) : counts = UnmodifiableMapView(Map<String, int>.from(counts));

  final int formatVersion;
  final int schemaVersion;
  final String sourceDevice;
  final DateTime createdAtUtc;
  final Map<String, int> counts;
  final String payloadSha256;

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'sourceDevice': sourceDevice,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'counts': Map.fromEntries(
      counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
    'payloadSha256': payloadSha256,
  };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    const fields = {
      'formatVersion',
      'schemaVersion',
      'sourceDevice',
      'createdAtUtc',
      'counts',
      'payloadSha256',
    };
    if (json.keys.toSet().difference(fields).isNotEmpty ||
        json.keys.toSet().length != fields.length) {
      throw const FormatException('Unknown or missing manifest fields');
    }
    final counts = json['counts'];
    if (json['formatVersion'] is! int ||
        json['schemaVersion'] is! int ||
        json['sourceDevice'] is! String ||
        json['createdAtUtc'] is! String ||
        counts is! Map ||
        json['payloadSha256'] is! String) {
      throw const FormatException('Invalid backup manifest');
    }
    final sourceDevice = json['sourceDevice'] as String;
    final hash = json['payloadSha256'] as String;
    final createdAt = DateTime.tryParse(json['createdAtUtc'] as String);
    if (sourceDevice.isEmpty ||
        sourceDevice.length > 256 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
        createdAt == null ||
        !createdAt.isUtc ||
        createdAt.year < 1970 ||
        createdAt.year > 2100) {
      throw const FormatException('Invalid backup manifest values');
    }
    return BackupManifest(
      formatVersion: json['formatVersion'] as int,
      schemaVersion: json['schemaVersion'] as int,
      sourceDevice: sourceDevice,
      createdAtUtc: createdAt,
      counts: _parseCounts(counts),
      payloadSha256: hash,
    );
  }

  static Map<String, int> _parseCounts(Object? value) {
    if (value is! Map) throw const FormatException('Invalid counts');
    const tables = {
      'customers',
      'deposits',
      'renewals',
      'audit_history',
      'message_templates',
      'import_batches',
      'business_settings',
    };
    if (value.keys.any((k) => k is! String || !tables.contains(k)) ||
        value.length != tables.length) {
      throw const FormatException('Invalid count keys');
    }
    return {
      for (final e in value.entries) e.key as String: _nonNegativeInt(e.value),
    };
  }

  static int _nonNegativeInt(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid count');
    }
    return value;
  }

  String encode() => jsonEncode(toJson());
}

class BackupIntegrityException implements Exception {
  const BackupIntegrityException(this.message);
  final String message;
  @override
  String toString() => 'BackupIntegrityException: $message';
}

class BackupTargetExistsException extends BackupIntegrityException {
  const BackupTargetExistsException(String path)
    : super('Backup target already exists: $path');
}
