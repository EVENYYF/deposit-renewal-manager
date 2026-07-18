import 'dart:async';

import 'package:deposit_renewal_manager/features/dashboard/application/dashboard_controller.dart';
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
    final container = ProviderContainer(
      overrides: [dashboardUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);

    await container.read(dashboardControllerProvider.future);
    await container
        .read(dashboardControllerProvider.notifier)
        .saveAndRefresh(command);

    expect(useCases.savedCommands, [command]);
    expect(container.read(dashboardControllerProvider).value?.overdueCount, 1);
    expect(useCases.loadCalls, 2);
  });
}

final class _FakeDashboardUseCases implements DashboardUseCases {
  final List<Future<DashboardSnapshot>> loadResults = [];
  final List<DashboardCommand> savedCommands = [];
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
  }
}
