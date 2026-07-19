import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';

final class DashboardSnapshot {
  const DashboardSnapshot({
    this.dueSoonCount = 0,
    this.overdueCount = 0,
    this.customerCount = 0,
    this.today = const [],
    this.nextThreeDays = const [],
    this.thisWeek = const [],
    this.overdue = const [],
  });

  final int dueSoonCount;
  final int overdueCount;
  final int customerCount;
  final List<DashboardReminder> today;
  final List<DashboardReminder> nextThreeDays;
  final List<DashboardReminder> thisWeek;
  final List<DashboardReminder> overdue;

  bool get isEmpty =>
      dueSoonCount == 0 && overdueCount == 0 && customerCount == 0;
}

final class DashboardReminder {
  const DashboardReminder({
    required this.depositId,
    required this.customerId,
    required this.customerName,
    required this.bankName,
    required this.amountCents,
    required this.expiryDate,
    required this.startDate,
    this.calculatedExpiryDate,
    required this.interestRateScaled,
    required this.ratePrecision,
  });

  final String depositId;
  final String customerId;
  final String customerName;
  final String bankName;
  final int amountCents;
  final String expiryDate;
  final String startDate;
  final String? calculatedExpiryDate;
  final int interestRateScaled;
  final int ratePrecision;
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
    final generation = ++_requestGeneration;
    return _load(generation);
  }

  Future<void> retry() => _refresh();

  Future<void> saveAndRefresh(DashboardCommand command) async {
    var generation = ++_requestGeneration;
    if (_disposed) return;
    state = const AsyncLoading<DashboardSnapshot>();
    try {
      await _useCases.save(command);
      await ref
          .read(notificationMutationCoordinatorProvider)
          .reconcileDeposit(command.depositId);
      if (_disposed) return;
      generation = ++_requestGeneration;
      state = const AsyncLoading<DashboardSnapshot>();
      await _load(generation);
    } catch (error, stack) {
      if (_isCurrent(generation)) state = AsyncError(error, stack);
    }
  }

  Future<void> _refresh() async {
    final generation = ++_requestGeneration;
    if (_disposed) return;
    state = const AsyncLoading<DashboardSnapshot>();
    try {
      await _load(generation);
    } catch (error, stack) {
      if (_isCurrent(generation)) state = AsyncError(error, stack);
    }
  }

  Future<DashboardSnapshot> _load(int generation) async {
    final snapshot = await _useCases.load();
    if (_isCurrent(generation)) state = AsyncData(snapshot);
    return _isCurrent(generation) ? snapshot : (state.value ?? snapshot);
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
