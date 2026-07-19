import '../domain/deposit_preset_repository.dart';

final class DepositPresetService {
  const DepositPresetService(this._repository);

  final DepositPresetRepository _repository;

  Future<List<String>> candidates(DepositPresetField field) async =>
      (await _repository.list(field)).map((preset) => preset.value).toList();

  Future<void> addCandidate(DepositPresetField field, String value) async {
    await _repository.add(field, value);
  }
}
