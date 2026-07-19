enum DepositPresetField { amount, bank, rate, term, product }

final class DepositPreset {
  const DepositPreset({
    required this.id,
    required this.field,
    required this.value,
    required this.createdAtUtc,
  });

  final String id;
  final DepositPresetField field;
  final String value;
  final DateTime createdAtUtc;
}

abstract interface class DepositPresetRepository {
  Future<List<DepositPreset>> list(DepositPresetField field);

  Future<DepositPreset> add(DepositPresetField field, String value);
}
