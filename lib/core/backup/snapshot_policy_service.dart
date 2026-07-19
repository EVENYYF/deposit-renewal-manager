import 'backup_service.dart';
import '../database/app_database.dart';

/// 设备本地快照策略。策略本身不参与业务备份。
final class SnapshotPolicyService {
  SnapshotPolicyService({
    required this.database,
    required this.backupService,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final BackupService backupService;
  final DateTime Function() _nowUtc;
  Future<void> _reconcileQueue = Future.value();

  Future<DeviceSetting> settings() => database.getDeviceSettings();

  Future<void> update({
    bool? enabled,
    int? intervalDays,
    int? retentionCount,
  }) => database.updateDeviceSettings(
    autoSnapshotEnabled: enabled,
    snapshotIntervalDays: intervalDays,
    snapshotRetentionCount: retentionCount,
  );

  Future<bool> isDue() async {
    final current = await settings();
    if (!current.autoSnapshotEnabled) return false;
    final revision = await database.businessRevision();
    if (revision == current.lastSnapshotBusinessRevision) return false;
    final last = current.lastSnapshotAtUtc;
    if (last == null) return true;
    final elapsed = _nowUtc().toUtc().difference(
      DateTime.fromMillisecondsSinceEpoch(last, isUtc: true),
    );
    return elapsed >= Duration(days: current.snapshotIntervalDays);
  }

  /// 在应用启动或恢复到前台时调用；仅在到期且业务修订号变化时创建。
  Future<void> reconcile() {
    final result = _reconcileQueue.then((_) => _reconcileOnce());
    _reconcileQueue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _reconcileOnce() async {
    if (!await isDue()) return;
    final current = await settings();
    final revision = await database.businessRevision();
    await backupService.createAutomaticSnapshotWithRetention(
      'scheduled',
      retentionCount: current.snapshotRetentionCount,
    );
    await database.markSnapshotCreated(
      createdAtUtc: _nowUtc(),
      businessRevision: revision,
    );
  }

  Future<void> createManualSnapshot() async {
    final current = await settings();
    final revision = await database.businessRevision();
    await backupService.createAutomaticSnapshotWithRetention(
      'manual',
      retentionCount: current.snapshotRetentionCount,
    );
    await database.markSnapshotCreated(
      createdAtUtc: _nowUtc(),
      businessRevision: revision,
    );
  }
}
