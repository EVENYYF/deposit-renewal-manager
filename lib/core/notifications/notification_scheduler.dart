import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/deposits/domain/deposit.dart' as domain;
import '../../features/deposits/domain/deposit_repository.dart';
import '../../features/deposits/domain/local_date.dart';
import '../database/app_database.dart';
import 'notification_plan.dart';

enum NotificationSupport { supported, unsupported }

enum NotificationReconcileStatus { success, degraded, partial, error }

final class NotificationCapability {
  const NotificationCapability({
    required this.support,
    required this.notificationsAllowed,
    required this.canScheduleExact,
    this.reason,
  });

  const NotificationCapability.unsupported([this.reason])
    : support = NotificationSupport.unsupported,
      notificationsAllowed = false,
      canScheduleExact = false;

  final NotificationSupport support;
  final bool notificationsAllowed;
  final bool canScheduleExact;
  final String? reason;

  bool get isSupported => support == NotificationSupport.supported;
  bool get isDegraded =>
      isSupported && (!notificationsAllowed || !canScheduleExact);
}

enum NotificationSchedulePrecision {
  exactAllowWhileIdle,
  inexactAllowWhileIdle,
}

final class NotificationPayload {
  const NotificationPayload({
    required this.customerId,
    required this.depositId,
  });

  final String customerId;
  final String depositId;

  String toJson() =>
      jsonEncode({'customerId': customerId, 'depositId': depositId});

  static NotificationPayload parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 2 ||
        decoded['customerId'] is! String ||
        decoded['depositId'] is! String ||
        !decoded.containsKey('customerId') ||
        !decoded.containsKey('depositId')) {
      throw const FormatException('Invalid notification payload');
    }
    return NotificationPayload(
      customerId: decoded['customerId'] as String,
      depositId: decoded['depositId'] as String,
    );
  }
}

/// Retains a cold-start tap until the app router is ready to consume it.
final class NotificationTapDispatcher extends ChangeNotifier {
  NotificationPayload? _pending;

  void dispatch(NotificationPayload payload) {
    _pending = payload;
    notifyListeners();
  }

  NotificationPayload? take() {
    final value = _pending;
    _pending = null;
    return value;
  }
}

final class ScheduledNotificationRequest {
  const ScheduledNotificationRequest({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
    required this.precision,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final NotificationPayload payload;
  final NotificationSchedulePrecision precision;
}

abstract interface class NotificationGateway {
  Future<NotificationCapability> capability();

  Future<bool> requestNotificationPermission();

  Future<bool> requestExactAlarmPermission();

  Future<bool> openSettings();

  Future<void> schedule(ScheduledNotificationRequest request);

  Future<void> cancel(int notificationId);
}

abstract interface class NotificationDataSource {
  Future<List<StoredDeposit>> activeDeposits();

  Future<StoredDeposit?> deposit(String depositId);
}

abstract interface class NotificationLocalClock {
  DateTime now();

  LocalDate today();

  DateTime at(LocalDate date, int hour, int minute);
}

final class NotificationReconcileResult {
  const NotificationReconcileResult({
    required this.capability,
    required this.scheduledCount,
    required this.cancelledCount,
    this.status = NotificationReconcileStatus.success,
    this.truncatedCount = 0,
    this.degradedReason,
  });

  final NotificationCapability capability;
  final int scheduledCount;
  final int cancelledCount;
  final NotificationReconcileStatus status;
  final int truncatedCount;
  final String? degradedReason;

  bool get degraded => status != NotificationReconcileStatus.success;
}

abstract interface class NotificationScheduler {
  Future<NotificationCapability> get capability;

  Future<NotificationReconcileResult> reconcileAll();

  Future<NotificationReconcileResult> reconcileDeposit(String depositId);

  Future<NotificationReconcileResult> cancelDeposit(String depositId);

  Future<NotificationReconcileResult> reconcileSummary();

  Future<bool> requestNotificationPermission();

  Future<bool> requestExactAlarmPermission();

  Future<bool> openSettings();
}

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const UnsupportedNotificationScheduler(),
);

/// Keeps notification features recoverable when platform initialization fails.
/// A failed attempt is not terminal: the next capability/reconcile call retries
/// the factory and swaps in the working scheduler.
final class RecoverableNotificationScheduler implements NotificationScheduler {
  RecoverableNotificationScheduler({
    required this.create,
    this.openSettingsFallback,
  });

