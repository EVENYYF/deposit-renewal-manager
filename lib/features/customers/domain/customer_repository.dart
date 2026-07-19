import 'name_search_index.dart';

final class CustomerDraft {
  const CustomerDraft({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;
}

final class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? phone;
  final bool isActive;
}

final class CustomerSearchResult {
  CustomerSearchResult({
    required this.customer,
    required Iterable<CustomerSearchDeposit> deposits,
  }) : deposits = List.unmodifiable(deposits);

  final CustomerRecord customer;
  final List<CustomerSearchDeposit> deposits;
}

abstract interface class CustomerRepository {
  Future<CustomerRecord> create(CustomerDraft draft);

  Future<CustomerRecord?> get(String id);

  Future<CustomerRecord> update(String id, CustomerDraft draft);

  Future<void> deactivate(String id);

  Future<List<CustomerSearchResult>> search(CustomerQuery query);
}

final class CustomerHasActiveDepositsException implements Exception {
  const CustomerHasActiveDepositsException(this.customerId);

  final String customerId;

  @override
  String toString() =>
      'CustomerHasActiveDepositsException(customerId: $customerId)';
}

final class CustomerInactiveException implements Exception {
  const CustomerInactiveException(this.customerId);

  final String customerId;

  @override
  String toString() => 'CustomerInactiveException(customerId: $customerId)';
}
