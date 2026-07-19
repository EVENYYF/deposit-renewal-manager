import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notification_scheduler.dart';
import 'router.dart';
import 'theme.dart';

class DepositRenewalApp extends StatelessWidget {
  const DepositRenewalApp({
    this.themeMode = ThemeMode.light,
    this.notificationScheduler,
    this.notificationTapDispatcher,
    super.key,
  });

  final ThemeMode themeMode;
  final NotificationScheduler? notificationScheduler;
  final NotificationTapDispatcher? notificationTapDispatcher;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      if (notificationScheduler != null)
        notificationSchedulerProvider.overrideWithValue(notificationScheduler!),
    ],
    child: _NotificationLifecycle(
      tapDispatcher: notificationTapDispatcher,
      child: _DepositRenewalMaterialApp(themeMode: themeMode),
    ),
  );
}

final class _NotificationLifecycle extends ConsumerStatefulWidget {
  const _NotificationLifecycle({required this.child, this.tapDispatcher});

  final Widget child;
  final NotificationTapDispatcher? tapDispatcher;

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
    unawaited(_reconcile());
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
    try {
      await ref.read(notificationSchedulerProvider).reconcileAll();
    } catch (_) {
      // UI surfaces capability and retry controls; lifecycle work must not crash.
    }
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
