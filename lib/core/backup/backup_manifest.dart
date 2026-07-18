import 'dart:convert';

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.sourceDevice,
    required this.createdAtUtc,
    required this.counts,
    required this.payloadSha256,
  });

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
    final counts = json['counts'];
    if (json['formatVersion'] is! int ||
        json['schemaVersion'] is! int ||
        json['sourceDevice'] is! String ||
        json['createdAtUtc'] is! String ||
        counts is! Map ||
        json['payloadSha256'] is! String) {
      throw const FormatException('Invalid backup manifest');
    }
    return BackupManifest(
      formatVersion: json['formatVersion'] as int,
      schemaVersion: json['schemaVersion'] as int,
      sourceDevice: json['sourceDevice'] as String,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      counts: {
        for (final e in counts.entries)
          e.key.toString(): (e.value as num).toInt(),
      },
      payloadSha256: json['payloadSha256'] as String,
    );
  }

  String encode() => jsonEncode(toJson());
}

class BackupIntegrityException implements Exception {
  const BackupIntegrityException(this.message);
  final String message;
  @override
  String toString() => 'BackupIntegrityException: $message';
}
