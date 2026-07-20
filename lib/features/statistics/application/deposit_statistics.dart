import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

enum DepositStatisticsDimension { bank, product }

enum DepositStatisticsDetailKind {
  active,
  overdue,
  renewed,
  stopped,
  bank,
  product,
}

final class DepositStatisticsDetail {
  const DepositStatisticsDetail({
    required this.depositId,
    required this.customerName,
    this.customerPhone,
    required this.bankName,
    required this.productName,
    required this.amountCents,
    required this.interestRateScaled,
    required this.ratePrecision,
    required this.expiryDate,
    this.startDate,
    this.lifecycle = 'active',
  });

  final String depositId;
  final String customerName;
  final String? customerPhone;
  final String bankName;
  final String productName;
  final int amountCents;
  final int interestRateScaled;
  final int ratePrecision;
  final String expiryDate;
  final String? startDate;
  final String lifecycle;
}

final class DepositStatisticsDetailQuery {
  const DepositStatisticsDetailQuery(this.dimension, this.value, {this.kind});

  final DepositStatisticsDimension dimension;
  final String value;
  final DepositStatisticsDetailKind? kind;

  @override
  bool operator ==(Object other) =>
      other is DepositStatisticsDetailQuery &&
      other.dimension == dimension &&
      other.value == value &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(dimension, value, kind);
}

final class DepositStatisticsSnapshot {
  const DepositStatisticsSnapshot({
    this.totalCount = 0,
    this.activeCount = 0,
    this.overdueCount = 0,
    this.renewedCount = 0,
    this.stoppedCount = 0,
    this.currentPrincipalCents = 0,
    this.customerCount = 0,
    this.renewalCount = 0,
    this.byBank = const [],
    this.byProduct = const [],
  });

  final int totalCount;
  final int activeCount;
  final int overdueCount;
  final int renewedCount;
  final int stoppedCount;
  final int currentPrincipalCents;
  final int customerCount;
  final int renewalCount;
  final List<DepositStatisticsBreakdown> byBank;
  final List<DepositStatisticsBreakdown> byProduct;
}

final class DepositStatisticsBreakdown {
  const DepositStatisticsBreakdown({
    required this.name,
    required this.amountCents,
    required this.depositCount,
    required this.customerCount,
  });

  final String name;
  final int amountCents;
  final int depositCount;
  final int customerCount;
}

abstract interface class DepositStatisticsUseCases {
  Future<DepositStatisticsSnapshot> load({DateTime? now});

  Future<List<DepositStatisticsDetail>> loadDetails(
    DepositStatisticsDetailQuery query,
  );
}

final class EmptyDepositStatisticsUseCases
    implements DepositStatisticsUseCases {
  const EmptyDepositStatisticsUseCases();

  @override
  Future<DepositStatisticsSnapshot> load({DateTime? now}) async =>
      const DepositStatisticsSnapshot();

  @override
  Future<List<DepositStatisticsDetail>> loadDetails(
    DepositStatisticsDetailQuery query,
  ) async => const [];
}

final depositStatisticsUseCasesProvider = Provider<DepositStatisticsUseCases>(
  (ref) => const EmptyDepositStatisticsUseCases(),
);

final depositStatisticsControllerProvider =
    FutureProvider.autoDispose<DepositStatisticsSnapshot>((ref) {
      return ref.read(depositStatisticsUseCasesProvider).load();
    });

final depositStatisticsDetailProvider = FutureProvider.autoDispose
    .family<List<DepositStatisticsDetail>, DepositStatisticsDetailQuery>((
      ref,
      query,
    ) {
      final useCases = ref.read(depositStatisticsUseCasesProvider);
      return useCases.loadDetails(query);
    });

