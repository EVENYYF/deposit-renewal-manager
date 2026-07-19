import 'package:flutter_riverpod/flutter_riverpod.dart';

final class CustomerHistoryEntry {
  const CustomerHistoryEntry({
    required this.operation,
    required this.occurredAt,
  });
  final String operation;
  final DateTime occurredAt;
}

abstract interface class CustomerHistoryUseCases {
  Future<List<CustomerHistoryEntry>> load(String customerId);
}

final class EmptyCustomerHistoryUseCases implements CustomerHistoryUseCases {
  const EmptyCustomerHistoryUseCases();
  @override
  Future<List<CustomerHistoryEntry>> load(String customerId) async => const [];
}

final customerHistoryUseCasesProvider = Provider<CustomerHistoryUseCases>(
  (ref) => const EmptyCustomerHistoryUseCases(),
);
