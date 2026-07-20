import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customers/domain/customer_repository.dart';
import '../domain/deposit.dart';
import '../domain/deposit_repository.dart';
import '../presentation/deposit_details_view.dart';

final class DepositDetailsRecord {
  const DepositDetailsRecord({required this.data, required this.editableDraft});
  final DepositDetailsViewData data;
  final DepositDraft? editableDraft;
}

abstract interface class DepositDetailsUseCases {
  Future<DepositDetailsRecord?> load(String depositId);
}

final class EmptyDepositDetailsUseCases implements DepositDetailsUseCases {
  const EmptyDepositDetailsUseCases();
  @override
  Future<DepositDetailsRecord?> load(String depositId) async => null;
}

final depositDetailsUseCasesProvider = Provider<DepositDetailsUseCases>(
  (ref) => const EmptyDepositDetailsUseCases(),
);

final class RepositoryDepositDetailsUseCases implements DepositDetailsUseCases {
  const RepositoryDepositDetailsUseCases(this.deposits, this.customers);
  final DepositRepository deposits;
  final CustomerRepository customers;

  @override
  Future<DepositDetailsRecord?> load(String depositId) async {
    final stored = await deposits.get(depositId);
    if (stored == null) return null;
    final customer = await customers.get(stored.customerId);
    if (customer == null) return null;
    final active = stored.deposit.lifecycle == DepositLifecycle.active;
    final draft = DepositDraft(
      id: stored.deposit.id,
      customerId: stored.customerId,
      amountCents: stored.amountCents,
      bankName: stored.bankName,
      productName: stored.productName,
      termValue: stored.termValue,
      termUnit: stored.termUnit,
      interestRateScaled: stored.interestRateScaled,
      ratePrecision: stored.ratePrecision,
      startDate: stored.startDate,
      calculatedExpiryDate: stored.deposit.calculatedExpiryDate,
      finalExpiryDate: stored.deposit.finalExpiryDate,
    );
    return DepositDetailsRecord(
      data: DepositDetailsViewData(
        depositId: stored.deposit.id,
        customerName: customer.name,
        customerPhone: customer.phone,
        bankName: stored.bankName,
        productName: stored.productName,
        amountCents: stored.amountCents,
        interestRateScaled: stored.interestRateScaled,
        ratePrecision: stored.ratePrecision,
        startDate: stored.startDate,
        expiryDate: stored.deposit.finalExpiryDate,
        lifecycle: stored.deposit.lifecycle,
      ),
      editableDraft: active ? draft : null,
    );
  }
}
