import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/deposits/domain/local_date.dart';
import '../database/app_database.dart';
import 'notification_plan.dart';
import 'notification_scheduler.dart';

typedef NotificationTapCallback = void Function(NotificationPayload payload);

/// Android implementation. The reconciliation engine remains platform
/// independent, so permission and plugin behavior can be faked in Dart tests.
final class AndroidNotificationScheduler extends NotificationReconciler {
  AndroidNotificationScheduler({
    required super.dataSource,
    required super.idStore,
    required this.timezoneClock,
    required super.gateway,
    super.settings,
    super.dailySummaryScheduler,
    super.legacySummaryNotificationIds,
  }) : super(clock: timezoneClock);

  final TimezoneNotificationClock timezoneClock;

  static Future<AndroidNotificationScheduler> create({
    required AppDatabase database,
    NotificationTapCallback? onTap,
    NotificationPlanSettings settings = const NotificationPlanSettings(),
  }) async {
    await _initializeStage('Android 闹钟服务', AndroidAlarmManager.initialize);
    final timezone = await _initializeStage('时区数据', _initializeTimezone);
    final gateway = AndroidNotificationGateway(onTap: onTap);
    await _initializeStage('通知插件', gateway.initialize);
    final clock = TimezoneNotificationClock(timezone);
    return AndroidNotificationScheduler(
      dataSource: DatabaseNotificationDataSource(database),
      idStore: StableNotificationIdStore(database),
      timezoneClock: clock,
      gateway: gateway,
      settings: settings,
      dailySummaryScheduler: AndroidDailySummaryScheduler(
        clock: clock,
        capability: gateway.capability,
        settings: settings,
      ),
      legacySummaryNotificationIds: const [
        AndroidDailySummaryScheduler.notificationId,
      ],
    );
  }

  static Future<T> _initializeStage<T>(
    String stage,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (error) {
      throw NotificationInitializationException(stage, error);
    }
  }

  static Future<tz.Location> _initializeTimezone() async {
    tz_data.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    final location = tz.getLocation(info.identifier);
    tz.setLocalLocation(location);
    return location;
  }

  @override
  Future<NotificationReconcileResult> reconcileAll() async {
    await timezoneClock.refresh();
    return super.reconcileAll();
  }

  @override
  Future<NotificationReconcileResult> reconcileDeposit(String depositId) async {
    await timezoneClock.refresh();
    return super.reconcileDeposit(depositId);
  }
}

final class NotificationInitializationException implements Exception {
  const NotificationInitializationException(this.stage, this.cause);

  final String stage;
  final Object cause;

  @override
  String toString() => '$stage初始化失败：$cause';
}

final class AndroidNotificationGateway implements NotificationGateway {
  AndroidNotificationGateway({this.onTap});

  final NotificationTapCallback? onTap;
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  static const _settingsChannel = MethodChannel(
    'deposit_renewal_manager/settings',
  );
  AndroidFlutterLocalNotificationsPlugin? get android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> initialize() async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _handlePayload(response.payload),
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _handlePayload(launch?.notificationResponse?.payload);
    }
  }

  void _handlePayload(String? payload) {
    if (payload == null) return;
    try {
      onTap?.call(NotificationPayload.parse(payload));
    } on FormatException {
      // Ignore malformed external payloads; notification data is strict.
    }
  }

  @override
  Future<NotificationCapability> capability() async {
    final implementation = android;
    if (implementation == null) {
      return const NotificationCapability.unsupported(
        'Android plugin unavailable',
      );
    }
    final allowed = await implementation.areNotificationsEnabled() ?? true;
    final exact = await implementation.canScheduleExactNotifications() ?? false;
    return NotificationCapability(
      support: NotificationSupport.supported,
      notificationsAllowed: allowed,
      canScheduleExact: exact,
      reason: allowed ? null : 'Android notification permission denied',
    );
  }

  @override
  Future<bool> requestNotificationPermission() async =>
      await android?.requestNotificationsPermission() ?? false;

  @override
  Future<bool> requestExactAlarmPermission() async =>
      await android?.requestExactAlarmsPermission() ?? false;

  @override
  Future<void> openSettings() => openApplicationSettings();

  static Future<void> openApplicationSettings() =>
      _settingsChannel.invokeMethod<void>('openAppSettings');

  @override
  Future<void> schedule(ScheduledNotificationRequest request) {
    final mode =
        request.precision == NotificationSchedulePrecision.exactAllowWhileIdle
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    return plugin.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      scheduledDate: tz.TZDateTime.from(request.scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'deposit_reminders',
          'Deposit reminders',
          channelDescription: 'Deposit renewal reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
      androidScheduleMode: mode,
      payload: request.payload.toJson(),
    );
  }

  @override
  Future<void> cancel(int notificationId) => plugin.cancel(id: notificationId);

  Future<void> showSummary(String body) => plugin.show(
    id: AndroidDailySummaryScheduler.notificationId,
    title: '存款到期汇总',
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'deposit_reminders',
        'Deposit reminders',
        channelDescription: 'Deposit renewal reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
      ),
    ),
    payload: const NotificationPayload(customerId: '', depositId: '').toJson(),
  );
}

