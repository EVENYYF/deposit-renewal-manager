import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/customers/domain/customer_repository.dart';
import '../../../features/customers/domain/name_search_index.dart';
import '../../../features/deposits/domain/deposit.dart';
import '../../../features/deposits/domain/local_date.dart';
import '../app_database.dart' as db;

typedef UtcNow = DateTime Function();

final class CustomerDao implements CustomerRepository {
  CustomerDao(
    this._db, {
    required this.sourceDeviceId,
    UtcNow? nowUtc,
    Uuid? uuid,
  }) : _nowUtc = nowUtc ?? clock.now,
       _uuid = uuid ?? const Uuid();

  final db.AppDatabase _db;
  final String sourceDeviceId;
  final UtcNow _nowUtc;
  final Uuid _uuid;

  @override
  Future<CustomerRecord> create(CustomerDraft draft) =>
      _db.transaction(() async {
        final normalized = _normalizeDraft(draft);
        final searchIndex = buildNameIndex(normalized.name);
        final timestamp = _timestamp();
        await _db
            .into(_db.customers)
            .insert(
              db.CustomersCompanion.insert(
                id: normalized.id,
                name: normalized.name,
                phone: Value(normalized.phone),
                normalizedName: Value(searchIndex.normalizedName),
                fullPinyin: Value(searchIndex.fullPinyin),
                initials: Value(searchIndex.initials),
                normalizedPhone: Value(normalizePhone(normalized.phone ?? '')),
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
        final searchIndex = buildNameIndex(normalized.name);
        await (_db.update(
          _db.customers,
        )..where((customer) => customer.id.equals(id))).write(
          db.CustomersCompanion(
            name: Value(normalized.name),
            phone: Value(normalized.phone),
            normalizedName: Value(searchIndex.normalizedName),
            fullPinyin: Value(searchIndex.fullPinyin),
            initials: Value(searchIndex.initials),
            normalizedPhone: Value(normalizePhone(normalized.phone ?? '')),
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

  @override
  Future<List<CustomerSearchResult>> search(CustomerQuery query) async {
    final statement = _buildSearchStatement(query);
    final rows = await _db
        .customSelect(
          statement.sql,
          variables: statement.variables,
          readsFrom: {_db.customers, _db.deposits},
        )
        .get();

    final results = <String, CustomerSearchResult>{};
    for (final row in rows) {
      final customerId = row.read<String>('customer_id');
      final existing = results.putIfAbsent(
        customerId,
        () => CustomerSearchResult(
          customer: CustomerRecord(
            id: customerId,
            name: row.read<String>('customer_name'),
            phone: row.readNullable<String>('customer_phone'),
            isActive: row.read<bool>('customer_is_active'),
          ),
          deposits: const [],
        ),
      );
      final depositId = row.readNullable<String>('deposit_id');
      if (depositId != null) {
        results[customerId] = CustomerSearchResult(
          customer: existing.customer,
          deposits: [
            ...existing.deposits,
            CustomerSearchDeposit(
              id: depositId,
              bankName: row.read<String>('deposit_bank_name'),
              finalExpiryDate: _parseDate(
                row.read<String>('deposit_final_expiry_date'),
              ),
              lifecycle: DepositLifecycle.values.byName(
                row.read<String>('deposit_lifecycle'),
              ),
            ),
          ],
        );
      }
    }
    return List.unmodifiable(results.values);
  }

  Future<List<QueryRow>> explainSearchPlan(CustomerQuery query) {
    final statement = _buildSearchStatement(query);
    return _db
        .customSelect(
          'EXPLAIN QUERY PLAN ${statement.sql}',
          variables: statement.variables,
        )
        .get();
  }

  _SearchStatement _buildSearchStatement(CustomerQuery query) {
    final normalizedText = normalizeSearchText(query.text);
    final escapedText = _escapeLike(normalizedText);
    final exact = normalizedText;
    final prefix = '$escapedText%';
    final contains = '%$escapedText%';
    final variables = <Variable<Object>>[];
    final where = <String>[];

    if (normalizedText.isNotEmpty) {
      variables.addAll(List.generate(4, (_) => Variable.withString(prefix)));
      variables.addAll(List.generate(4, (_) => Variable.withString(contains)));
      variables.addAll(List.generate(4, (_) => Variable.withString(exact)));
      variables.addAll(List.generate(4, (_) => Variable.withString(prefix)));
      where.add('c.id IN (SELECT id FROM search_candidates)');
    }
    if (query.bank != null) {
      where.add('d.bank_name = ?');
      variables.add(Variable.withString(query.bank!.trim()));
    }
    if (query.expiryFrom != null) {
      where.add('d.final_expiry_date >= ?');
      variables.add(Variable.withString(query.expiryFrom.toString()));
    }
    if (query.expiryTo != null) {
      where.add('d.final_expiry_date <= ?');
      variables.add(Variable.withString(query.expiryTo.toString()));
    }
    if (query.lifecycle != null) {
      where.add('d.lifecycle = ?');
      variables.add(Variable.withString(query.lifecycle!.name));
    }
    if (query.overdueOnly) {
      where.add("d.lifecycle = 'active'");
      where.add('d.final_expiry_date < ?');
      variables.add(Variable.withString(query.today.toString()));
    }

    final rankSql = normalizedText.isEmpty
        ? '0'
        : '''
CASE
  WHEN c.normalized_name = ? OR c.full_pinyin = ?
    OR c.initials = ? OR c.normalized_phone = ? THEN 0
  WHEN c.normalized_name LIKE ? ESCAPE '!'
    OR c.full_pinyin LIKE ? ESCAPE '!'
    OR c.initials LIKE ? ESCAPE '!'
    OR c.normalized_phone LIKE ? ESCAPE '!' THEN 1
  ELSE 2
END
''';
    final join = query.hasDepositFilters ? 'JOIN' : 'LEFT JOIN';
    final candidateCte = normalizedText.isEmpty
        ? ''
        : '''
WITH search_candidates AS (
  SELECT id FROM customers
  WHERE normalized_name LIKE ? ESCAPE '!'
     OR full_pinyin LIKE ? ESCAPE '!'
     OR initials LIKE ? ESCAPE '!'
     OR normalized_phone LIKE ? ESCAPE '!'
  UNION
  SELECT id FROM customers
  WHERE normalized_name LIKE ? ESCAPE '!'
     OR full_pinyin LIKE ? ESCAPE '!'
     OR initials LIKE ? ESCAPE '!'
     OR normalized_phone LIKE ? ESCAPE '!'
)
''';
    return _SearchStatement('''
$candidateCte
SELECT
  c.id AS customer_id,
  c.name AS customer_name,
  c.phone AS customer_phone,
  c.is_active AS customer_is_active,
  d.id AS deposit_id,
  d.bank_name AS deposit_bank_name,
  d.final_expiry_date AS deposit_final_expiry_date,
  d.lifecycle AS deposit_lifecycle,
  $rankSql AS search_rank
FROM customers c
$join deposits d ON d.customer_id = c.id
${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
ORDER BY search_rank, c.rowid, d.rowid
''', variables);
  }

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

  int _timestamp() => _nowUtc().toUtc().microsecondsSinceEpoch;

  String _escapeLike(String value) =>
      value.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_');

  LocalDate _parseDate(String value) {
    final parts = value.split('-');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

final class _SearchStatement {
  const _SearchStatement(this.sql, this.variables);

  final String sql;
  final List<Variable<Object>> variables;
}
