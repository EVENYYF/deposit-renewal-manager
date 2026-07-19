import 'local_date.dart';

enum DepositLifecycle { active, renewed, stopped }

final class Deposit {
  Deposit.automatic({
    required this.id,
    required LocalDate calculatedExpiryDate,
    LocalDate? finalExpiryDate,
    this.lifecycle = DepositLifecycle.active,
  }) : calculatedExpiryDate = calculatedExpiryDate,
       finalExpiryDate = finalExpiryDate ?? calculatedExpiryDate;

  Deposit.direct({
    required this.id,
    required LocalDate expiryDate,
    this.lifecycle = DepositLifecycle.active,
  }) : calculatedExpiryDate = null,
       finalExpiryDate = expiryDate;

  final String id;
  final LocalDate? calculatedExpiryDate;
  final LocalDate finalExpiryDate;
  final DepositLifecycle lifecycle;

  LocalDate get effectiveExpiryDate => finalExpiryDate;

  bool get isExpiryAdjusted =>
      calculatedExpiryDate != null && calculatedExpiryDate != finalExpiryDate;

  bool isOverdueOn(LocalDate today) =>
      lifecycle == DepositLifecycle.active && finalExpiryDate.isBefore(today);
}
