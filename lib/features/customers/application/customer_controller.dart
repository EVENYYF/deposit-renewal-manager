import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
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
    final generation = ++_requestGeneration;
    final query = _query;
    return _load(generation, query);
  }

  Future<void> search(String query) async {
    final normalized = query.trim();
    _query = normalized;
    await _refresh(normalized);
  }

  Future<void> retry() => _refresh(_query);

  Future<void> saveAndRefresh(CustomerDraft draft) async {
    var generation = ++_requestGeneration;
    if (_disposed) return;
    state = const AsyncLoading<CustomerDirectoryState>();
    try {
      await _useCases.save(draft);
      await ref.read(notificationMutationCoordinatorProvider).reconcileAll();
      if (_disposed) return;
      generation = ++_requestGeneration;
      state = const AsyncLoading<CustomerDirectoryState>();
      await _load(generation, _query);
    } catch (error, stack) {
      if (_isCurrent(generation)) state = AsyncError(error, stack);
    }
  }

  Future<CustomerDirectoryState> _load(int generation, String query) async {
    final results = await _useCases.load(query);
    final loaded = CustomerDirectoryState(query: query, results: results);
    if (_isCurrent(generation)) state = AsyncData(loaded);
    return _isCurrent(generation) ? loaded : (state.value ?? loaded);
  }

  Future<void> _refresh(String query) async {
    final generation = ++_requestGeneration;
    if (_disposed) return;
    state = const AsyncLoading<CustomerDirectoryState>();
    try {
      await _load(generation, query);
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
