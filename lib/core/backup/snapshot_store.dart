import 'dart:io';
import 'dart:math';

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
  Future<void> _queue = Future.value();
  Directory get _automaticDirectory =>
      Directory(p.join(directory.path, 'automatic'));

  bool isInAutomaticDirectory(File file) {
    final root = p.canonicalize(_automaticDirectory.absolute.path);
    final target = p.canonicalize(file.absolute.path);
    return target == root || p.isWithin(root, target);
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<File> _allocateAutomatic(DateTime nowUtc, String operation) async {
    await _automaticDirectory.create(recursive: true);
    final safeOperation = operation.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final stamp = nowUtc.toUtc().toIso8601String().replaceAll(':', '-');
    while (true) {
      final nonce = _secureNonce();
      final candidate = File(
        p.join(
          _automaticDirectory.path,
          'auto_${stamp}_${safeOperation}_$nonce.drbackup',
        ),
      );
      if (!await candidate.exists()) return candidate;
    }
  }

  Future<File> writeAutomatic(
    List<int> bytes,
    DateTime nowUtc,
    String operation,
    Future<void> Function(File file) validate,
  ) => _serialized(
    () => _withFileLock(() async {
      final file = await _allocateAutomatic(nowUtc, operation);
      await _writeAtomically(file, bytes, validate);
      await _pruneAutomatic();
      return file;
    }),
  );

  Future<List<SnapshotInfo>> listAutomatic() => _serialized(_listAutomatic);

  Future<List<SnapshotInfo>> _listAutomatic() async {
    if (!await _automaticDirectory.exists()) return const [];
    final root = p.canonicalize(_automaticDirectory.absolute.path);
    final result = <SnapshotInfo>[];
    await for (final entity in _automaticDirectory.list(followLinks: false)) {
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
    result.sort((a, b) {
      final byTime = b.createdAtUtc.compareTo(a.createdAtUtc);
      return byTime != 0
          ? byTime
          : p.basename(b.file.path).compareTo(p.basename(a.file.path));
    });
    return result;
  }

  Future<void> pruneAutomatic() =>
      _serialized(() => _withFileLock(_pruneAutomatic));

  Future<void> _pruneAutomatic() async {
    final snapshots = await _listAutomatic();
    for (final snapshot in snapshots.skip(maxAutomaticSnapshots)) {
      final root = p.canonicalize(_automaticDirectory.absolute.path);
      final target = p.canonicalize(snapshot.file.absolute.path);
      if (p.isWithin(root, target) && p.basename(target).startsWith('auto_')) {
        await snapshot.file.delete();
      }
    }
  }

  Future<void> _writeAtomically(
    File target,
    List<int> bytes,
    Future<void> Function(File file) validate,
  ) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await validate(temp);
      await temp.rename(target.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<T> _withFileLock<T>(Future<T> Function() action) async {
    await _automaticDirectory.create(recursive: true);
    final lock = await File(
      p.join(_automaticDirectory.path, '.snapshot.lock'),
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
        throw const FileSystemException('Timed out acquiring snapshot lock');
      }
      return await action();
    } finally {
      if (acquired) await lock.unlock();
      await lock.close();
    }
  }

  String _secureNonce() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