typedef AndroidAlarmOneShotAt =
    Future<bool> Function(
      DateTime time,
      int id,
      Function callback, {
      bool allowWhileIdle,
      bool exact,
      bool wakeup,
      bool rescheduleOnReboot,
    });

final class AndroidDailySummaryScheduler implements DailySummaryScheduler {
  AndroidDailySummaryScheduler({
    required this.clock,
    required this.capability,
    this.settings = const NotificationPlanSettings(),
    AndroidAlarmOneShotAt? oneShotAt,
  }) : _oneShotAt = oneShotAt ?? AndroidAlarmManager.oneShotAt;

  static const alarmId = 0x5da11;
  static const notificationId = 0x5da12;

  final NotificationLocalClock clock;
  final Future<NotificationCapability> Function() capability;
  final NotificationPlanSettings settings;
  final AndroidAlarmOneShotAt _oneShotAt;

  @override
  Future<void> scheduleNext() async {
    final now = clock.now();
    var date = clock.today();
    var target = clock.at(date, settings.summaryHour, settings.summaryMinute);
    if (!target.isAfter(now)) {
      date = date.addDays(1);
      target = clock.at(date, settings.summaryHour, settings.summaryMinute);
    }
    final currentCapability = await capability();
    final accepted = await _oneShotAt(
      target,
      alarmId,
      dailySummaryAlarmCallback,
      allowWhileIdle: true,
      exact: currentCapability.canScheduleExact,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    if (!accepted) throw StateError('Android rejected daily summary alarm');
  }
}

@pragma('vm:entry-point')
Future<void> dailySummaryAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await runDailySummaryAlarmJob(
    bootstrapAndShow: _bootstrapAndShowDailySummary,
    scheduleNext: _scheduleNextDailySummary,
    recordError: debugPrint,
  );
}

Future<void> runDailySummaryAlarmJob({
  required Future<void> Function() bootstrapAndShow,
  required Future<void> Function() scheduleNext,
  required void Function(String message) recordError,
}) async {
  try {
    await bootstrapAndShow();
  } catch (error, stack) {
    recordError('每日汇总后台执行失败：$error\n$stack');
  } finally {
    try {
      await scheduleNext();
    } catch (error, stack) {
      recordError('每日汇总续排失败：$error\n$stack');
    }
  }
}

Future<void> _bootstrapAndShowDailySummary() async {
  final database = AppDatabase();
  try {
    final timezone = await AndroidNotificationScheduler._initializeTimezone();
    final clock = TimezoneNotificationClock(timezone);
    final gateway = AndroidNotificationGateway();
    await gateway.initialize();
    final deposits = await DatabaseNotificationDataSource(
      database,
    ).activeDeposits();
    final plan = NotificationPlan.build(
      deposits: deposits,
      today: clock.today(),
      settings: const NotificationPlanSettings(summaryHorizonDays: 1),
    );
    final counts = plan.summaries.first.counts;
    await gateway.showSummary(
      '今日 ${counts.today}，未来三天 ${counts.nextThreeDays}，'
      '本周 ${counts.thisWeek}，逾期 ${counts.overdue}',
    );
  } finally {
    await database.close();
  }
}

Future<void> _scheduleNextDailySummary() async {
  await AndroidAlarmManager.initialize();
  final timezone = await AndroidNotificationScheduler._initializeTimezone();
  final clock = TimezoneNotificationClock(timezone);
  final gateway = AndroidNotificationGateway();
  await gateway.initialize();
  await AndroidDailySummaryScheduler(
    clock: clock,
    capability: gateway.capability,
  ).scheduleNext();
}

final class TimezoneNotificationClock implements NotificationLocalClock {
  TimezoneNotificationClock(this.location);

  tz.Location location;

  Future<void> refresh() async {
    final info = await FlutterTimezone.getLocalTimezone();
    final current = tz.getLocation(info.identifier);
    location = current;
    tz.setLocalLocation(current);
  }

  @override
  DateTime now() => tz.TZDateTime.now(location);

  @override
  LocalDate today() {
    final value = now();
    return LocalDate(value.year, value.month, value.day);
  }

  @override
  DateTime at(LocalDate date, int hour, int minute) =>
      tz.TZDateTime(location, date.year, date.month, date.day, hour, minute);
}
