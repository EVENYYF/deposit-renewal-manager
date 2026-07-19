import 'dart:async';

import 'package:deposit_renewal_manager/features/customers/application/customer_controller.dart';
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
    final container = ProviderContainer(
      overrides: [customerUseCasesProvider.overrideWithValue(useCases)],
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
  });
}

CustomerSearchResult _result(String id) => CustomerSearchResult(
  customer: CustomerRecord(id: id, name: id, phone: null, isActive: true),
  deposits: const [],
);

final class _FakeCustomerUseCases implements CustomerUseCases {
  final Map<String, List<Future<List<CustomerSearchResult>>>> responses = {};
  final List<CustomerDraft> saved = [];

  @override
  Future<List<CustomerSearchResult>> load(String query) =>
      responses[query]!.removeAt(0);

  @override
  Future<void> save(CustomerDraft draft) async => saved.add(draft);
}
