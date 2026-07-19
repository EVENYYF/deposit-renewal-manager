import 'package:deposit_renewal_manager/app/app.dart';
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/notifications/android_notification_scheduler.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationScheduler scheduler = const UnsupportedNotificationScheduler();
  final taps = NotificationTapDispatcher();
  AppDatabase? database;
  if (defaultTargetPlatform == TargetPlatform.android) {
    database = AppDatabase();
    try {
      scheduler = await AndroidNotificationScheduler.create(
        database: database,
        onTap: taps.dispatch,
      );
    } catch (_) {
      scheduler = const UnsupportedNotificationScheduler(
        'Android notification initialization failed',
      );
    }
  }
  runApp(
    DepositRenewalApp(
      notificationScheduler: scheduler,
      notificationTapDispatcher: taps,
    ),
  );
}
