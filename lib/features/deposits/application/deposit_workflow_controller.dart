import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/deposit_repository.dart';
import '../../customers/domain/customer_repository.dart';

abstract interface class DepositWorkflow {
  Future<void> create(DepositDraft draft);
  Future<void> createWithCustomer(DepositDraft draft, CustomerDraft customer);
  Future<void> update(String depositId, DepositDraft draft);
  Future<void> renew(String sourceDepositId, DepositDraft draft);
  Future<void> stop(String depositId);
}

final class EmptyDepositWorkflow implements DepositWorkflow {
  const EmptyDepositWorkflow();

  @override
  Future<void> create(DepositDraft draft) async {}
  @override
  Future<void> createWithCustomer(
    DepositDraft draft,
    CustomerDraft customer,
  ) async {}
  @override
  Future<void> renew(String sourceDepositId, DepositDraft draft) async {}
  @override
  Future<void> stop(String depositId) async {}
  @override
  Future<void> update(String depositId, DepositDraft draft) async {}
}

final depositWorkflowProvider = Provider<DepositWorkflow>(
  (ref) => const EmptyDepositWorkflow(),
);
