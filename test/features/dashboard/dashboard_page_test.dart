import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:deposit_renewal_manager/features/dashboard/application/dashboard_controller.dart';
import 'package:deposit_renewal_manager/features/dashboard/presentation/dashboard_page.dart';
import 'package:deposit_renewal_manager/features/deposits/presentation/deposit_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows reminder sections and quick actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardUseCasesProvider.overrideWithValue(const _Cases()),
          notificationSchedulerProvider.overrideWithValue(
            const UnsupportedNotificationScheduler(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardPage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日到期'), findsOneWidget);
    expect(find.text('三天内'), findsOneWidget);
    expect(find.text('本周内'), findsOneWidget);
    expect(find.text('到期待处理'), findsOneWidget);
    expect(find.text('续期'), findsWidgets);
    expect(find.text('停止续期'), findsWidgets);

    await tester.tap(find.text('提示语'));
    await tester.pumpAndSettle();
    expect(find.text('续期提示语'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
  });

  testWidgets('renew opens a prefilled renewal form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardUseCasesProvider.overrideWithValue(const _Cases()),
          notificationSchedulerProvider.overrideWithValue(
            const UnsupportedNotificationScheduler(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('续期'));
    await tester.pumpAndSettle();
    expect(find.byType(DepositFormPage), findsOneWidget);
    expect(find.byKey(const Key('customer-name')), findsOneWidget);

    Navigator.of(tester.element(find.byType(DepositFormPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新'));
    await tester.pumpAndSettle();
    expect(find.text('更新存款'), findsOneWidget);
  });
}

final class _Cases implements DashboardUseCases {
  const _Cases();
  @override
  Future<DashboardSnapshot> load() async => const DashboardSnapshot(
    dueSoonCount: 1,
    today: [
      DashboardReminder(
        depositId: 'd1',
        customerId: 'c1',
        customerName: '张三',
        bankName: '银行',
        amountCents: 100,
        expiryDate: '2026-07-19',
        startDate: '2025-07-19',
        calculatedExpiryDate: '2026-07-19',
        interestRateScaled: 15000,
        ratePrecision: 4,
      ),
    ],
  );
  @override
  Future<void> save(DashboardCommand command) async {}
}
