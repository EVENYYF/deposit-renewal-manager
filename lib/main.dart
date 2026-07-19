import 'dart:io';

import 'package:deposit_renewal_manager/app/app.dart';
import 'package:deposit_renewal_manager/core/backup/backup_service.dart';
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/notifications/android_notification_scheduler.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationScheduler scheduler = const UnsupportedNotificationScheduler();
  final taps = NotificationTapDispatcher();
  final database = AppDatabase();
  final supportDirectory = await getApplicationSupportDirectory();
  final backupService = BackupService(
    database: database,
    sourceDevice: 'local-device',
    snapshotsDirectory: Directory(
      p.join(supportDirectory.path, 'automatic_snapshots'),
    ),
  );
  if (defaultTargetPlatform == TargetPlatform.android) {
    scheduler = RecoverableNotificationScheduler(
      create: () => AndroidNotificationScheduler.create(
        database: database,
        onTap: taps.dispatch,
      ),
      openSettingsFallback: AndroidNotificationGateway.openApplicationSettings,
    );
  }
  runApp(
    DepositRenewalApp(
      database: database,
      backupService: backupService,
      notificationScheduler: scheduler,
      notificationTapDispatcher: taps,
    ),
  );
}
