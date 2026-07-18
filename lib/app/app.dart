import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class DepositRenewalApp extends StatelessWidget {
  const DepositRenewalApp({this.themeMode = ThemeMode.light, super.key});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) =>
      ProviderScope(child: _DepositRenewalMaterialApp(themeMode: themeMode));
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
