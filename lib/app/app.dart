import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/backup/backup_service.dart';
import '../core/notifications/notification_scheduler.dart';
import 'app_dependencies.dart';
import 'router.dart';
import 'theme.dart';

class DepositRenewalApp extends StatefulWidget {
  const DepositRenewalApp({
    this.themeMode = ThemeMode.light,
    this.database,
    this.backupService,
    this.notificationScheduler,
    this.notificationTapDispatcher,
    this.notificationInitializationError,
    super.key,
  });

  final ThemeMode themeMode;
  final AppDatabase? database;
  final BackupService? backupService;
  final NotificationScheduler? notificationScheduler;
  final NotificationTapDispatcher? notificationTapDispatcher;
  final String? notificationInitializationError;

  @override
  State<DepositRenewalApp> createState() => _DepositRenewalAppState();
}

final class _DepositRenewalAppState extends State<DepositRenewalApp> {
  @override
  void dispose() {
    unawaited(widget.database?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _NotificationLifecycle(
      tapDispatcher: widget.notificationTapDispatcher,
      initializationError: widget.notificationInitializationError,
      child: _DepositRenewalMaterialApp(themeMode: widget.themeMode),
    );
    if (widget.database != null) {
      final backupService =
          widget.backupService ??
          BackupService(
            database: widget.database!,
            sourceDevice: localSourceDeviceId,
          );
      return ApplicationProviderScope(
        database: widget.database!,
        backupService: backupService,
        notificationScheduler:
            widget.notificationScheduler ??
            const UnsupportedNotificationScheduler(),
        child: content,
      );
    }
    return ProviderScope(
      overrides: [
        if (widget.notificationScheduler != null)
          notificationSchedulerProvider.overrideWithValue(
            widget.notificationScheduler!,
          ),
      ],
      child: content,
    );
  }
}

final class _NotificationLifecycle extends ConsumerStatefulWidget {
  const _NotificationLifecycle({
    required this.child,
    this.tapDispatcher,
    this.initializationError,
  });

  final Widget child;
  final NotificationTapDispatcher? tapDispatcher;
  final String? initializationError;

  @override
  ConsumerState<_NotificationLifecycle> createState() =>
      _NotificationLifecycleState();
}

final class _NotificationLifecycleState
    extends ConsumerState<_NotificationLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.tapDispatcher?.addListener(_routeNotification);
    _routeNotification();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initializationError = widget.initializationError;
      if (initializationError != null) {
        ref
            .read(notificationCapabilityControllerProvider.notifier)
            .warning(initializationError);
      }
      unawaited(_initializeNotifications());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcile());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.tapDispatcher?.removeListener(_routeNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _reconcile() async {
    await ref
        .read(notificationCapabilityControllerProvider.notifier)
        .reconcileAll();
  }

  Future<void> _initializeNotifications() async {
    final controller = ref.read(
      notificationCapabilityControllerProvider.notifier,
    );
    await controller.initialize();
  }

  void _routeNotification() {
    final payload = widget.tapDispatcher?.take();
    if (payload == null) return;
    if (payload.depositId.isEmpty) {
      ref.read(routerProvider).go('/');
      return;
    }
    final depositId = Uri.encodeComponent(payload.depositId);
    final customerId = Uri.encodeQueryComponent(payload.customerId);
    ref
        .read(routerProvider)
        .go('/notifications/$depositId?customerId=$customerId');
  }
}

class _DepositRenewalMaterialApp extends ConsumerWidget {
  const _DepositRenewalMaterialApp({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: '存款续期',
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    themeMode: themeMode,
    routerConfig: ref.watch(routerProvider),
  );
}
