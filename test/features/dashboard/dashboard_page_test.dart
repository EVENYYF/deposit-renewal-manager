import 'dart:async';

import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/dashboard/application/dashboard_controller.dart';
import 'package:deposit_renewal_manager/features/deposits/application/deposit_workflow_controller.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/dashboard/presentation/dashboard_page.dart';
import 'package:deposit_renewal_manager/features/deposits/presentation/deposit_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides notification banner when capability is healthy', (
    tester,
  ) async {
    await _pumpNotificationBanner(
      tester,
      const _CapabilityScheduler(
        NotificationCapability(
          support: NotificationSupport.supported,
          notificationsAllowed: true,
          canScheduleExact: true,
        ),
      ),
    );

    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.text('通知提醒需要处理'), findsNothing);
  });

  testWidgets('notification banner explains missing notification permission', (
    tester,
  ) async {
    await _pumpNotificationBanner(
      tester,
      const _CapabilityScheduler(
        NotificationCapability(
          support: NotificationSupport.supported,
          notificationsAllowed: false,
          canScheduleExact: true,
        ),
      ),
    );

    expect(find.text('通知权限未开启，无法发送到期提醒'), findsOneWidget);
    expect(find.text('开启通知'), findsOneWidget);
  });

  testWidgets('notification banner explains missing exact alarm permission', (
    tester,
  ) async {
    await _pumpNotificationBanner(
      tester,
      const _CapabilityScheduler(
        NotificationCapability(
          support: NotificationSupport.supported,
          notificationsAllowed: true,
          canScheduleExact: false,
        ),
      ),
    );

    expect(find.text('精确提醒未开启，提醒时间可能延后'), findsOneWidget);
    expect(find.text('开启精确提醒'), findsOneWidget);
  });

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
    expect(find.byType(RefreshIndicator), findsOneWidget);
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

  testWidgets('stop action is disabled while the mutation is pending', (
    tester,
  ) async {
    final workflow = _PendingStopWorkflow();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardUseCasesProvider.overrideWithValue(const _Cases()),
          depositWorkflowProvider.overrideWithValue(workflow),
          notificationSchedulerProvider.overrideWithValue(
            const UnsupportedNotificationScheduler(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('停止续期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认停止'));
    await tester.pump();

    final stopButton = tester.widget<TextButton>(
      find.ancestor(of: find.text('停止续期'), matching: find.byType(TextButton)),
    );
    expect(stopButton.onPressed, isNull);
    expect(workflow.stopCalls, 1);

    workflow.stopCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('refresh failure keeps dashboard content and shows feedback', (
    tester,
  ) async {
    final cases = _RefreshFailureCases();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardUseCasesProvider.overrideWithValue(cases),
          notificationSchedulerProvider.overrideWithValue(
            const UnsupportedNotificationScheduler(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardPage())),
      ),
    );
    await tester.pumpAndSettle();

    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final pendingRefresh = refresh.onRefresh();
    cases.refresh.completeError(StateError('offline'));
    await pendingRefresh;
    await tester.pump();

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('首页刷新失败，请稍后重试'), findsOneWidget);
  });
}

Future<void> _pumpNotificationBanner(
  WidgetTester tester,
  NotificationScheduler scheduler,
) async {
  final container = ProviderContainer(
    overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
  );
  addTearDown(container.dispose);
  await container
      .read(notificationCapabilityControllerProvider.notifier)
      .refresh();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: NotificationStatusBanner())),
    ),
  );
  await tester.pump();
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

final class _RefreshFailureCases implements DashboardUseCases {
  final refresh = Completer<DashboardSnapshot>();
  int loadCalls = 0;

  @override
  Future<DashboardSnapshot> load() {
    loadCalls++;
    return loadCalls == 1 ? const _Cases().load() : refresh.future;
  }

  @override
  Future<void> save(DashboardCommand command) async {}
}

final class _PendingStopWorkflow implements DepositWorkflow {
  final stopCompleter = Completer<void>();
  int stopCalls = 0;

  @override
  Future<void> create(DepositDraft draft) async {}

  @override
  Future<void> createWithCustomer(
    DepositDraft draft,
    CustomerDraft customer,
  ) async {}

  @override
  Future<void> renew(String sourceDepositId, DepositDraft draft) async {}

  @override
  Future<void> stop(String depositId) {
    stopCalls++;
    return stopCompleter.future;
  }

  @override
  Future<void> update(String depositId, DepositDraft draft) async {}
}

final class _CapabilityScheduler implements NotificationScheduler {
  const _CapabilityScheduler(this.value);

  final NotificationCapability value;

  @override
  Future<NotificationCapability> get capability async => value;

  NotificationReconcileResult get _result => NotificationReconcileResult(
    capability: value,
    scheduledCount: 0,
    cancelledCount: 0,
  );

  @override
  Future<NotificationReconcileResult> cancelDeposit(String depositId) async =>
      _result;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<NotificationReconcileResult> reconcileAll() async => _result;

  @override
  Future<NotificationReconcileResult> reconcileDeposit(String depositId) async =>
      _result;

  @override
  Future<NotificationReconcileResult> reconcileSummary() async => _result;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;
}
