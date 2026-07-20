import 'package:deposit_renewal_manager/app/app.dart';
import 'package:deposit_renewal_manager/app/router.dart';
import 'package:deposit_renewal_manager/features/templates/presentation/templates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const destinations = ['首页', '客户', '新增', '设置'];

  void setSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('uses bottom navigation with four destinations on a phone', (
    tester,
  ) async {
    setSize(tester, const Size(390, 844));

    await tester.pumpWidget(const DepositRenewalApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final destination in destinations) {
      expect(find.text(destination), findsWidgets);
    }
  });

  testWidgets('opens templates from settings', (tester) async {
    setSize(tester, const Size(390, 844));

    await tester.pumpWidget(const DepositRenewalApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(find.text('消息模板'), findsOneWidget);

    await tester.tap(find.text('消息模板'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplatesPage), findsOneWidget);
  });

  testWidgets('uses a navigation rail on a wide window', (tester) async {
    setSize(tester, const Size(1024, 768));

    await tester.pumpWidget(const DepositRenewalApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('selecting every destination updates route and selection', (
    tester,
  ) async {
    setSize(tester, const Size(390, 844));
    await tester.pumpWidget(const DepositRenewalApp());
    await tester.pumpAndSettle();

    for (var index = 1; index < destinations.length; index++) {
      await tester.tap(find.text(destinations[index]).last);
      await tester.pumpAndSettle();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, index);
      expect(find.text(destinations[index]), findsWidgets);
    }
  });

  testWidgets('notification deep link stays inside the shell and can go back', (
    tester,
  ) async {
    setSize(tester, const Size(390, 844));
    await tester.pumpWidget(const DepositRenewalApp());
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.byType(NavigationBar)),
    ).go('/notifications/42');
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('通知\n42'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    GoRouter.of(tester.element(find.byType(NavigationBar))).pop();
    await tester.pumpAndSettle();
    expect(find.text('存款续期'), findsOneWidget);
  });

  testWidgets('notification deep link cold start selects the dashboard shell', (
    tester,
  ) async {
    setSize(tester, const Size(390, 844));
    final router = createAppRouter(initialLocation: '/notifications/42');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(router)],
        child: const DepositRenewalApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('通知\n42'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('存款续期'), findsOneWidget);
  });

  testWidgets('long Chinese copy and large text do not overflow', (
    tester,
  ) async {
    setSize(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const DepositRenewalApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('supports ${mode.name} semantic theme', (tester) async {
      setSize(tester, const Size(390, 844));

      await tester.pumpWidget(DepositRenewalApp(themeMode: mode));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold).first);
      expect(
        Theme.of(context).brightness,
        mode == ThemeMode.light ? Brightness.light : Brightness.dark,
      );
    });
  }
}
