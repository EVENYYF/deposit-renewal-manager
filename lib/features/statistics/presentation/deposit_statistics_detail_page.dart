import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../deposits/application/deposit_details_service.dart';
import '../../deposits/application/deposit_workflow_controller.dart';
import '../../deposits/domain/deposit_repository.dart';
import '../../deposits/presentation/deposit_form_page.dart';
import '../../deposits/presentation/deposit_details_view.dart';
import '../application/deposit_statistics.dart';

class DepositStatisticsDetailPage extends ConsumerWidget {
  const DepositStatisticsDetailPage({
    required this.dimension,
    required this.value,
    this.kind,
    super.key,
  });

  final DepositStatisticsDimension dimension;
  final String value;
  final DepositStatisticsDetailKind? kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = DepositStatisticsDetailQuery(dimension, value, kind: kind);
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
                  itemBuilder: (context, index) => _DetailTile(
                    detail: rows[index],
                    onChanged: () =>
                        ref.invalidate(depositStatisticsDetailProvider(query)),
                  ),
                ),
        ),
      ),
    );
  }
}

class _DetailTile extends ConsumerWidget {
  const _DetailTile({required this.detail, required this.onChanged});

  final DepositStatisticsDetail detail;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = detail.customerPhone?.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final record = await ref
              .read(depositDetailsUseCasesProvider)
              .load(detail.depositId);
          if (record != null && context.mounted) {
            final action = await showDepositDetailsDialog(
              context,
              data: record.data,
              allowActions: record.editableDraft != null,
            );
            if (!context.mounted ||
                action == null ||
                record.editableDraft == null) {
              return;
            }
            switch (action) {
              case DepositDetailsAction.stop:
                final confirmed = await _confirmStop(context);
                if (!confirmed || !context.mounted) return;
                try {
                  await ref
                      .read(depositWorkflowProvider)
                      .stop(detail.depositId);
                  onChanged();
                } on DepositNotActiveException {
                  if (context.mounted) {
                    _showError(context, '该存款已被处理，请刷新后重试');
                  }
                } on Object {
                  if (context.mounted) {
                    _showError(context, '停止续期失败，请稍后重试');
                  }
                }
                return;
              case DepositDetailsAction.renew:
                await _showForm(context, ref, record, DepositFormMode.renew);
                return;
              case DepositDetailsAction.edit:
                await _showForm(context, ref, record, DepositFormMode.update);
                return;
            }
          }
        },
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
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref,
    DepositDetailsRecord record,
    DepositFormMode mode,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 560,
          height: 700,
          child: DepositFormPage(
            mode: mode,
            sourceDepositId: detail.depositId,
            initial: record.editableDraft,
            initialCustomerName: record.data.customerName,
            initialCustomerPhone: record.data.customerPhone,
            onSaved: () => Navigator.pop(dialogContext, true),
          ),
        ),
      ),
    );
    if (saved == true) onChanged();
  }

  Future<bool> _confirmStop(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('停止续期？'),
          content: const Text('停止后该笔存款不再进入提醒。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认停止'),
            ),
          ],
        ),
      ) ??
      false;

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
