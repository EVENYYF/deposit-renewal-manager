import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/deposits/domain/deposit.dart' as domain;
import '../../../features/deposits/domain/deposit_repository.dart';
import '../../../features/deposits/domain/local_date.dart';
import '../../../features/customers/domain/customer_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../app_database.dart' as db;
import 'customer_dao.dart';

enum RenewalFailurePoint {
  afterSourceClose,
  afterTargetInsert,
  afterLinkInsert,
}

typedef RenewalFailureInjector =
    Future<void> Function(RenewalFailurePoint point);

final class DepositDao implements DepositRepository {
  DepositDao(
    this._db, {
    required this.sourceDeviceId,
    UtcNow? nowUtc,
    Uuid? uuid,
    this.failureInjector,
    this.notificationCoordinator,
    this.notificationWarning,
  }) : _nowUtc = nowUtc ?? clock.now,
       _uuid = uuid ?? const Uuid();

  final db.AppDatabase _db;
  final String sourceDeviceId;
  final UtcNow _nowUtc;
  final Uuid _uuid;
  final RenewalFailureInjector? failureInjector;
  final NotificationMutationCoordinator? notificationCoordinator;
  final void Function(String warning)? notificationWarning;

  @override
  Future<StoredDeposit> create(DepositDraft draft) async {
    _validateTerm(draft);
    final result = await _db.transaction(() async {
      await _requireActiveCustomer(draft.customerId);
      final timestamp = _timestamp();
      await _insertDraft(draft, timestamp);
      final revision = await _db.incrementBusinessRevision();
      final row = await _requireRow(draft.id);
      await _appendAudit('create', row.id, null, _rowJson(row), revision);
      return _toStored(row);
    });
    await _notify(
      () => notificationCoordinator?.afterCreateOrUpdate(result.deposit.id),
    );
    return result;
  }

