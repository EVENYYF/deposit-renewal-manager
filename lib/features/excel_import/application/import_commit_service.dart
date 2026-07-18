import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../features/customers/domain/name_search_index.dart';
import '../domain/import_models.dart';

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

  Future<ImportResult> commit({
    required String fileName,
    required List<int> fileBytes,
    required ImportPreview preview,
    Map<int, DuplicateDecision> decisions = const {},
    Map<int, Map<String, bool>> fieldChoices = const {},
  }) async {
    final snapshot = await createSnapshot();
    final batchId = _uuid.v4();
    final hash = sha256.convert(fileBytes).toString();
    final affected = <String>[];
    var imported = 0, skipped = 0, failed = 0;
    try {
      final result = await database.transaction(() async {
        for (final row in preview.rows) {
          if (!row.isValid) {
            failed++;
            continue;
          }
          final n = row.normalized;
          final phone = n['phone']?.toString() ?? '';
          final normalizedPhone = normalizePhone(phone);
          final existing =
              await (database.select(database.customers)
                    ..where((c) => c.normalizedPhone.equals(normalizedPhone))
                    ..limit(1))
                  .getSingleOrNull();
          final decision =
              decisions[row.rowNumber] ??
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
            final choices =
                fieldChoices[row.rowNumber] ?? const <String, bool>{};
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
                  interestRateScaled: (n['interestRate'] as num).round(),
                  ratePrecision: 2,
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
      await notificationReconcile?.call(result);
      return result;
    } catch (_) {
      rethrow;
    }
  }
}