/// Statistics intentionally use current active records for principal and
/// breakdowns. Renewed rows are historical versions and must not double count.
final class SqliteDepositStatisticsUseCases
    implements DepositStatisticsUseCases {
  const SqliteDepositStatisticsUseCases(this._database);

  final AppDatabase _database;

  static const _columns = <DepositStatisticsDimension, String>{
    DepositStatisticsDimension.bank: 'bank_name',
    DepositStatisticsDimension.product: 'product_name',
  };

  @override
  Future<DepositStatisticsSnapshot> load({DateTime? now}) async {
    final date = _isoDate((now ?? clock.now()).toLocal());
    final summary = await _database
        .customSelect(
          '''
SELECT
  COUNT(*) FILTER (WHERE d.lifecycle != 'renewed') AS total_count,
  COUNT(*) FILTER (WHERE d.lifecycle = 'active' AND d.final_expiry_date >= ?) AS active_count,
  COUNT(*) FILTER (WHERE d.lifecycle = 'active' AND d.final_expiry_date < ?) AS overdue_count,
  COUNT(*) FILTER (WHERE d.lifecycle = 'renewed') AS renewed_count,
  COUNT(*) FILTER (WHERE d.lifecycle = 'stopped') AS stopped_count,
  COALESCE(SUM(CASE WHEN d.lifecycle = 'active' THEN d.amount_cents ELSE 0 END), 0) AS current_principal,
  COUNT(DISTINCT CASE WHEN d.lifecycle != 'renewed' THEN d.customer_id END) AS customer_count
FROM deposits d
JOIN customers c ON c.id = d.customer_id
WHERE c.is_active = 1
''',
          variables: [Variable.withString(date), Variable.withString(date)],
          readsFrom: {_database.deposits, _database.customers},
        )
        .getSingle();
    final renewal = await _database
        .customSelect('SELECT COUNT(*) AS total FROM renewals')
        .getSingle();
    final byBank = await _loadBreakdown(DepositStatisticsDimension.bank);
    final byProduct = await _loadBreakdown(DepositStatisticsDimension.product);
    return DepositStatisticsSnapshot(
      totalCount: summary.read<int>('total_count'),
      activeCount: summary.read<int>('active_count'),
      overdueCount: summary.read<int>('overdue_count'),
      renewedCount: summary.read<int>('renewed_count'),
      stoppedCount: summary.read<int>('stopped_count'),
      currentPrincipalCents: summary.read<int>('current_principal'),
      customerCount: summary.read<int>('customer_count'),
      renewalCount: renewal.read<int>('total'),
      byBank: byBank,
      byProduct: byProduct,
    );
  }

  @override
  Future<List<DepositStatisticsDetail>> loadDetails(
    DepositStatisticsDetailQuery query,
  ) async {
    if (query.kind != null) return _loadStatusDetails(query.kind!);
    final column = _columns[query.dimension]!;
    final rows = await _database
        .customSelect(
          '''
SELECT d.id AS deposit_id,
       c.name AS customer_name,
       c.phone AS customer_phone,
       d.bank_name AS bank_name,
       d.product_name AS product_name,
       d.amount_cents AS amount_cents,
       d.interest_rate_scaled AS interest_rate_scaled,
       d.rate_precision AS rate_precision,
       d.final_expiry_date AS expiry_date
FROM deposits d
JOIN customers c ON c.id = d.customer_id
WHERE d.lifecycle = 'active'
  AND c.is_active = 1
  AND COALESCE(NULLIF(TRIM(d.$column), ''), '') = ?
ORDER BY d.final_expiry_date,
         c.name COLLATE NOCASE,
         d.id
''',
          variables: [Variable.withString(query.value.trim())],
          readsFrom: {_database.deposits, _database.customers},
        )
        .get();
    return rows
        .map(
          (row) => DepositStatisticsDetail(
            depositId: row.read<String>('deposit_id'),
            customerName: row.read<String>('customer_name'),
            customerPhone: row.readNullable<String>('customer_phone'),
            bankName: row.read<String>('bank_name'),
            productName: row.read<String>('product_name'),
            amountCents: row.read<int>('amount_cents'),
            interestRateScaled: row.read<int>('interest_rate_scaled'),
            ratePrecision: row.read<int>('rate_precision'),
            expiryDate: row.read<String>('expiry_date'),
          ),
        )
        .toList(growable: false);
  }

  Future<List<DepositStatisticsDetail>> _loadStatusDetails(
    DepositStatisticsDetailKind kind,
  ) async {
    final date = _isoDate(clock.now().toLocal());
    final condition = switch (kind) {
      DepositStatisticsDetailKind.active =>
        "d.lifecycle = 'active' AND d.final_expiry_date >= ?",
      DepositStatisticsDetailKind.overdue =>
        "d.lifecycle = 'active' AND d.final_expiry_date < ?",
      DepositStatisticsDetailKind.renewed => "d.lifecycle = 'renewed'",
      DepositStatisticsDetailKind.stopped => "d.lifecycle = 'stopped'",
      _ => "d.lifecycle = 'active'",
    };
    final rows = await _database
        .customSelect(
          '''
SELECT d.id AS deposit_id, c.name AS customer_name, c.phone AS customer_phone,
 d.bank_name, d.product_name, d.amount_cents, d.interest_rate_scaled,
 d.rate_precision, d.start_date, d.final_expiry_date AS expiry_date, d.lifecycle
FROM deposits d JOIN customers c ON c.id = d.customer_id
WHERE c.is_active = 1 AND $condition
ORDER BY d.final_expiry_date, c.name COLLATE NOCASE, d.id
''',
          variables:
              kind == DepositStatisticsDetailKind.active ||
                  kind == DepositStatisticsDetailKind.overdue
              ? [Variable.withString(date)]
              : const [],
          readsFrom: {_database.deposits, _database.customers},
        )
        .get();
    return rows
        .map(
          (row) => DepositStatisticsDetail(
            depositId: row.read<String>('deposit_id'),
            customerName: row.read<String>('customer_name'),
            customerPhone: row.readNullable<String>('customer_phone'),
            bankName: row.read<String>('bank_name'),
            productName: row.read<String>('product_name'),
            amountCents: row.read<int>('amount_cents'),
            interestRateScaled: row.read<int>('interest_rate_scaled'),
            ratePrecision: row.read<int>('rate_precision'),
            startDate: row.read<String>('start_date'),
            expiryDate: row.read<String>('expiry_date'),
            lifecycle: row.read<String>('lifecycle'),
          ),
        )
        .toList(growable: false);
  }

  Future<List<DepositStatisticsBreakdown>> _loadBreakdown(
    DepositStatisticsDimension dimension,
  ) async {
    final column = _columns[dimension]!;
    final rows = await _database
        .customSelect(
          '''
SELECT COALESCE(NULLIF(TRIM(d.$column), ''), '') AS name,
       COALESCE(SUM(d.amount_cents), 0) AS amount_cents,
       COUNT(*) AS deposit_count,
       COUNT(DISTINCT d.customer_id) AS customer_count
FROM deposits d
JOIN customers c ON c.id = d.customer_id
WHERE d.lifecycle = 'active' AND c.is_active = 1
GROUP BY COALESCE(NULLIF(TRIM(d.$column), ''), '')
ORDER BY amount_cents DESC, name COLLATE NOCASE
''',
          readsFrom: {_database.deposits, _database.customers},
        )
        .get();
    return rows
        .map(
          (row) => DepositStatisticsBreakdown(
            name: row.read<String>('name'),
            amountCents: row.read<int>('amount_cents'),
            depositCount: row.read<int>('deposit_count'),
            customerCount: row.read<int>('customer_count'),
          ),
        )
        .toList(growable: false);
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
