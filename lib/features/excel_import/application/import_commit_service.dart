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
    final hash = sha256.convert(fileBytes).toString();
    final duplicateHash =
        await (database.select(database.importBatches)
              ..where((b) => b.contentHash.equals(hash))
              ..limit(1))
            .getSingleOrNull();
    if (duplicateHash != null) {
      throw StateError('duplicate import contentHash');
    }
    final snapshot = await createSnapshot();
    final batchId = _uuid.v4();
    final affected = <String>[];
    var imported = 0, skipped = 0, failed = 0;
    final warnings = <String>[];
    final result = await database.transaction(() async {
      final duplicateInTransaction =
          await (database.select(database.importBatches)
                ..where((b) => b.contentHash.equals(hash))
                ..limit(1))
              .getSingleOrNull();
      if (duplicateInTransaction != null) {
        throw StateError('duplicate import contentHash');
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
        final decision =
            suppliedDecision ??
            (existing == null
                ? DuplicateDecision.createSeparate
                : DuplicateDecision.attachToExisting);
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
        final date = parseImportDate(start)!;
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
}