  final Future<NotificationScheduler> Function() create;
  final Future<bool> Function()? openSettingsFallback;
  NotificationScheduler? _delegate;
  Future<NotificationScheduler>? _creating;
  Object? _lastError;

  String get errorMessage => _lastError?.toString() ?? '通知初始化失败';

  Future<NotificationScheduler> _ready() async {
    final existing = _delegate;
    if (existing != null) return existing;
    final inFlight = _creating;
    if (inFlight != null) return inFlight;
    final attempt = create();
    _creating = attempt;
    try {
      final created = await attempt;
      _delegate = created;
      _lastError = null;
      return created;
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _creating = null;
    }
  }

  @override
  Future<NotificationCapability> get capability async {
    try {
      return await (await _ready()).capability;
    } catch (error) {
      return NotificationCapability.unsupported('Android 通知初始化失败：$error');
    }
  }

  Future<NotificationReconcileResult> _run(
    Future<NotificationReconcileResult> Function(NotificationScheduler) action,
  ) async {
    try {
      return await action(await _ready());
    } catch (error) {
      _lastError = error;
      final cap = NotificationCapability.unsupported('Android 通知初始化失败：$error');
      return NotificationReconcileResult(
        capability: cap,
        scheduledCount: 0,
        cancelledCount: 0,
        status: NotificationReconcileStatus.error,
        degradedReason: cap.reason,
      );
    }
  }

  @override
  Future<NotificationReconcileResult> reconcileAll() =>
      _run((scheduler) => scheduler.reconcileAll());

  @override
  Future<NotificationReconcileResult> reconcileDeposit(String depositId) =>
      _run((scheduler) => scheduler.reconcileDeposit(depositId));

  @override
  Future<NotificationReconcileResult> cancelDeposit(String depositId) =>
      _run((scheduler) => scheduler.cancelDeposit(depositId));

  @override
  Future<NotificationReconcileResult> reconcileSummary() =>
      _run((scheduler) => scheduler.reconcileSummary());

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      return await (await _ready()).requestNotificationPermission();
    } catch (error) {
      _lastError = error;
      return false;
    }
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    try {
      return await (await _ready()).requestExactAlarmPermission();
    } catch (error) {
      _lastError = error;
      return false;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      if (openSettingsFallback != null) {
        return await openSettingsFallback!();
      }
      return await (await _ready()).openSettings();
    } catch (error) {
      _lastError = error;
      rethrow;
    }
  }
}

final class UnsupportedNotificationScheduler implements NotificationScheduler {
  const UnsupportedNotificationScheduler([
    this.reason = 'Platform notifications are unsupported',
  ]);

  final String reason;

  @override
  Future<NotificationCapability> get capability async =>
      NotificationCapability.unsupported(reason);

  @override
  Future<NotificationReconcileResult> cancelDeposit(String depositId) =>
      _result();

  @override
  Future<NotificationReconcileResult> reconcileAll() => _result();

  @override
  Future<NotificationReconcileResult> reconcileDeposit(String depositId) =>
      _result();

  @override
  Future<NotificationReconcileResult> reconcileSummary() => _result();

  @override
  Future<bool> requestExactAlarmPermission() async => false;

  @override
  Future<bool> requestNotificationPermission() async => false;

  @override
  Future<bool> openSettings() async => false;

  Future<NotificationReconcileResult> _result() async =>
      NotificationReconcileResult(
        capability: NotificationCapability.unsupported(reason),
        scheduledCount: 0,
        cancelledCount: 0,
        status: NotificationReconcileStatus.degraded,
        degradedReason: reason,
      );
}

final class NotificationCapabilityState {
  const NotificationCapabilityState({
    this.capability,
    this.lastResult,
    this.message,
    this.busy = false,
  });

  final NotificationCapability? capability;
  final NotificationReconcileResult? lastResult;
  final String? message;
  final bool busy;

  bool get needsNotificationPermission =>
      capability?.isSupported == true &&
      capability?.notificationsAllowed == false;

