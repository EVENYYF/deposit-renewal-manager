import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/deposits/domain/deposit_preset_repository.dart';
import '../app_database.dart' hide DepositPreset;

typedef PresetUtcNow = DateTime Function();

final class DepositPresetDao implements DepositPresetRepository {
  DepositPresetDao(this._db, {PresetUtcNow? nowUtc, Uuid? uuid})
    : _nowUtc = nowUtc ?? clock.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final PresetUtcNow _nowUtc;
  final Uuid _uuid;

  @override
  Future<List<DepositPreset>> list(DepositPresetField field) async {
    final rows =
        await (_db.select(_db.depositPresets)
              ..where((row) => row.fieldType.equals(field.name))
              ..orderBy([
                (row) => OrderingTerm.desc(row.createdAtUtc),
                (row) => OrderingTerm.asc(row.value),
              ]))
            .get();
    return rows
        .map(
          (row) => DepositPreset(
            id: row.id,
            field: DepositPresetField.values.byName(row.fieldType),
            value: row.value,
            createdAtUtc: DateTime.fromMicrosecondsSinceEpoch(
              row.createdAtUtc,
              isUtc: true,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<DepositPreset> add(DepositPresetField field, String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Must not be empty');
    }
    final timestamp = _nowUtc().toUtc().microsecondsSinceEpoch;
    await _db
        .into(_db.depositPresets)
        .insert(
          DepositPresetsCompanion.insert(
            id: _uuid.v4(),
            fieldType: field.name,
            value: normalized,
            createdAtUtc: timestamp,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final row =
        await (_db.select(_db.depositPresets)..where(
              (row) =>
                  row.fieldType.equals(field.name) &
                  row.value.equals(normalized),
            ))
            .getSingle();
    return DepositPreset(
      id: row.id,
      field: field,
      value: row.value,
      createdAtUtc: DateTime.fromMicrosecondsSinceEpoch(
        row.createdAtUtc,
        isUtc: true,
      ),
    );
  }
}
