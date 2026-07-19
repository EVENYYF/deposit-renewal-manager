import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/deposit_statistics.dart';

class DepositStatisticsPage extends ConsumerWidget {
  const DepositStatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(depositStatisticsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('存款统计'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () =>
                ref.invalidate(depositStatisticsControllerProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          onRetry: () => ref.invalidate(depositStatisticsControllerProvider),
        ),
        data: (snapshot) => _StatisticsBody(snapshot: snapshot),
      ),
    );
  }
}

class _StatisticsBody extends StatelessWidget {
  const _StatisticsBody({required this.snapshot});
  final DepositStatisticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Metric(label: '当前本金', value: _money(snapshot.currentPrincipalCents)),
          _Metric(label: '当前笔数', value: '${snapshot.totalCount} 笔'),
          _Metric(label: '客户数', value: '${snapshot.customerCount} 人'),
          _Metric(label: '续期次数', value: '${snapshot.renewalCount} 次'),
        ],
      ),
      const SizedBox(height: 24),
      Text('存款状态', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            _StatusRow(label: '生效中', value: snapshot.activeCount),
            _StatusRow(label: '已逾期', value: snapshot.overdueCount),
            _StatusRow(label: '已续期历史', value: snapshot.renewedCount),
            _StatusRow(label: '已停止', value: snapshot.stoppedCount),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _BreakdownSection(title: '按银行', rows: snapshot.byBank),
      const SizedBox(height: 24),
      _BreakdownSection(title: '按产品', rows: snapshot.byProduct),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 164,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) =>
      ListTile(dense: true, title: Text(label), trailing: Text('$value 笔'));
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.title, required this.rows});
  final String title;
  final List<DepositStatisticsBreakdown> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        const Card(child: ListTile(title: Text('暂无生效中的存款')))
      else
        ...rows.map(
          (row) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(row.name),
              subtitle: Text(
                '${row.depositCount} 笔 · ${row.customerCount} 位客户',
              ),
              trailing: Text(_money(row.amountCents)),
            ),
          ),
        ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('暂时无法加载统计'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    ),
  );
}

String _money(int cents) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final units = (absolute ~/ 100).toString();
  final grouped = units.replaceAllMapped(
    RegExp(r'(?<=\d)(?=(\d{3})+$)'),
    (_) => ',',
  );
  return '${negative ? '-' : ''}¥$grouped.${(absolute % 100).toString().padLeft(2, '0')}';
}
