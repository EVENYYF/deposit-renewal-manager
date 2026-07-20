import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/deposit_statistics.dart';

class DepositStatisticsDetailPage extends ConsumerWidget {
  const DepositStatisticsDetailPage({
    required this.dimension,
    required this.value,
    super.key,
  });

  final DepositStatisticsDimension dimension;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = DepositStatisticsDetailQuery(dimension, value);
    final state = ref.watch(depositStatisticsDetailProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: Text('${_dimensionLabel(dimension)}：${_name(value)}'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          onRetry: () => ref.invalidate(depositStatisticsDetailProvider(query)),
        ),
        data: (rows) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(depositStatisticsDetailProvider(query));
            await ref.read(depositStatisticsDetailProvider(query).future);
          },
          child: rows.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(
                      height: 320,
                      child: Center(child: Text('暂无匹配的生效存款')),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (context, index) =>
                      _DetailTile(detail: rows[index]),
                ),
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.detail});

  final DepositStatisticsDetail detail;

  @override
  Widget build(BuildContext context) {
    final phone = detail.customerPhone?.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail.customerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(_money(detail.amountCents)),
              ],
            ),
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(phone),
            ],
            const SizedBox(height: 8),
            Text('${_name(detail.bankName)} · ${_name(detail.productName)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(_rate(detail))),
                Text(detail.expiryDate),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('重新加载'),
    ),
  );
}

String _dimensionLabel(DepositStatisticsDimension dimension) =>
    switch (dimension) {
      DepositStatisticsDimension.bank => '银行',
      DepositStatisticsDimension.product => '产品',
    };

String _name(String value) => value.trim().isEmpty ? '未填写' : value.trim();

String _rate(DepositStatisticsDetail detail) {
  var scale = 1;
  for (var index = 0; index < detail.ratePrecision; index++) {
    scale *= 10;
  }
  final value = (detail.interestRateScaled / scale)
      .toStringAsFixed(detail.ratePrecision)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$value%';
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
