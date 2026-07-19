import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/deposits/domain/deposit.dart' as domain;
import '../../features/deposits/domain/deposit_repository.dart';
import '../../features/deposits/domain/local_date.dart';
import '../database/app_database.dart';
import 'notification_plan.dart';

enum NotificationSupport { supported, unsupported }

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
    this.degradedReason,
  });

  final NotificationCapability capability;
  final int scheduledCount;
  final int cancelledCount;
  final String? degradedReason;

  bool get degraded => degradedReason != null;
}

abstract interface class NotificationScheduler {
  Future<NotificationCapability> get capability;

  Future<NotificationReconcileResult> reconcileAll();

  Future<NotificationReconcileResult> reconcileDeposit(String depositId);

  Future<NotificationReconcileResult> cancelDeposit(String depositId);
}

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const UnsupportedNotificationScheduler(),
);

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

  Future<NotificationReconcileResult> _result() async =>
      NotificationReconcileResult(
        capability: NotificationCapability.unsupported(reason),
        scheduledCount: 0,
        cancelledCount: 0,
        degradedReason: reason,
      );
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
    final mappings = await database
        .select(database.notificationIdMappings)
        .get();
    return mappings
        .where((mapping) => mapping.entityId.startsWith(prefix))
        .toList(growable: false);
  }

  static int _sha256Candidate(String entityId, int attempt) {
    final digest = sha256.convert(utf8.encode('$entityId\u0000$attempt'));
    return ByteData.sublistView(Uint8List.fromList(digest.bytes)).getUint32(0);
  }
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
  });

  final NotificationDataSource dataSource;
  final NotificationGateway gateway;
  final StableNotificationIdStore idStore;
  final NotificationLocalClock clock;
  final NotificationPlanSettings settings;

  @override
  Future<NotificationCapability> get capability => gateway.capability();

  @override
  Future<NotificationReconcileResult> reconcileAll() async {
    final cap = await capability;
    if (!cap.isSupported || !cap.notificationsAllowed) {
      return _degraded(cap, cap.reason ?? 'Notifications are not allowed');
    }
    final mappings = await idStore.mappingsWithPrefix('deposit:');
    final summaryMappings = await idStore.mappingsWithPrefix('summary:');
    var cancelled = 0;
    for (final mapping in [...mappings, ...summaryMappings]) {
      await gateway.cancel(mapping.notificationId);
      cancelled++;
    }
    final plan = NotificationPlan.build(
      deposits: await dataSource.activeDeposits(),
      today: clock.today(),
      settings: settings,
    );
    final scheduled = await _schedulePlan(plan, cap);
    return NotificationReconcileResult(
      capability: cap,
      scheduledCount: scheduled,
      cancelledCount: cancelled,
      degradedReason: cap.canScheduleExact
          ? null
          : 'Exact alarm permission unavailable; using inexact scheduling',
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
    }
    return NotificationReconcileResult(
      capability: cap,
      scheduledCount: 0,
      cancelledCount: mappings.length,
    );
  }

  Future<int> _schedulePlan(
    NotificationPlan plan,
    NotificationCapability cap,
  ) async {
    final precision = cap.canScheduleExact
        ? NotificationSchedulePrecision.exactAllowWhileIdle
        : NotificationSchedulePrecision.inexactAllowWhileIdle;
    var count = 0;
    final now = clock.now();
    for (final reminder in plan.depositReminders) {
      final scheduledAt = clock.at(
        reminder.date,
        settings.reminderHour,
        settings.reminderMinute,
      );
      if (!scheduledAt.isAfter(now)) continue;
      final id = await idStore.idFor(
        'deposit:${reminder.depositId}:${reminder.offset.inDays}',
      );
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
    }
    for (final summary in plan.summaries) {
      final scheduledAt = clock.at(
        summary.date,
        settings.summaryHour,
        settings.summaryMinute,
      );
      if (!scheduledAt.isAfter(now)) continue;
      final id = await idStore.idFor('summary:${summary.date}');
      final c = summary.counts;
      await gateway.schedule(
        ScheduledNotificationRequest(
          id: id,
          scheduledAt: scheduledAt,
          title: '存款到期汇总',
          body:
              '今日 ${c.today}，未来三天 ${c.nextThreeDays}，本周 ${c.thisWeek}，逾期 ${c.overdue}',
          payload: const NotificationPayload(customerId: '', depositId: ''),
          precision: precision,
        ),
      );
      count++;
    }
    return count;
  }

  NotificationReconcileResult _degraded(
    NotificationCapability cap,
    String reason,
  ) => NotificationReconcileResult(
    capability: cap,
    scheduledCount: 0,
    cancelledCount: 0,
    degradedReason: reason,
  );
}
