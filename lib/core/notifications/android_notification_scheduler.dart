import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  }) : super(clock: timezoneClock);

  final TimezoneNotificationClock timezoneClock;

  static Future<AndroidNotificationScheduler> create({
    required AppDatabase database,
    NotificationTapCallback? onTap,
    NotificationPlanSettings settings = const NotificationPlanSettings(),
  }) async {
    final timezone = await _initializeTimezone();
    final gateway = AndroidNotificationGateway(onTap: onTap);
    await gateway.initialize();
    return AndroidNotificationScheduler(
      dataSource: DatabaseNotificationDataSource(database),
      idStore: StableNotificationIdStore(database),
      timezoneClock: TimezoneNotificationClock(timezone),
      gateway: gateway,
      settings: settings,
    );
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

final class AndroidNotificationGateway implements NotificationGateway {
  AndroidNotificationGateway({this.onTap});

  final NotificationTapCallback? onTap;
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  AndroidFlutterLocalNotificationsPlugin? get android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> initialize() async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
        ),
      ),
      androidScheduleMode: mode,
      payload: request.payload.toJson(),
    );
  }

  @override
  Future<void> cancel(int notificationId) => plugin.cancel(id: notificationId);
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
