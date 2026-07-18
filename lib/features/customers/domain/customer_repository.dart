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

abstract interface class CustomerRepository {
  Future<CustomerRecord> create(CustomerDraft draft);

  Future<CustomerRecord?> get(String id);

  Future<CustomerRecord> update(String id, CustomerDraft draft);

  Future<void> deactivate(String id);
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
