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
  DashboardUseCases get _useCases => ref.read(dashboardUseCasesProvider);

  @override
  Future<DashboardSnapshot> build() => _useCases.load();

  Future<void> retry() => _refresh();

  Future<void> saveAndRefresh(DashboardCommand command) async {
    state = const AsyncLoading<DashboardSnapshot>();
    state = await AsyncValue.guard(() async {
      await _useCases.save(command);
      return _useCases.load();
    });
  }

  Future<void> _refresh() async {
    state = const AsyncLoading<DashboardSnapshot>();
    state = await AsyncValue.guard(_useCases.load);
  }
}
