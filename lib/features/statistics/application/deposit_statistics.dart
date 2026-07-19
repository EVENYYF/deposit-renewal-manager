import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

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
}

final class EmptyDepositStatisticsUseCases
    implements DepositStatisticsUseCases {
  const EmptyDepositStatisticsUseCases();

  @override
  Future<DepositStatisticsSnapshot> load({DateTime? now}) async =>
      const DepositStatisticsSnapshot();
}

final depositStatisticsUseCasesProvider = Provider<DepositStatisticsUseCases>(
  (ref) => const EmptyDepositStatisticsUseCases(),
);

final depositStatisticsControllerProvider =
    FutureProvider.autoDispose<DepositStatisticsSnapshot>((ref) {
      return ref.read(depositStatisticsUseCasesProvider).load();
    });

/// Statistics intentionally use current active records for principal and
/// breakdowns. Renewed rows are historical versions and must not double count.
final class SqliteDepositStatisticsUseCases
    implements DepositStatisticsUseCases {
  const SqliteDepositStatisticsUseCases(this._database);

  final AppDatabase _database;

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
    final byBank = await _loadBreakdown('bank_name');
    final byProduct = await _loadBreakdown('product_name');
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

  Future<List<DepositStatisticsBreakdown>> _loadBreakdown(String column) async {
    final rows = await _database
        .customSelect(
          '''
SELECT COALESCE(NULLIF(TRIM(d.$column), ''), '未填写') AS name,
       COALESCE(SUM(d.amount_cents), 0) AS amount_cents,
       COUNT(*) AS deposit_count,
       COUNT(DISTINCT d.customer_id) AS customer_count
FROM deposits d
JOIN customers c ON c.id = d.customer_id
WHERE d.lifecycle = 'active' AND c.is_active = 1
GROUP BY COALESCE(NULLIF(TRIM(d.$column), ''), '未填写')
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
