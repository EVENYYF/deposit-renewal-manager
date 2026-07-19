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
  int _requestGeneration = 0;
  bool _disposed = false;
  bool _lifecycleBound = false;

  CustomerUseCases get _useCases => ref.read(customerUseCasesProvider);

  @override
  Future<CustomerDirectoryState> build() {
    _bindLifecycle();
    ++_requestGeneration;
    final query = _query;
    return _load(query);
  }

  Future<void> search(String query) async {
    final normalized = query.trim();
    _query = normalized;
    await _refresh(normalized);
  }

  Future<void> retry() => _refresh(_query);

  Future<void> saveAndRefresh(CustomerDraft draft) async {
    final generation = ++_requestGeneration;
    final query = _query;
    if (_disposed) return;
    state = const AsyncLoading<CustomerDirectoryState>();
    try {
      await _useCases.save(draft);
      if (!_isCurrent(generation)) return;
      final results = await _useCases.load(query);
      if (_isCurrent(generation)) {
        state = AsyncData(
          CustomerDirectoryState(query: query, results: results),
        );
      }
    } catch (error, stack) {
      if (_isCurrent(generation)) state = AsyncError(error, stack);
    }
  }

  Future<CustomerDirectoryState> _load(String query) async =>
      CustomerDirectoryState(
        query: query,
        results: await _useCases.load(query),
      );

  Future<void> _refresh(String query) async {
    final generation = ++_requestGeneration;
    if (_disposed) return;
    state = const AsyncLoading<CustomerDirectoryState>();
    try {
      final results = await _useCases.load(query);
      if (_isCurrent(generation)) {
        state = AsyncData(
          CustomerDirectoryState(query: query, results: results),
        );
      }
    } catch (error, stack) {
      if (_isCurrent(generation)) state = AsyncError(error, stack);
    }
  }

  void _bindLifecycle() {
    if (_lifecycleBound) return;
    _lifecycleBound = true;
    ref.onDispose(() {
      _disposed = true;
      _requestGeneration++;
    });
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _requestGeneration;
}