  NotificationCapabilityState copyWith({
    NotificationCapability? capability,
    NotificationReconcileResult? lastResult,
    String? message,
    bool? busy,
  }) => NotificationCapabilityState(
    capability: capability ?? this.capability,
    lastResult: lastResult ?? this.lastResult,
    message: message,
    busy: busy ?? this.busy,
  );
}

final notificationCapabilityControllerProvider =
    NotifierProvider<
      NotificationCapabilityController,
      NotificationCapabilityState
    >(NotificationCapabilityController.new);

final class NotificationCapabilityController
    extends Notifier<NotificationCapabilityState> {
  NotificationScheduler get _scheduler =>
      ref.read(notificationSchedulerProvider);

  @override
  NotificationCapabilityState build() => const NotificationCapabilityState();

  bool _initialized = false;

  /// Performs the first capability check and requests Android 13+ permission
  /// when the platform reports it is missing.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
    if (state.needsNotificationPermission) {
      await requestNotificationPermission();
    } else {
      await reconcileAll();
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, message: state.message);
    try {
      final capability = await _scheduler.capability;
      state = state.copyWith(
        capability: capability,
        busy: false,
        message: capability.reason,
      );
    } catch (error) {
      state = state.copyWith(busy: false, message: '通知状态读取失败：$error');
    }
  }

  Future<void> reconcileAll() => _record(_scheduler.reconcileAll);

  Future<void> requestNotificationPermission() async {
    state = state.copyWith(busy: true, message: state.message);
    try {
      await _scheduler.requestNotificationPermission();
      await _record(_scheduler.reconcileAll);
    } catch (error) {
      state = state.copyWith(busy: false, message: '通知授权失败：$error');
    }
  }

  Future<void> requestExactAlarmPermission() async {
    state = state.copyWith(busy: true, message: state.message);
    try {
      await _scheduler.requestExactAlarmPermission();
      await _record(_scheduler.reconcileAll);
    } catch (error) {
      state = state.copyWith(busy: false, message: '精确提醒授权失败：$error');
    }
  }

  Future<bool> openSettings() async {
    try {
      final opened = await _scheduler.openSettings();
      if (!opened) {
        state = state.copyWith(message: '打开系统通知设置失败');
      }
      return opened;
    } catch (error) {
      state = state.copyWith(message: '打开系统通知设置失败：$error');
      return false;
    }
  }

  void warning(String message) => state = state.copyWith(message: message);

  Future<void> _record(
    Future<NotificationReconcileResult> Function() operation,
  ) async {
    state = state.copyWith(busy: true, message: state.message);
    try {
      final result = await operation();
      state = state.copyWith(
        capability: result.capability,
        lastResult: result,
        busy: false,
        message: result.degradedReason,
      );
    } catch (error) {
      state = state.copyWith(busy: false, message: '通知重排失败：$error');
    }
  }
}

typedef NotificationIdCandidate = int Function(String entityId, int attempt);

final class StableNotificationIdStore {
  StableNotificationIdStore(
    this.database, {
    NotificationIdCandidate? candidate,
    DateTime Function()? nowUtc,
  }) : _candidate = candidate ?? _sha256Candidate,
       _nowUtc = nowUtc ?? DateTime.now;

  final AppDatabase database;
  final NotificationIdCandidate _candidate;
  final DateTime Function() _nowUtc;

  Future<int> idFor(String entityId) => database.transaction(() async {
    final existing = await (database.select(
      database.notificationIdMappings,
    )..where((row) => row.entityId.equals(entityId))).getSingleOrNull();
    if (existing != null) return existing.notificationId;

    for (var attempt = 0; attempt < 1024; attempt++) {
      final candidate = _candidate(entityId, attempt) & 0x7fffffff;
      if (candidate == 0) continue;
      final collision =
          await (database.select(database.notificationIdMappings)
                ..where((row) => row.notificationId.equals(candidate)))
              .getSingleOrNull();
      if (collision != null) continue;
      await database
          .into(database.notificationIdMappings)
          .insert(
            NotificationIdMappingsCompanion.insert(
              entityId: entityId,
              notificationId: candidate,
              createdAtUtc: _nowUtc().toUtc().microsecondsSinceEpoch,
            ),
          );
      return candidate;
    }
    throw StateError('Unable to allocate a unique notification ID');
  });

