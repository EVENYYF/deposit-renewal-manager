import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class CustomerDirectoryState {
  CustomerDirectoryState({
    this.query = '',
    Iterable<CustomerSearchResult> results = const [],
  }) : results = List.unmodifiable(results);

  final String query;
  final List<CustomerSearchResult> results;

  bool get isEmpty => results.isEmpty;
}

abstract interface class CustomerUseCases {
  Future<List<CustomerSearchResult>> load(String query);

  Future<void> save(CustomerDraft draft);
}

final class EmptyCustomerUseCases implements CustomerUseCases {
  const EmptyCustomerUseCases();

  @override
  Future<List<CustomerSearchResult>> load(String query) async => const [];

  @override
  Future<void> save(CustomerDraft draft) async {}
}

final customerUseCasesProvider = Provider<CustomerUseCases>(
  (ref) => const EmptyCustomerUseCases(),
);

final customerControllerProvider =
    AsyncNotifierProvider<CustomerController, CustomerDirectoryState>(
      CustomerController.new,
    );

final class CustomerController extends AsyncNotifier<CustomerDirectoryState> {
  String _query = '';

  CustomerUseCases get _useCases => ref.read(customerUseCasesProvider);

  @override
  Future<CustomerDirectoryState> build() => _load();

  Future<void> search(String query) async {
    _query = query.trim();
    await _refresh();
  }

  Future<void> retry() => _refresh();

  Future<void> saveAndRefresh(CustomerDraft draft) async {
    state = const AsyncLoading<CustomerDirectoryState>();
    state = await AsyncValue.guard(() async {
      await _useCases.save(draft);
      return _load();
    });
  }

  Future<CustomerDirectoryState> _load() async => CustomerDirectoryState(
    query: _query,
    results: await _useCases.load(_query),
  );

  Future<void> _refresh() async {
    state = const AsyncLoading<CustomerDirectoryState>();
    state = await AsyncValue.guard(_load);
  }
}
