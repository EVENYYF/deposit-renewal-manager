import 'dart:async';

import 'package:deposit_renewal_manager/features/dashboard/application/dashboard_controller.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads and exposes an empty dashboard', () async {
    final pending = Completer<DashboardSnapshot>();
    final useCases = _FakeDashboardUseCases()..loadResults.add(pending.future);
    final container = ProviderContainer(
      overrides: [dashboardUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      dashboardControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    expect(container.read(dashboardControllerProvider).isLoading, isTrue);

    pending.complete(const DashboardSnapshot());
    final result = await container.read(dashboardControllerProvider.future);

    expect(result.isEmpty, isTrue);
    expect(useCases.loadCalls, 1);
  });

  test('exposes an error and retry loads data again', () async {
    final useCases = _FakeDashboardUseCases()
      ..loadResults.add(Future.error(StateError('offline')))
      ..loadResults.add(Future.value(const DashboardSnapshot(dueSoonCount: 2)));
    final container = ProviderContainer(
      overrides: [dashboardUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(dashboardControllerProvider.future),
      throwsA(isA<StateError>()),
    );
    expect(container.read(dashboardControllerProvider).hasError, isTrue);

    await container.read(dashboardControllerProvider.notifier).retry();

    expect(container.read(dashboardControllerProvider).value?.dueSoonCount, 2);
    expect(useCases.loadCalls, 2);
  });

  test('saving a command refreshes the dashboard', () async {
    const command = DashboardCommand('deposit-1');
    final useCases = _FakeDashboardUseCases()
      ..loadResults.add(Future.value(const DashboardSnapshot()))
      ..loadResults.add(Future.value(const DashboardSnapshot(overdueCount: 1)));
    final notifications = _FakeMutationCoordinator();
    final container = ProviderContainer(
      overrides: [
        dashboardUseCasesProvider.overrideWithValue(useCases),
        notificationMutationCoordinatorProvider.overrideWithValue(
          notifications,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(dashboardControllerProvider.future);
    await container
        .read(dashboardControllerProvider.notifier)
        .saveAndRefresh(command);

    expect(useCases.savedCommands, [command]);
    expect(notifications.reconciledDeposits, ['deposit-1']);
    expect(container.read(dashboardControllerProvider).value?.overdueCount, 1);
    expect(useCases.loadCalls, 2);
  });

  test('an older retry cannot overwrite a newer save refresh', () async {
    const command = DashboardCommand('deposit-2');
    final older = Completer<DashboardSnapshot>();
    final newer = Completer<DashboardSnapshot>();
    final useCases = _FakeDashboardUseCases()
      ..loadResults.add(Future.value(const DashboardSnapshot()))
      ..loadResults.add(older.future)
      ..loadResults.add(newer.future);
    final container = ProviderContainer(
      overrides: [dashboardUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);
    await container.read(dashboardControllerProvider.future);

    final retry = container.read(dashboardControllerProvider.notifier).retry();
    final save = container
        .read(dashboardControllerProvider.notifier)
        .saveAndRefresh(command);
    newer.complete(const DashboardSnapshot(customerCount: 7));
    await save;
    older.complete(const DashboardSnapshot(customerCount: 1));
    await retry;

    expect(container.read(dashboardControllerProvider).value?.customerCount, 7);
  });

  test('a retry during save cannot suppress the post-save refresh', () async {
    const command = DashboardCommand('deposit-3');
    final savePending = Completer<void>();
    final retryPending = Completer<DashboardSnapshot>();
    final useCases = _FakeDashboardUseCases()
      ..loadResults.add(Future.value(const DashboardSnapshot()))
      ..loadResults.add(retryPending.future)
      ..loadResults.add(Future.value(const DashboardSnapshot(customerCount: 9)))
      ..saveResults.add(savePending.future);
    final container = ProviderContainer(
      overrides: [dashboardUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);
    await container.read(dashboardControllerProvider.future);

    final save = container
        .read(dashboardControllerProvider.notifier)
        .saveAndRefresh(command);
    final retry = container.read(dashboardControllerProvider.notifier).retry();
    retryPending.complete(const DashboardSnapshot(customerCount: 1));
    await retry;
    savePending.complete();
    await save;

    expect(useCases.loadCalls, 3);
    expect(container.read(dashboardControllerProvider).value?.customerCount, 9);
  });

  test('initial load cannot overwrite a manual retry', () async {
    final initial = Completer<DashboardSnapshot>();
    final retryPending = Completer<DashboardSnapshot>();
    final useCases = _FakeDashboardUseCases()
      ..loadResults.add(initial.future)
      ..loadResults.add(retryPending.future);
    final container = ProviderContainer(
      overrides: [dashboardUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);

    final initialLoad = container.read(dashboardControllerProvider.future);
    final retry = container.read(dashboardControllerProvider.notifier).retry();
    retryPending.complete(const DashboardSnapshot(customerCount: 8));
    await retry;
    initial.complete(const DashboardSnapshot(customerCount: 1));
    await initialLoad;

    expect(container.read(dashboardControllerProvider).value?.customerCount, 8);
  });
}

final class _FakeMutationCoordinator
    implements NotificationMutationCoordinator {
  final List<String> reconciledDeposits = [];
  @override
  Future<void> afterCreateOrUpdate(String depositId) async {}
  @override
  Future<void> afterRenew(
    String sourceDepositId,
    String targetDepositId,
  ) async {}
  @override
  Future<void> afterStopOrDelete(String depositId) async {}
  @override
  Future<void> cancelDeposit(String depositId) async {}
  @override
  Future<void> reconcileAll() async {}
  @override
  Future<void> reconcileDeposit(String depositId) async =>
      reconciledDeposits.add(depositId);
  @override
  Future<void> reconcileSummary() async {}
}

final class _FakeDashboardUseCases implements DashboardUseCases {
  final List<Future<DashboardSnapshot>> loadResults = [];
  final List<DashboardCommand> savedCommands = [];
  final List<Future<void>> saveResults = [];
  int loadCalls = 0;

  @override
  Future<DashboardSnapshot> load() {
    final result = loadResults[loadCalls];
    loadCalls++;
    return result;
  }

  @override
  Future<void> save(DashboardCommand command) async {
    savedCommands.add(command);
    if (saveResults.isNotEmpty) await saveResults.removeAt(0);
  }
}