  Future<List<NotificationIdMapping>> mappingsWithPrefix(String prefix) async {
    final escaped = prefix
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return (database.select(database.notificationIdMappings)..where(
          (mapping) => mapping.entityId.like('$escaped%', escapeChar: r'\'),
        ))
        .get();
  }

  Future<void> remove(String entityId) async {
    await (database.delete(
      database.notificationIdMappings,
    )..where((mapping) => mapping.entityId.equals(entityId))).go();
  }

  static int _sha256Candidate(String entityId, int attempt) {
    final digest = sha256.convert(utf8.encode('$entityId\u0000$attempt'));
    return ByteData.sublistView(Uint8List.fromList(digest.bytes)).getUint32(0);
  }
}

abstract interface class DailySummaryScheduler {
  Future<void> scheduleNext();
}

final class NoopDailySummaryScheduler implements DailySummaryScheduler {
  const NoopDailySummaryScheduler();

  @override
  Future<void> scheduleNext() async {}
}

final class DatabaseNotificationDataSource implements NotificationDataSource {
  const DatabaseNotificationDataSource(this.database);

  final AppDatabase database;

  @override
  Future<List<StoredDeposit>> activeDeposits() async {
    final rows = await (database.select(
      database.deposits,
    )..where((row) => row.lifecycle.equals('active'))).get();
    return rows.map(_stored).toList(growable: false);
  }

  @override
  Future<StoredDeposit?> deposit(String depositId) async {
    final row = await (database.select(
      database.deposits,
    )..where((item) => item.id.equals(depositId))).getSingleOrNull();
    return row == null ? null : _stored(row);
  }

  StoredDeposit _stored(Deposit row) {
    final expiry = _date(row.finalExpiryDate);
    final calculated = row.calculatedExpiryDate == null
        ? null
        : _date(row.calculatedExpiryDate!);
    final lifecycle = domain.DepositLifecycle.values.byName(row.lifecycle);
    final entity = calculated == null
        ? domain.Deposit.direct(
            id: row.id,
            expiryDate: expiry,
            lifecycle: lifecycle,
          )
        : domain.Deposit.automatic(
            id: row.id,
            calculatedExpiryDate: calculated,
            finalExpiryDate: expiry,
            lifecycle: lifecycle,
          );
    return StoredDeposit(
      deposit: entity,
      customerId: row.customerId,
      amountCents: row.amountCents,
      bankName: row.bankName,
      interestRateScaled: row.interestRateScaled,
      ratePrecision: row.ratePrecision,
      startDate: _date(row.startDate),
    );
  }

