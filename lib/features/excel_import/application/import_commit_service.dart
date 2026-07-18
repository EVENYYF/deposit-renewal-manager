import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../features/customers/domain/name_search_index.dart';
import '../domain/import_models.dart';
import 'duplicate_resolver.dart';

typedef ImportSnapshot = Future<File> Function();
typedef NotificationReconcileHook = Future<void> Function(ImportResult result);

class ImportCommitService {
  ImportCommitService({
    required this.database,
    required this.sourceDeviceId,
    required this.createSnapshot,
    this.notificationReconcile,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();
  final AppDatabase database;
  final String sourceDeviceId;
  final ImportSnapshot createSnapshot;
  final NotificationReconcileHook? notificationReconcile;
  final Uuid _uuid;

  Future<List<DuplicateCandidate>> resolveDuplicates(ImportPreview preview) =>
      DuplicateResolver(database).resolve(preview);

  Future<ImportResult> commit({
    required String fileName,
    required List<int> fileBytes,
    required ImportPreview preview,
    Map<int, DuplicateDecision> decisions = const {},
    Map<int, Map<String, bool>> fieldChoices = const {},
  }) async {
    _validateDecisionInputs(preview, decisions, fieldChoices);
    final hash = sha256.convert(fileBytes).toString();
    final duplicateHash =
        await (database.select(database.importBatches)
              ..where((b) => b.contentHash.equals(hash))
              ..limit(1))
            .getSingleOrNull();
    if (duplicateHash != null) {
      throw const DuplicateImportException(
        'This spreadsheet content has already been imported',
      );
    }
    final snapshot = await createSnapshot();
    final batchId = _uuid.v4();
    final affected = <String>[];
    var imported = 0, skipped = 0, failed = 0;
    final warnings = <String>[];
    late final ImportResult result;
    try {
      result = await database.transaction(() async {
        final duplicateInTransaction =
            await (database.select(database.importBatches)
                  ..where((b) => b.contentHash.equals(hash))
                  ..limit(1))
                .getSingleOrNull();
        if (duplicateInTransaction != null) {
          throw const DuplicateImportException(
            'This spreadsheet content has already been imported',
          );
        }
        for (final row in preview.rows) {
          if (!row.isValid) {
            failed++;
            continue;
          }
          final n = row.normalized;
          final phone = n['phone']?.toString() ?? '';
          final normalizedPhone = normalizePhone(phone);
          if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(normalizedPhone)) {
            failed++;
            continue;
          }
          final existing =
              await (database.select(database.customers)
                    ..where((c) => c.normalizedPhone.equals(normalizedPhone))
                    ..limit(1))
                  .getSingleOrNull();
          final candidate = _candidateFor(preview, row.rowNumber);
          if (candidate == null && existing != null) {
            throw StateError(
              'duplicate candidate is missing for row ${row.rowNumber}',
            );
          }
          if (candidate != null &&
              existing?.id != candidate.existingCustomerId) {
            throw StateError(
              'duplicate preview is stale for row ${row.rowNumber}',
            );
          }
          final suppliedDecision = decisions[row.rowNumber];
          if (suppliedDecision == DuplicateDecision.attachToExisting &&
              existing == null) {
            throw StateError('attachToExisting requires an existing customer');
          }
          if (suppliedDecision == DuplicateDecision.skip && existing == null) {
            throw StateError('skip is only valid for duplicate rows');
          }
          final choices = fieldChoices[row.rowNumber] ?? const <String, bool>{};
          for (final key in choices.keys) {
            if (!{'name', 'phone'}.contains(key)) {
              throw StateError('unknown field choice: $key');
            }
            if (existing == null || !<String>{'name', 'phone'}.contains(key)) {
              throw StateError('field choice requires duplicate conflict');
            }
            final oldValue = key == 'name'
                ? existing.name
                : (existing.phone ?? '');
            final newValue = n[key]?.toString() ?? '';
            if (oldValue == newValue) {
              throw StateError('field choice has no conflict: $key');
            }
          }
          final decision = suppliedDecision ?? DuplicateDecision.createSeparate;
          if (decision == DuplicateDecision.skip) {
            skipped++;
            continue;
          }
          String customerId;
          if (existing != null &&
              decision == DuplicateDecision.attachToExisting) {
            customerId = existing.id;
            if (choices['name'] == true || choices['phone'] == true) {
              final name = choices['name'] == true
                  ? n['name'].toString()
                  : existing.name;
              final updatedPhone = choices['phone'] == true
                  ? n['phone']?.toString()
                  : existing.phone;
              final idx = buildNameIndex(name);
              await (database.update(
                database.customers,
              )..where((c) => c.id.equals(customerId))).write(
                CustomersCompanion(
                  name: Value(name),
                  phone: Value(updatedPhone),
                  normalizedName: Value(idx.normalizedName),
                  fullPinyin: Value(idx.fullPinyin),
                  initials: Value(idx.initials),
                  normalizedPhone: Value(normalizePhone(updatedPhone ?? '')),
                  updatedAtUtc: Value(
                    DateTime.now().toUtc().millisecondsSinceEpoch,
                  ),
                ),
              );
            }
          } else {
            customerId = _uuid.v4();
            final name = n['name'].toString();
            final idx = buildNameIndex(name);
            final now = DateTime.now().toUtc().millisecondsSinceEpoch;
            await database
                .into(database.customers)
                .insert(
                  CustomersCompanion.insert(
                    id: customerId,
                    name: name,
                    phone: Value(phone),
                    normalizedName: Value(idx.normalizedName),
                    fullPinyin: Value(idx.fullPinyin),
                    initials: Value(idx.initials),
                    normalizedPhone: Value(normalizedPhone),
                    createdAtUtc: now,
                    updatedAtUtc: now,
                  ),
                );
          }
          final start = n['startDate'].toString();
          final term = n['term'] as int;
          final date = parseImportDate(start, dateSystem: preview.dateSystem);
          if (date == null) {
            throw StateError('invalid start date in row ${row.rowNumber}');
          }
          final expiry = date.addMonthsClamped(term);
          final amount = n['amountCents'] as int;
          final now = DateTime.now().toUtc().millisecondsSinceEpoch;
          await database
              .into(database.deposits)
              .insert(
                DepositsCompanion.insert(
                  id: _uuid.v4(),
                  customerId: customerId,
                  amountCents: amount,
                  bankName: Value(n['bankName']?.toString() ?? ''),
                  interestRateScaled: _requiredInt(n, 'interestRateScaled'),
                  ratePrecision: _requiredInt(n, 'ratePrecision'),
                  startDate: start,
                  calculatedExpiryDate: Value(expiry.toString()),
                  finalExpiryDate: expiry.toString(),
                  lifecycle: 'active',
                  createdAtUtc: now,
                  updatedAtUtc: now,
                  sourceDeviceId: sourceDeviceId,
                ),
              );
          affected.add(customerId);
          imported++;
        }
        final revision = await database.incrementBusinessRevision();
        await database
            .into(database.importBatches)
            .insert(
              ImportBatchesCompanion.insert(
                id: batchId,
                fileName: fileName,
                contentHash: hash,
                importedRows: Value(imported),
                rejectedRows: Value(failed + skipped),
                importedAtUtc: DateTime.now().toUtc().millisecondsSinceEpoch,
                sourceDeviceId: sourceDeviceId,
              ),
            );
        await database
            .into(database.auditHistory)
            .insert(
              AuditHistoryCompanion.insert(
                id: _uuid.v4(),
                entityType: 'import_batch',
                entityId: batchId,
                operation: 'excel-import',
                afterJson: Value(
                  jsonEncode({
                    'contentHash': hash,
                    'preSnapshotId': snapshot.path,
                    'completedRevision': revision,
                    'affectedCustomerIds': affected,
                  }),
                ),
                occurredAtUtc: DateTime.now().toUtc().millisecondsSinceEpoch,
                sourceDeviceId: sourceDeviceId,
                businessRevision: revision,
              ),
            );
        return ImportResult(
          batchId: batchId,
          importedRows: imported,
          skippedRows: skipped,
          failedRows: failed,
          affectedCustomerIds: affected,
          completedBusinessRevision: revision,
          preSnapshotId: snapshot.path,
        );
      });
    } on DuplicateImportException {
      rethrow;
    } catch (error) {
      if (error.toString().contains(
        'UNIQUE constraint failed: import_batches.content_hash',
      )) {
        throw const DuplicateImportException(
          'This spreadsheet content has already been imported',
        );
      }
      rethrow;
    }
    try {
      await notificationReconcile?.call(result);
    } catch (e) {
      warnings.add('notification reconcile failed: $e');
    }
    return ImportResult(
      batchId: result.batchId,
      importedRows: result.importedRows,
      skippedRows: result.skippedRows,
      failedRows: result.failedRows,
      affectedCustomerIds: result.affectedCustomerIds,
      completedBusinessRevision: result.completedBusinessRevision,
      preSnapshotId: result.preSnapshotId,
      warnings: warnings,
    );
  }

  int _requiredInt(Map<String, Object?> values, String key) {
    final value = values[key];
    if (value is! int || value < 0) {
      throw StateError('invalid normalized $key');
    }
    return value;
  }

  void _validateDecisionInputs(
    ImportPreview preview,
    Map<int, DuplicateDecision> decisions,
    Map<int, Map<String, bool>> fieldChoices,
  ) {
    if (!preview.duplicatesResolved) {
      throw StateError('duplicate resolution is required before commit');
    }
    final rowsByNumber = {for (final row in preview.rows) row.rowNumber: row};
    for (final rowNumber in {...decisions.keys, ...fieldChoices.keys}) {
      if (!rowsByNumber.containsKey(rowNumber)) {
        throw StateError('unknown import row: $rowNumber');
      }
    }
    for (final row in preview.rows) {
      final decision = decisions[row.rowNumber];
      final hasChoices = fieldChoices.containsKey(row.rowNumber);
      final candidate = _candidateFor(preview, row.rowNumber);
      if (!row.isValid) {
        if (decision != null || hasChoices) {
          throw StateError(
            'invalid row cannot have a decision: ${row.rowNumber}',
          );
        }
        continue;
      }
      if (candidate == null) {
        if (decision != null && decision != DuplicateDecision.createSeparate) {
          throw StateError('nonduplicate row only supports createSeparate');
        }
        if (hasChoices) {
          throw StateError('nonduplicate row cannot have field choices');
        }
        continue;
      }
      if (decision == null) {
        throw StateError('duplicate row requires an explicit decision');
      }
      if (decision != DuplicateDecision.attachToExisting && hasChoices) {
        throw StateError('field choices are only valid for attachToExisting');
      }
      if (decision == DuplicateDecision.attachToExisting && hasChoices) {
        final conflicts = candidate.fieldConflicts.keys.toSet();
        for (final key in fieldChoices[row.rowNumber]!.keys) {
          if (!conflicts.contains(key)) {
            throw StateError('field choice is not an actual conflict: $key');
          }
        }
      }
    }
  }

  DuplicateCandidate? _candidateFor(ImportPreview preview, int rowNumber) {
    for (final candidate in preview.candidates) {
      if (candidate.row.rowNumber == rowNumber) return candidate;
    }
    return null;
  }
}
