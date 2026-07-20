import 'dart:async';

import 'package:deposit_renewal_manager/features/customers/application/customer_controller.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stale search cannot overwrite the latest query', () async {
    final q1 = Completer<List<CustomerSearchResult>>();
    final q2 = Completer<List<CustomerSearchResult>>();
    final useCases = _FakeCustomerUseCases()
      ..responses[''] = [Future.value(const [])]
      ..responses['q1'] = [q1.future]
      ..responses['q2'] = [q2.future];
    final container = ProviderContainer(
      overrides: [customerUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);
    await container.read(customerControllerProvider.future);

    final first = container
        .read(customerControllerProvider.notifier)
        .search('q1');
    final second = container
        .read(customerControllerProvider.notifier)
        .search('q2');
    q2.complete(const []);
    await second;
    q1.complete([_result('old')]);
    await first;

    final state = container.read(customerControllerProvider).value!;
    expect(state.query, 'q2');
    expect(state.results, isEmpty);
  });

  test('retry recovers from an error and save refreshes data', () async {
    final useCases = _FakeCustomerUseCases()
      ..responses[''] = [
        Future.error(StateError('offline')),
        Future.value([_result('saved')]),
        Future.value([_result('saved')]),
      ];
    final notifications = _FakeMutationCoordinator();
    final container = ProviderContainer(
      overrides: [
        customerUseCasesProvider.overrideWithValue(useCases),
        notificationMutationCoordinatorProvider.overrideWithValue(
          notifications,
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(customerControllerProvider.future),
      throwsA(isA<StateError>()),
    );
    await container.read(customerControllerProvider.notifier).retry();
    expect(
      container.read(customerControllerProvider).value!.results,
      hasLength(1),
    );

    await container
        .read(customerControllerProvider.notifier)
        .saveAndRefresh(const CustomerDraft(id: 'new', name: 'New'));
    expect(useCases.saved, hasLength(1));
    expect(notifications.reconcileAllCalls, 1);
  });

  test('a search during save is followed by a refresh of its query', () async {
    final savePending = Completer<void>();
    final searchPending = Completer<List<CustomerSearchResult>>();
    final useCases = _FakeCustomerUseCases()
      ..responses[''] = [Future.value(const [])]
      ..responses['latest'] = [
        searchPending.future,
        Future.value([_result('saved')]),
      ]
      ..saveResults.add(savePending.future);
    final container = ProviderContainer(
      overrides: [customerUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);
    await container.read(customerControllerProvider.future);

    final save = container
        .read(customerControllerProvider.notifier)
        .saveAndRefresh(const CustomerDraft(id: 'new', name: 'New'));
    final search = container
        .read(customerControllerProvider.notifier)
        .search('latest');
    searchPending.complete([_result('old')]);
    await search;
    savePending.complete();
    await save;

    final state = container.read(customerControllerProvider).value!;
    expect(state.query, 'latest');
    expect(state.results.single.customer.id, 'saved');
  });

  test('a retry during save cannot suppress the post-save refresh', () async {
    final savePending = Completer<void>();
    final retryPending = Completer<List<CustomerSearchResult>>();
    final useCases = _FakeCustomerUseCases()
      ..responses[''] = [
        Future.value(const []),
        retryPending.future,
        Future.value([_result('saved')]),
      ]
      ..saveResults.add(savePending.future);
    final container = ProviderContainer(
      overrides: [customerUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);
    await container.read(customerControllerProvider.future);

    final save = container
        .read(customerControllerProvider.notifier)
        .saveAndRefresh(const CustomerDraft(id: 'new', name: 'New'));
    final retry = container.read(customerControllerProvider.notifier).retry();
    retryPending.complete([_result('old')]);
    await retry;
    savePending.complete();
    await save;

    expect(
      container
          .read(customerControllerProvider)
          .value!
          .results
          .single
          .customer
          .id,
      'saved',
    );
  });

  test('initial load cannot overwrite a manual retry', () async {
    final initial = Completer<List<CustomerSearchResult>>();
    final retryPending = Completer<List<CustomerSearchResult>>();
    final useCases = _FakeCustomerUseCases()
      ..responses[''] = [initial.future, retryPending.future];
    final container = ProviderContainer(
      overrides: [customerUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);

    final initialLoad = container.read(customerControllerProvider.future);
    final retry = container.read(customerControllerProvider.notifier).retry();
    retryPending.complete([_result('new')]);
    await retry;
    initial.complete([_result('old')]);
    await initialLoad;

    expect(
      container
          .read(customerControllerProvider)
          .value!
          .results
          .single
          .customer
          .id,
      'new',
    );
  });

  test('retry keeps previous customers during refresh', () async {
    final pending = Completer<List<CustomerSearchResult>>();
    final useCases = _FakeCustomerUseCases()
      ..responses[''] = [
        Future.value([_result('old')]),
        pending.future,
      ];
    final container = ProviderContainer(
      overrides: [customerUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);
    await container.read(customerControllerProvider.future);

    final retry = container.read(customerControllerProvider.notifier).retry();

    final refreshing = container.read(customerControllerProvider);
    expect(refreshing.hasValue, isTrue);
    expect(refreshing.value?.results.single.customer.id, 'old');
    pending.complete([_result('new')]);
    await retry;
    expect(
      container
          .read(customerControllerProvider)
          .value
          ?.results
          .single
          .customer
          .id,
      'new',
    );
  });

  test('retry failure keeps previous customers', () async {
    final failure = Completer<List<CustomerSearchResult>>();
    final useCases = _FakeCustomerUseCases()
      ..responses[''] = [
        Future.value([_result('old')]),
        failure.future,
      ];
    final container = ProviderContainer(
      overrides: [customerUseCasesProvider.overrideWithValue(useCases)],
    );
    addTearDown(container.dispose);
    await container.read(customerControllerProvider.future);

    final retry = container.read(customerControllerProvider.notifier).retry();
    failure.completeError(StateError('offline'));
    await retry;

    final failed = container.read(customerControllerProvider);
    expect(failed.hasError, isFalse);
    expect(failed.value?.results.single.customer.id, 'old');
    expect(container.read(customerRefreshMessageProvider), isNotNull);
  });
}

final class _FakeMutationCoordinator
    implements NotificationMutationCoordinator {
  int reconcileAllCalls = 0;
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
  Future<void> reconcileAll() async => reconcileAllCalls++;
  @override
  Future<void> reconcileDeposit(String depositId) async {}
  @override
  Future<void> reconcileSummary() async {}
}

CustomerSearchResult _result(String id) => CustomerSearchResult(
  customer: CustomerRecord(id: id, name: id, phone: null, isActive: true),
  deposits: const [],
);

final class _FakeCustomerUseCases implements CustomerUseCases {
  final Map<String, List<Future<List<CustomerSearchResult>>>> responses = {};
  final List<CustomerDraft> saved = [];
  final List<Future<void>> saveResults = [];

  @override
  Future<List<CustomerSearchResult>> load(String query) =>
      responses[query]!.removeAt(0);

  @override
  Future<void> save(CustomerDraft draft) async {
    saved.add(draft);
    if (saveResults.isNotEmpty) await saveResults.removeAt(0);
  }
}