  LocalDate _date(String value) {
    final parts = value.split('-');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

/// Shared reconciliation engine used by Android and deterministic fakes.
class NotificationReconciler implements NotificationScheduler {
  NotificationReconciler({
    required this.dataSource,
    required this.gateway,
    required this.idStore,
    required this.clock,
    this.settings = const NotificationPlanSettings(),
    this.dailySummaryScheduler = const NoopDailySummaryScheduler(),
    this.maxScheduledDepositAlarms = 400,
    this.legacySummaryNotificationIds = const [],
  });

  final NotificationDataSource dataSource;
  final NotificationGateway gateway;
  final StableNotificationIdStore idStore;
  final NotificationLocalClock clock;
  final NotificationPlanSettings settings;
  final DailySummaryScheduler dailySummaryScheduler;
  final int maxScheduledDepositAlarms;
  final List<int> legacySummaryNotificationIds;

  @override
  Future<NotificationCapability> get capability => gateway.capability();

  @override
  Future<NotificationReconcileResult> reconcileAll() async {
    final cap = await capability;
    if (!cap.isSupported || !cap.notificationsAllowed) {
      return _degraded(cap, cap.reason ?? 'Notifications are not allowed');
    }
    final plan = NotificationPlan.build(
      deposits: await dataSource.activeDeposits(),
      today: clock.today(),
      settings: settings,
    );
    final outcome = await _schedulePlan(plan, cap);
    if (outcome.error != null) {
      return NotificationReconcileResult(
        capability: cap,
        scheduledCount: outcome.scheduled,
        cancelledCount: 0,
        status: outcome.scheduled == 0
            ? NotificationReconcileStatus.error
            : NotificationReconcileStatus.partial,
        truncatedCount: outcome.truncated,
        degradedReason: '部分提醒重排失败，已保留旧计划：${outcome.error}',
      );
    }

    var cancelled = 0;
    final mappings = await idStore.mappingsWithPrefix('deposit:');
    for (final mapping in mappings) {
      if (outcome.desiredKeys.contains(mapping.entityId)) continue;
      await gateway.cancel(mapping.notificationId);
      await idStore.remove(mapping.entityId);
      cancelled++;
    }
    final legacySummaryMappings = await idStore.mappingsWithPrefix('summary:');
    final cancelledIds = <int>{};
    for (final mapping in legacySummaryMappings) {
      await gateway.cancel(mapping.notificationId);
      cancelledIds.add(mapping.notificationId);
      await idStore.remove(mapping.entityId);
      cancelled++;
    }
    for (final notificationId in legacySummaryNotificationIds) {
      if (!cancelledIds.add(notificationId)) continue;
      await gateway.cancel(notificationId);
      cancelled++;
    }
    await dailySummaryScheduler.scheduleNext();
    return NotificationReconcileResult(
      capability: cap,
      scheduledCount: outcome.scheduled,
      cancelledCount: cancelled,
      status: cap.canScheduleExact && outcome.truncated == 0
          ? NotificationReconcileStatus.success
          : NotificationReconcileStatus.degraded,
      truncatedCount: outcome.truncated,
      degradedReason: outcome.truncated > 0
          ? '提醒数量超过系统安全上限，已省略 ${outcome.truncated} 条较远提醒'
          : cap.canScheduleExact
          ? null
          : '未授权精确提醒，当前使用非精确调度',
    );
  }

  @override
  Future<NotificationReconcileResult> reconcileDeposit(String depositId) async {
    // Reconcile all also refreshes summary text, which must reflect edits.
    return reconcileAll();
  }

  @override
  Future<NotificationReconcileResult> cancelDeposit(String depositId) async {
    final cap = await capability;
    final mappings = await idStore.mappingsWithPrefix('deposit:$depositId:');
    for (final mapping in mappings) {
      await gateway.cancel(mapping.notificationId);
      await idStore.remove(mapping.entityId);
    }
    return NotificationReconcileResult(
      capability: cap,
      scheduledCount: 0,
      cancelledCount: mappings.length,
    );
  }

  @override
  Future<NotificationReconcileResult> reconcileSummary() async {
    final cap = await capability;
    try {
      await dailySummaryScheduler.scheduleNext();
      return NotificationReconcileResult(
        capability: cap,
        scheduledCount: 0,
        cancelledCount: 0,
        status: cap.notificationsAllowed
            ? NotificationReconcileStatus.success
            : NotificationReconcileStatus.degraded,
        degradedReason: cap.notificationsAllowed ? null : cap.reason,
      );
    } catch (error) {
      return NotificationReconcileResult(
        capability: cap,
        scheduledCount: 0,
        cancelledCount: 0,
        status: NotificationReconcileStatus.error,
        degradedReason: '每日汇总重排失败：$error',
      );
    }
  }

  @override
  Future<bool> requestNotificationPermission() =>
      gateway.requestNotificationPermission();

  @override
  Future<bool> requestExactAlarmPermission() =>
      gateway.requestExactAlarmPermission();

  @override
  Future<bool> openSettings() => gateway.openSettings();

  Future<_ScheduleOutcome> _schedulePlan(
    NotificationPlan plan,
    NotificationCapability cap,
  ) async {
    final precision = cap.canScheduleExact
        ? NotificationSchedulePrecision.exactAllowWhileIdle
        : NotificationSchedulePrecision.inexactAllowWhileIdle;
    final now = clock.now();
    final reminders = plan.depositReminders.where((reminder) {
      return clock
          .at(reminder.date, settings.reminderHour, settings.reminderMinute)
          .isAfter(now);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
    final selected = reminders.take(maxScheduledDepositAlarms).toList();
    final desired = <String>{};
    var count = 0;
    Object? error;
    for (final reminder in selected) {
      final scheduledAt = clock.at(
        reminder.date,
        settings.reminderHour,
        settings.reminderMinute,
      );
      final key = 'deposit:${reminder.depositId}:${reminder.offset.inDays}';
      desired.add(key);
      try {
        final id = await idStore.idFor(key);
        await gateway.schedule(
          ScheduledNotificationRequest(
            id: id,
            scheduledAt: scheduledAt,
            title: '存款到期提醒',
            body: '存款将在 ${reminder.offset.inDays} 天后到期',
            payload: NotificationPayload(
              customerId: reminder.customerId,
              depositId: reminder.depositId,
            ),
            precision: precision,
          ),
        );
        count++;
      } catch (caught) {
        error = caught;
        break;
      }
    }
    return _ScheduleOutcome(
      scheduled: count,
      truncated: reminders.length - selected.length,
      desiredKeys: desired,
      error: error,
    );
  }

  NotificationReconcileResult _degraded(
    NotificationCapability cap,
    String reason,
  ) => NotificationReconcileResult(
    capability: cap,
    scheduledCount: 0,
    cancelledCount: 0,
    status: NotificationReconcileStatus.degraded,
    degradedReason: reason,
  );
}

final class _ScheduleOutcome {
  const _ScheduleOutcome({
    required this.scheduled,
    required this.truncated,
    required this.desiredKeys,
    this.error,
  });

  final int scheduled;
  final int truncated;
  final Set<String> desiredKeys;
  final Object? error;
}

abstract interface class NotificationMutationCoordinator {
  /// Invoke after a successful create or update transaction.
  Future<void> afterCreateOrUpdate(String depositId);

  /// Invoke after a successful renewal transaction for both affected deposits.
  Future<void> afterRenew(String sourceDepositId, String targetDepositId);

  /// Invoke after a successful stop or delete transaction.
  Future<void> afterStopOrDelete(String depositId);

  Future<void> reconcileDeposit(String depositId);
  Future<void> cancelDeposit(String depositId);
  Future<void> reconcileSummary();
  Future<void> reconcileAll();
}

final notificationMutationCoordinatorProvider =
    Provider<NotificationMutationCoordinator>(
      (ref) => SchedulerNotificationMutationCoordinator(
        scheduler: ref.read(notificationSchedulerProvider),
        onWarning: (message) => ref
            .read(notificationCapabilityControllerProvider.notifier)
            .warning(message),
      ),
    );

final class SchedulerNotificationMutationCoordinator
    implements NotificationMutationCoordinator {
  const SchedulerNotificationMutationCoordinator({
    required this.scheduler,
    required this.onWarning,
  });

  final NotificationScheduler scheduler;
  final void Function(String message) onWarning;

  @override
  Future<void> afterCreateOrUpdate(String depositId) =>
      reconcileDeposit(depositId);

  @override
  Future<void> afterRenew(
    String sourceDepositId,
    String targetDepositId,
  ) async {
    await _run(() => scheduler.cancelDeposit(sourceDepositId));
    await _run(() => scheduler.reconcileDeposit(targetDepositId));
  }

  @override
  Future<void> afterStopOrDelete(String depositId) => cancelDeposit(depositId);

  @override
  Future<void> reconcileDeposit(String depositId) =>
      _run(() => scheduler.reconcileDeposit(depositId));

  @override
  Future<void> cancelDeposit(String depositId) =>
      _run(() => scheduler.cancelDeposit(depositId));

  @override
  Future<void> reconcileSummary() => _run(scheduler.reconcileSummary);

  @override
  Future<void> reconcileAll() => _run(scheduler.reconcileAll);

  Future<void> _run(
    Future<NotificationReconcileResult> Function() action,
  ) async {
    try {
      final result = await action();
      if (result.status == NotificationReconcileStatus.partial ||
          result.status == NotificationReconcileStatus.error) {
        onWarning(result.degradedReason ?? '通知更新失败');
      }
    } catch (error) {
      onWarning('业务已保存，但通知更新失败：$error');
    }
  }
}
