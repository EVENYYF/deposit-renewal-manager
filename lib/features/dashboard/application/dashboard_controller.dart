import 'package:flutter_riverpod/flutter_riverpod.dart';

final class DashboardSnapshot {
  const DashboardSnapshot({
    this.dueSoonCount = 0,
    this.overdueCount = 0,
    this.customerCount = 0,
  });

  final int dueSoonCount;
  final int overdueCount;
  final int customerCount;

  bool get isEmpty =>
      dueSoonCount == 0 && overdueCount == 0 && customerCount == 0;
}

final class DashboardCommand {
  const DashboardCommand(this.depositId);

  final String depositId;
}

abstract interface class DashboardUseCases {
  Future<DashboardSnapshot> load();

  Future<void> save(DashboardCommand command);
}

final class EmptyDashboardUseCases implements DashboardUseCases {
  const EmptyDashboardUseCases();

  @override
  Future<DashboardSnapshot> load() async => const DashboardSnapshot();

  @override
  Future<void> save(DashboardCommand command) async {}
}

final dashboardUseCasesProvider = Provider<DashboardUseCases>(
  (ref) => const EmptyDashboardUseCases(),
);

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardSnapshot>(
      DashboardController.new,
    );

final class DashboardController extends AsyncNotifier<DashboardSnapshot> {
  int _requestGeneration = 0;
  bool _disposed = false;
  bool _lifecycleBound = false;

  DashboardUseCases get _useCases => ref.read(dashboardUseCasesProvider);

  @override
  Future<DashboardSnapshot> build() {
    _bindLifecycle();
    ++_requestGeneration;
    return _useCases.load();
  }

  Future<void> retry() => _refresh();

  Future<void> saveAndRefresh(DashboardCommand command) async {
    final generation = ++_requestGeneration;
    if (_disposed) return;
    state = const AsyncLoading<DashboardSnapshot>();
    try {
      await _useCases.save(command);
      if (!_isCurrent(generation)) return;
      final snapshot = await _useCases.load();
      if (_isCurrent(generation)) state = AsyncData(snapshot);
    } catch (error, stack) {
      if (_isCurrent(generation)) state = AsyncError(error, stack);
    }
  }

  Future<void> _refresh() async {
    final generation = ++_requestGeneration;
    if (_disposed) return;
    state = const AsyncLoading<DashboardSnapshot>();
    try {
      final snapshot = await _useCases.load();
      if (_isCurrent(generation)) state = AsyncData(snapshot);
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
