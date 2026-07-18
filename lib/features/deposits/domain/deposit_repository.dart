import 'deposit.dart';
import 'local_date.dart';

final class DepositDraft {
  const DepositDraft({
    required this.id,
    required this.customerId,
    required this.amountCents,
    this.bankName = '',
    required this.interestRateScaled,
    required this.ratePrecision,
    required this.startDate,
    required this.calculatedExpiryDate,
    required this.finalExpiryDate,
  });

  final String id;
  final String customerId;
  final int amountCents;
  final String bankName;
  final int interestRateScaled;
  final int ratePrecision;
  final LocalDate startDate;
  final LocalDate? calculatedExpiryDate;
  final LocalDate finalExpiryDate;
}

final class StoredDeposit {
  const StoredDeposit({
    required this.deposit,
    required this.customerId,
    required this.amountCents,
    required this.bankName,
    required this.interestRateScaled,
    required this.ratePrecision,
    required this.startDate,
  });

  final Deposit deposit;
  final String customerId;
  final int amountCents;
  final String bankName;
  final int interestRateScaled;
  final int ratePrecision;
  final LocalDate startDate;
}

final class RenewalResult {
  const RenewalResult({required this.newDepositId});

  final String newDepositId;
}

abstract interface class DepositRepository {
  Future<StoredDeposit> create(DepositDraft draft);

  Future<StoredDeposit?> get(String id);

  Future<StoredDeposit> update(String id, DepositDraft draft);

  Future<RenewalResult> renew(String sourceId, DepositDraft next);

  Future<void> stopRenewal(String id);

  Future<String?> renewalSourceOf(String targetDepositId);
}

final class DepositNotActiveException implements Exception {
  const DepositNotActiveException(this.depositId);

  final String depositId;

  @override
  String toString() => 'DepositNotActiveException(depositId: $depositId)';
}
