import 'package:deposit_renewal_manager/app/app.dart';
import 'package:deposit_renewal_manager/core/notifications/android_notification_scheduler.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'recoverable scheduler retries factory after initialization failure',
    () async {
      var createCalls = 0;
      final delegate = _PermissionScheduler()..allowed = true;
      final scheduler = RecoverableNotificationScheduler(
        create: () async {
          createCalls++;
          if (createCalls == 1) throw StateError('plugin unavailable');
          return delegate;
        },
      );

      final first = await scheduler.reconcileAll();
      expect(first.status, NotificationReconcileStatus.error);
      expect(first.degradedReason, contains('plugin unavailable'));

      final second = await scheduler.reconcileAll();
      expect(createCalls, 2);
      expect(second.scheduledCount, 1);
      expect(delegate.reconcileCalls, 1);
    },
  );

  test(
    'initialization actively requests missing permission only once',
    () async {
      final scheduler = _PermissionScheduler();
      final container = ProviderContainer(
        overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        notificationCapabilityControllerProvider.notifier,
      );

      await controller.initialize();
      await controller.initialize();

      expect(scheduler.permissionRequests, 1);
      expect(scheduler.reconcileCalls, 1);
    },
  );

  test('open settings failure is exposed to the capability state', () async {
    final scheduler = _PermissionScheduler()..settingsResult = false;
    final container = ProviderContainer(
      overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
    );
    addTearDown(container.dispose);

    await container
        .read(notificationCapabilityControllerProvider.notifier)
        .openSettings();

    expect(
      container.read(notificationCapabilityControllerProvider).message,
      '打开系统通知设置失败',
    );
  });

  test(
    'denied permission requires user action then grant reconciles all',
    () async {
      final scheduler = _PermissionScheduler();
      final container = ProviderContainer(
        overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        notificationCapabilityControllerProvider.notifier,
      );

      await controller.refresh();
      expect(
        container
            .read(notificationCapabilityControllerProvider)
            .needsNotificationPermission,
        isTrue,
      );
      expect(scheduler.permissionRequests, 0);

      await controller.requestNotificationPermission();
      expect(scheduler.permissionRequests, 1);
      expect(scheduler.reconcileCalls, 1);
      expect(
        container
            .read(notificationCapabilityControllerProvider)
            .capability
            ?.notificationsAllowed,
        isTrue,
      );
    },
  );

  test(
    'daily summary schedules one next local alarm and requests reboot restore',
    () async {
      DateTime? scheduledAt;
      bool? recordedExact;
      bool? recordedAllowWhileIdle;
      bool? recordedRescheduleOnReboot;
      final scheduler = AndroidDailySummaryScheduler(
        clock: _Clock(),
        capability: () async => const NotificationCapability(
          support: NotificationSupport.supported,
          notificationsAllowed: true,
          canScheduleExact: false,
        ),
        oneShotAt:
            (
              time,
              id,
              callback, {
              allowWhileIdle = false,
              exact = false,
              wakeup = false,
              rescheduleOnReboot = false,
            }) async {
              scheduledAt = time;
              recordedAllowWhileIdle = allowWhileIdle;
              recordedExact = exact;
              recordedRescheduleOnReboot = rescheduleOnReboot;
              return true;
            },
      );

      await scheduler.scheduleNext();

      expect(scheduledAt, DateTime(2026, 7, 21, 9));
      expect(recordedAllowWhileIdle, isTrue);
      expect(recordedExact, isFalse);
      expect(recordedRescheduleOnReboot, isTrue);
    },
  );

  test(
    'daily summary failure is recorded and still schedules next alarm',
    () async {
      var scheduleCalls = 0;
      final errors = <String>[];

      await runDailySummaryAlarmJob(
        bootstrapAndShow: () async => throw StateError('show failed'),
        scheduleNext: () async => scheduleCalls++,
        recordError: errors.add,
      );

      expect(scheduleCalls, 1);
      expect(errors.single, contains('show failed'));
    },
  );

  testWidgets('resuming the app reconciles timezone-sensitive schedules', (
    tester,
  ) async {
    final scheduler = _PermissionScheduler()..allowed = true;
    await tester.pumpWidget(
      DepositRenewalApp(notificationScheduler: scheduler),
    );
    await tester.pump();
    expect(scheduler.reconcileCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(scheduler.reconcileCalls, 2);
  });
}

final class _PermissionScheduler implements NotificationScheduler {
  bool allowed = false;
  Object? settingsError;
  bool settingsResult = true;
  int permissionRequests = 0;
  int reconcileCalls = 0;

  @override
  Future<NotificationCapability> get capability async => NotificationCapability(
    support: NotificationSupport.supported,
    notificationsAllowed: allowed,
    canScheduleExact: false,
    reason: allowed ? null : 'denied',
  );

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    allowed = true;
    return true;
  }

  @override
  Future<NotificationReconcileResult> reconcileAll() async {
    reconcileCalls++;
    return NotificationReconcileResult(
      capability: await capability,
      scheduledCount: 1,
      cancelledCount: 0,
      status: NotificationReconcileStatus.degraded,
      degradedReason: 'inexact',
    );
  }

  @override
  Future<NotificationReconcileResult> cancelDeposit(String depositId) =>
      reconcileAll();
  @override
  Future<bool> openSettings() async {
    if (settingsError case final error?) throw error;
    return settingsResult;
  }

  @override
  Future<NotificationReconcileResult> reconcileDeposit(String depositId) =>
      reconcileAll();
  @override
  Future<NotificationReconcileResult> reconcileSummary() => reconcileAll();
  @override
  Future<bool> requestExactAlarmPermission() async => false;
}

final class _Clock implements NotificationLocalClock {
  @override
  DateTime at(LocalDate date, int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);
  @override
  DateTime now() => DateTime(2026, 7, 20, 10);
  @override
  LocalDate today() => LocalDate(2026, 7, 20);
}
