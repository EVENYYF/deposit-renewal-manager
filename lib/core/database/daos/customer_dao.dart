import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/customers/domain/customer_repository.dart';
import '../app_database.dart' as db;

typedef UtcNow = DateTime Function();

final class CustomerDao implements CustomerRepository {
  CustomerDao(
    this._db, {
    required this.sourceDeviceId,
    UtcNow? nowUtc,
    Uuid? uuid,
  }) : _nowUtc = nowUtc ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final db.AppDatabase _db;
  final String sourceDeviceId;
  final UtcNow _nowUtc;
  final Uuid _uuid;

  @override
  Future<CustomerRecord> create(CustomerDraft draft) =>
      _db.transaction(() async {
        final normalized = _normalizeDraft(draft);
        final timestamp = _timestamp();
        await _db
            .into(_db.customers)
            .insert(
              db.CustomersCompanion.insert(
                id: normalized.id,
                name: normalized.name,
                phone: Value(normalized.phone),
                createdAtUtc: timestamp,
                updatedAtUtc: timestamp,
              ),
            );
        final revision = await _db.incrementBusinessRevision();
        final created = CustomerRecord(
          id: normalized.id,
          name: normalized.name,
          phone: normalized.phone,
          isActive: true,
        );
        await _appendAudit(
          'create',
          created.id,
          null,
          _toJson(created),
          revision,
        );
        return created;
      });

  @override
  Future<CustomerRecord?> get(String id) async {
    final row = await (_db.select(
      _db.customers,
    )..where((customer) => customer.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  @override
  Future<CustomerRecord> update(String id, CustomerDraft draft) =>
      _db.transaction(() async {
        final existing = await _requireCustomer(id);
        final normalized = _normalizeDraft(draft);
        await (_db.update(
          _db.customers,
        )..where((customer) => customer.id.equals(id))).write(
          db.CustomersCompanion(
            name: Value(normalized.name),
            phone: Value(normalized.phone),
            updatedAtUtc: Value(_timestamp()),
          ),
        );
        final updated = CustomerRecord(
          id: id,
          name: normalized.name,
          phone: normalized.phone,
          isActive: existing.isActive,
        );
        final revision = await _db.incrementBusinessRevision();
        await _appendAudit(
          'update',
          id,
          _toJson(existing),
          _toJson(updated),
          revision,
        );
        return updated;
      });

  @override
  Future<void> deactivate(String id) => _db.transaction(() async {
    final existing = await _requireCustomer(id);
    if (!existing.isActive) return;
    final activeDeposit =
        await (_db.select(_db.deposits)
              ..where(
                (deposit) =>
                    deposit.customerId.equals(id) &
                    deposit.lifecycle.equals('active'),
              )
              ..limit(1))
            .getSingleOrNull();
    if (activeDeposit != null) {
      throw CustomerHasActiveDepositsException(id);
    }
    await (_db.update(
      _db.customers,
    )..where((customer) => customer.id.equals(id))).write(
      db.CustomersCompanion(
        isActive: const Value(false),
        updatedAtUtc: Value(_timestamp()),
      ),
    );
    final updated = CustomerRecord(
      id: existing.id,
      name: existing.name,
      phone: existing.phone,
      isActive: false,
    );
    final revision = await _db.incrementBusinessRevision();
    await _appendAudit(
      'deactivate',
      id,
      _toJson(existing),
      _toJson(updated),
      revision,
    );
  });

  Future<CustomerRecord> _requireCustomer(String id) async {
    final customer = await get(id);
    if (customer == null) throw StateError('Customer not found: $id');
    return customer;
  }

  CustomerDraft _normalizeDraft(CustomerDraft draft) {
    final id = draft.id.trim();
    final name = draft.name.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(draft.id, 'id', 'Must not be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError.value(draft.name, 'name', 'Must not be empty');
    }
    final phone = draft.phone?.trim();
    return CustomerDraft(
      id: id,
      name: name,
      phone: phone == null || phone.isEmpty ? null : phone,
    );
  }

  CustomerRecord _toRecord(db.Customer row) => CustomerRecord(
    id: row.id,
    name: row.name,
    phone: row.phone,
    isActive: row.isActive,
  );

  String _toJson(CustomerRecord record) => jsonEncode({
    'id': record.id,
    'name': record.name,
    'phone': record.phone,
    'isActive': record.isActive,
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
            entityType: 'customer',
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

  String _timestamp() => _nowUtc().toUtc().toIso8601String();
}