  @override
  Future<StoredDeposit?> get(String id) async {
    final row = await (_db.select(
      _db.deposits,
    )..where((deposit) => deposit.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toStored(row);
  }

  @override
  Future<StoredDeposit> update(String id, DepositDraft draft) async {
    _validateTerm(draft);
    final result = await _db.transaction(() async {
      final before = await _requireRow(id);
      if (before.lifecycle != 'active') throw DepositNotActiveException(id);
      await _requireActiveCustomer(draft.customerId);
      await (_db.update(
        _db.deposits,
      )..where((deposit) => deposit.id.equals(id))).write(
        db.DepositsCompanion(
          customerId: Value(draft.customerId),
          amountCents: Value(draft.amountCents),
          bankName: Value(draft.bankName.trim()),
          productName: Value(draft.productName.trim()),
          termValue: Value(draft.termValue),
          termUnit: Value(draft.termUnit?.name),
          interestRateScaled: Value(draft.interestRateScaled),
          ratePrecision: Value(draft.ratePrecision),
          startDate: Value(draft.startDate.toString()),
          calculatedExpiryDate: Value(draft.calculatedExpiryDate?.toString()),
          finalExpiryDate: Value(draft.finalExpiryDate.toString()),
          updatedAtUtc: Value(_timestamp()),
          sourceDeviceId: Value(sourceDeviceId),
        ),
      );
      final after = await _requireRow(id);
      await _learnProduct(draft.productName, after.updatedAtUtc);
      final revision = await _db.incrementBusinessRevision();
      await _appendAudit(
        'update',
        id,
        _rowJson(before),
        _rowJson(after),
        revision,
      );
      return _toStored(after);
    });
    await _notify(() => notificationCoordinator?.afterCreateOrUpdate(id));
    return result;
  }

  @override
  Future<RenewalResult> renew(String sourceId, DepositDraft next) async {
    _validateTerm(next);
    final result = await _db.transaction(() async {
      final before = await _requireRow(sourceId);
      if (before.lifecycle != 'active') {
        throw DepositNotActiveException(sourceId);
      }
      if (next.id == sourceId) {
        throw ArgumentError.value(
          next.id,
          'next.id',
          'Must differ from source',
        );
      }
      if (next.customerId != before.customerId) {
        throw ArgumentError.value(
          next.customerId,
          'next.customerId',
          'Must match the source customer',
        );
      }
      await _requireActiveCustomer(before.customerId);

      final timestamp = _timestamp();
      await (_db.update(
        _db.deposits,
      )..where((deposit) => deposit.id.equals(sourceId))).write(
        db.DepositsCompanion(
          lifecycle: const Value('renewed'),
          updatedAtUtc: Value(timestamp),
          sourceDeviceId: Value(sourceDeviceId),
        ),
      );
      await _inject(RenewalFailurePoint.afterSourceClose);
      await _insertDraft(next, timestamp);
      await _inject(RenewalFailurePoint.afterTargetInsert);
      await _db
          .into(_db.renewals)
          .insert(
            db.RenewalsCompanion.insert(
              id: _uuid.v4(),
              sourceDepositId: sourceId,
              targetDepositId: next.id,
              renewedAtUtc: timestamp,
              sourceDeviceId: sourceDeviceId,
            ),
          );
      await _inject(RenewalFailurePoint.afterLinkInsert);

      final closedSource = await _requireRow(sourceId);
      final target = await _requireRow(next.id);
      final revision = await _db.incrementBusinessRevision();
      await _appendAudit(
        'renew',
        sourceId,
        _rowJson(before),
        _rowJson(closedSource),
        revision,
      );
      await _appendAudit(
        'create_from_renewal',
        target.id,
        null,
        _rowJson(target),
        revision,
      );
      return RenewalResult(newDepositId: next.id);
    });
    await _notify(
      () => notificationCoordinator?.afterRenew(sourceId, result.newDepositId),
    );
    return result;
  }

  @override
  Future<void> stopRenewal(String id) async {
    await _db.transaction(() async {
      final before = await _requireRow(id);
      if (before.lifecycle != 'active') throw DepositNotActiveException(id);
      await (_db.update(
        _db.deposits,
      )..where((deposit) => deposit.id.equals(id))).write(
        db.DepositsCompanion(
          lifecycle: const Value('stopped'),
          updatedAtUtc: Value(_timestamp()),
          sourceDeviceId: Value(sourceDeviceId),
        ),
      );
      final after = await _requireRow(id);
      final revision = await _db.incrementBusinessRevision();
      await _appendAudit(
        'stop',
        id,
        _rowJson(before),
        _rowJson(after),
        revision,
      );
    });
    await _notify(() => notificationCoordinator?.afterStopOrDelete(id));
  }

  @override
  Future<String?> renewalSourceOf(String targetDepositId) async {
    final row =
        await (_db.select(_db.renewals)..where(
              (renewal) => renewal.targetDepositId.equals(targetDepositId),
            ))
            .getSingleOrNull();
    return row?.sourceDepositId;
  }

  Future<void> _insertDraft(DepositDraft draft, int timestamp) async {
    if (draft.id.trim().isEmpty) {
      throw ArgumentError.value(draft.id, 'id', 'Must not be empty');
    }
    await _db
        .into(_db.deposits)
        .insert(
          db.DepositsCompanion.insert(
            id: draft.id,
            customerId: draft.customerId,
            amountCents: draft.amountCents,
            bankName: Value(draft.bankName.trim()),
            productName: Value(draft.productName.trim()),
            termValue: Value(draft.termValue),
            termUnit: Value(draft.termUnit?.name),
            interestRateScaled: draft.interestRateScaled,
            ratePrecision: draft.ratePrecision,
            startDate: draft.startDate.toString(),
            calculatedExpiryDate: Value(draft.calculatedExpiryDate?.toString()),
            finalExpiryDate: draft.finalExpiryDate.toString(),
            lifecycle: 'active',
            createdAtUtc: timestamp,
            updatedAtUtc: timestamp,
            sourceDeviceId: sourceDeviceId,
          ),
        );
    await _learnProduct(draft.productName, timestamp);
  }

  Future<db.Deposit> _requireRow(String id) async {
    final row = await (_db.select(
      _db.deposits,
    )..where((deposit) => deposit.id.equals(id))).getSingleOrNull();
    if (row == null) throw StateError('Deposit not found: $id');
    return row;
  }

  Future<void> _requireActiveCustomer(String id) async {
    final customer = await (_db.select(
      _db.customers,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (customer == null) throw StateError('Customer not found: $id');
    if (!customer.isActive) throw CustomerInactiveException(id);
  }

  StoredDeposit _toStored(db.Deposit row) {
    final lifecycle = domain.DepositLifecycle.values.byName(row.lifecycle);
    final calculated = _parseDateOrNull(row.calculatedExpiryDate);
    final finalExpiry = _parseDate(row.finalExpiryDate);
    final entity = calculated == null
        ? domain.Deposit.direct(
            id: row.id,
            expiryDate: finalExpiry,
            lifecycle: lifecycle,
          )
        : domain.Deposit.automatic(
            id: row.id,
            calculatedExpiryDate: calculated,
            finalExpiryDate: finalExpiry,
            lifecycle: lifecycle,
          );
    return StoredDeposit(
      deposit: entity,
      customerId: row.customerId,
      amountCents: row.amountCents,
      bankName: row.bankName,
      productName: row.productName,
      termValue: row.termValue,
      termUnit: row.termUnit == null
          ? null
          : DepositTermUnit.values.byName(row.termUnit!),
      interestRateScaled: row.interestRateScaled,
      ratePrecision: row.ratePrecision,
      startDate: _parseDate(row.startDate),
    );
  }

  String _rowJson(db.Deposit row) => jsonEncode({
    'id': row.id,
    'customerId': row.customerId,
    'amountCents': row.amountCents,
    'bankName': row.bankName,
    'productName': row.productName,
    'termValue': row.termValue,
    'termUnit': row.termUnit,
    'interestRateScaled': row.interestRateScaled,
    'ratePrecision': row.ratePrecision,
    'startDate': row.startDate,
    'calculatedExpiryDate': row.calculatedExpiryDate,
    'finalExpiryDate': row.finalExpiryDate,
    'lifecycle': row.lifecycle,
  });

  Future<void> _appendAudit(
    String operation,
    String entityId,
    String? beforeJson,
    String? afterJson,
    int revision,
  ) {
    return _db
        .into(_db.auditHistory)
        .insert(
          db.AuditHistoryCompanion.insert(
            id: _uuid.v4(),
            entityType: 'deposit',
            entityId: entityId,
            operation: operation,
            beforeJson: Value(beforeJson),
            afterJson: Value(afterJson),
            occurredAtUtc: _timestamp(),
            sourceDeviceId: sourceDeviceId,
            businessRevision: revision,
          ),
        );
  }

  Future<void> _inject(RenewalFailurePoint point) async {
    await failureInjector?.call(point);
  }

  Future<void> _notify(Future<void>? Function() action) async {
    try {
      await action();
    } catch (error) {
      notificationWarning?.call('业务已保存，但通知更新失败：$error');
    }
  }

  LocalDate _parseDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) throw FormatException('Invalid ISO date', value);
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  LocalDate? _parseDateOrNull(String? value) =>
      value == null ? null : _parseDate(value);

  int _timestamp() => _nowUtc().toUtc().microsecondsSinceEpoch;

  void _validateTerm(DepositDraft draft) {
    if ((draft.termValue == null) != (draft.termUnit == null)) {
      throw ArgumentError('termValue and termUnit must both be set or null');
    }
    if (draft.termValue != null && draft.termValue! <= 0) {
      throw ArgumentError.value(
        draft.termValue,
        'termValue',
        'Must be positive',
      );
    }
  }

  Future<void> _learnProduct(String productName, int timestamp) async {
    final value = productName.trim();
    if (value.isEmpty) return;
    await _db.customStatement(
      'INSERT OR IGNORE INTO deposit_presets '
      '(id, field_type, value, created_at_utc) VALUES (?, ?, ?, ?)',
      [_uuid.v4(), 'product', value, timestamp],
    );
  }
}
