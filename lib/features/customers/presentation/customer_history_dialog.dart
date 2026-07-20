import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/customer_history_service.dart';
import 'customer_history_formatter.dart';

Future<void> showCustomerHistoryDialog(
  BuildContext context,
  WidgetRef ref, {
  required String customerId,
  required String customerName,
}) async {
  final history = await ref
      .read(customerHistoryUseCasesProvider)
      .load(customerId);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('$customerName的修改记录'),
      content: SizedBox(
        width: 480,
        child: history.isEmpty
            ? const Text('暂无修改记录')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: history.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = history[index];
                  final changes = CustomerHistoryFormatter.formatEntry(entry);
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                      entry.entityType == null
                          ? _operationLabel(entry.operation)
                          : '${_entityLabel(entry.entityType)} · '
                                '${_operationLabel(entry.operation)}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(entry.occurredAt),
                        ),
                        for (
                          var changeIndex = 0;
                          changeIndex < changes.length;
                          changeIndex++
                        )
                          _HistoryChange(
                            change: changes[changeIndex],
                            index: changeIndex,
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

String _operationLabel(String value) => switch (value) {
  'create' => '新建',
  'update' => '更新',
  'renew' => '续期',
  'create_from_renewal' => '续期生成新存款',
  'stop' => '停止续期',
  'deactivate' => '停用客户',
  _ => value,
};

String _entityLabel(String? value) => switch (value) {
  'customer' => '客户',
  'deposit' => '存款',
  _ => '记录',
};

class _HistoryChange extends StatelessWidget {
  const _HistoryChange({required this.change, required this.index});

  final FormattedHistoryChange change;
  final int index;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Text(
          '${change.label}：',
          key: Key('history-field-$index'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          change.before,
          key: Key('history-before-$index'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const Icon(Icons.arrow_forward, size: 14),
        Text(
          change.after,
          key: Key('history-after-$index'),
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
