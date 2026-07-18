import '../../../core/database/app_database.dart';
import '../domain/import_models.dart';

class DuplicateResolver {
  const DuplicateResolver(this.database);
  final AppDatabase database;

  Future<List<DuplicateCandidate>> resolve(ImportPreview preview) async {
    final candidates = <DuplicateCandidate>[];
    for (final row in preview.validRows) {
      final phone =
          row.normalized['normalizedPhone']?.toString() ??
          row.normalized['phone']?.toString() ??
          '';
      if (phone.isEmpty) continue;
      final existing =
          await (database.select(database.customers)
                ..where((c) => c.normalizedPhone.equals(phone))
                ..limit(1))
              .getSingleOrNull();
      if (existing == null) continue;
      row.availableDecisions
        ..clear()
        ..addAll(DuplicateDecision.values);
      final conflicts = <String, ({Object? oldValue, Object? newValue})>{};
      final newName = row.normalized['name'];
      final newPhone = row.normalized['phone'];
      if (newName != null && newName.toString() != existing.name) {
        conflicts['name'] = (oldValue: existing.name, newValue: newName);
      }
      if (newPhone != null && newPhone.toString() != (existing.phone ?? '')) {
        conflicts['phone'] = (oldValue: existing.phone, newValue: newPhone);
      }
      candidates.add(
        DuplicateCandidate(
          row: row,
          existingCustomerId: existing.id,
          fieldConflicts: conflicts,
        ),
      );
    }
    return candidates;
  }
}
