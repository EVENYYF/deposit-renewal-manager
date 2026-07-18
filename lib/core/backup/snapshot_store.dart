import 'dart:io';

import 'package:path/path.dart' as p;

class SnapshotInfo {
  const SnapshotInfo({
    required this.file,
    required this.createdAtUtc,
    required this.operation,
  });
  final File file;
  final DateTime createdAtUtc;
  final String operation;
}

class SnapshotStore {
  SnapshotStore(this.directory, {this.maxAutomaticSnapshots = 10});

  final Directory directory;
  final int maxAutomaticSnapshots;

  Future<File> allocateAutomatic(DateTime nowUtc, String operation) async {
    await directory.create(recursive: true);
    final safeOperation = operation.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final stamp = nowUtc.toUtc().toIso8601String().replaceAll(':', '-');
    var suffix = 0;
    while (true) {
      final tail = suffix == 0 ? '' : '_${suffix.toString().padLeft(3, '0')}';
      final candidate = File(
        p.join(directory.path, 'auto_${stamp}_$safeOperation$tail.drbackup'),
      );
      if (!await candidate.exists()) return candidate;
      suffix++;
    }
  }

  Future<List<SnapshotInfo>> listAutomatic() async {
    if (!await directory.exists()) return const [];
    final root = p.canonicalize(directory.absolute.path);
    final result = <SnapshotInfo>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File ||
          !p.basename(entity.path).startsWith('auto_') ||
          p.extension(entity.path) != '.drbackup') {
        continue;
      }
      final canonical = p.canonicalize(entity.absolute.path);
      if (!p.isWithin(root, canonical)) continue;
      final stat = await entity.stat();
      final name = p.basenameWithoutExtension(entity.path).substring(5);
      final split = name.lastIndexOf('_');
      result.add(
        SnapshotInfo(
          file: entity,
          createdAtUtc: stat.modified.toUtc(),
          operation: split < 0 ? 'unknown' : name.substring(split + 1),
        ),
      );
    }
    result.sort(
      (a, b) => p.basename(b.file.path).compareTo(p.basename(a.file.path)),
    );
    return result;
  }

  Future<void> pruneAutomatic() async {
    final snapshots = await listAutomatic();
    for (final snapshot in snapshots.skip(maxAutomaticSnapshots)) {
      final root = p.canonicalize(directory.absolute.path);
      final target = p.canonicalize(snapshot.file.absolute.path);
      if (p.isWithin(root, target) && p.basename(target).startsWith('auto_')) {
        await snapshot.file.delete();
      }
    }
  }
}
