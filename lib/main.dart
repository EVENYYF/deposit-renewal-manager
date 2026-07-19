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
  String? notificationInitializationError;
  final database = AppDatabase();
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      scheduler = await AndroidNotificationScheduler.create(
        database: database,
        onTap: taps.dispatch,
      );
    } catch (error, stack) {
      notificationInitializationError = 'Android 通知初始化失败：$error';
      debugPrint('$notificationInitializationError\n$stack');
      scheduler = const UnsupportedNotificationScheduler(
        'Android notification initialization failed',
      );
    }
  }
  runApp(
    DepositRenewalApp(
      database: database,
      notificationScheduler: scheduler,
      notificationTapDispatcher: taps,
      notificationInitializationError: notificationInitializationError,
    ),
  );
}
