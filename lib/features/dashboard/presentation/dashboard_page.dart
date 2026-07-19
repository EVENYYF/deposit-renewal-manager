import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../../core/notifications/notification_scheduler.dart';
import '../../deposits/application/deposit_workflow_controller.dart';
import '../../deposits/domain/deposit_repository.dart';
import '../../deposits/domain/local_date.dart';
import '../../deposits/presentation/deposit_form_page.dart';
import '../../templates/application/render_message.dart';
import '../../templates/domain/message_template.dart';
import '../application/dashboard_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(dashboardControllerProvider);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('存款续期', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const NotificationStatusBanner(),
              ],
            ),
          ),
        ),
        value.when(
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => SliverFillRemaining(
            child: _StateMessage(
              title: '暂时无法加载首页',
              actionLabel: '重试',
              onAction: () =>
                  ref.read(dashboardControllerProvider.notifier).retry(),
            ),
          ),
          data: (snapshot) => SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.list(
              children: [
                _Summary(snapshot: snapshot),
                const SizedBox(height: 16),
                _ReminderSection(title: '今日到期', records: snapshot.today),
                _ReminderSection(title: '三天内', records: snapshot.nextThreeDays),
                _ReminderSection(title: '本周内', records: snapshot.thisWeek),
                _ReminderSection(title: '到期待处理', records: snapshot.overdue),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class NotificationStatusBanner extends ConsumerWidget {
  const NotificationStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationCapabilityControllerProvider);
    if (state.capability == null && state.message == null && !state.busy) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(
      notificationCapabilityControllerProvider.notifier,
    );
    final permission = state.needsNotificationPermission;
    final exact =
        state.capability?.notificationsAllowed == true &&
        state.capability?.canScheduleExact == false;
    return MaterialBanner(
      content: Text(state.message ?? '通知提醒需要处理'),
      actions: [
        TextButton(
          onPressed: state.busy
              ? null
              : permission
              ? controller.requestNotificationPermission
              : exact
              ? controller.requestExactAlarmPermission
              : controller.reconcileAll,
          child: Text(
            permission
                ? '开启通知'
                : exact
                ? '开启精确提醒'
                : '重试',
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Metric(label: '即将到期', value: snapshot.dueSoonCount),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _Metric(label: '待处理', value: snapshot.overdueCount),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _Metric(label: '客户', value: snapshot.customerCount),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _ReminderSection extends ConsumerWidget {
  const _ReminderSection({required this.title, required this.records});
  final String title;
  final List<DashboardReminder> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('${records.length} 笔'),
          ],
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          const Card(
            child: Padding(padding: EdgeInsets.all(16), child: Text('暂无记录')),
          )
        else
          ...records.map((record) => _ReminderTile(record: record)),
      ],
    ),
  );
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.record});
  final DashboardReminder record;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
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
                  record.customerName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(record.expiryDate),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${record.bankName} · ${NumberFormat.currency(locale: 'zh_CN', symbol: '¥').format(record.amountCents / 100)}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showPrompt(context),
                icon: const Icon(Icons.content_copy),
                label: const Text('提示语'),
              ),
              FilledButton.tonal(
                onPressed: () =>
                    _showDepositForm(context, ref, DepositFormMode.renew),
                child: const Text('续期'),
              ),
              TextButton(
                onPressed: () =>
                    _showDepositForm(context, ref, DepositFormMode.update),
                child: const Text('更新'),
              ),
              TextButton(
                onPressed: () => _confirmStop(context, ref),
                child: const Text('停止续期'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _confirmStop(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('停止续期？'),
        content: const Text('停止后该笔存款不再进入提醒。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认停止'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(depositWorkflowProvider).stop(record.depositId);
    await ref.read(dashboardControllerProvider.notifier).retry();
  }

  Future<void> _showDepositForm(
    BuildContext context,
    WidgetRef ref,
    DepositFormMode mode,
  ) async {
    final draft = _draft;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 560,
          height: 700,
          child: DepositFormPage(
            mode: mode,
            sourceDepositId: record.depositId,
            initial: draft,
            initialCustomerName: record.customerName,
            initialCustomerPhone: record.customerPhone,
            onSaved: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
    if (context.mounted) {
      await ref.read(dashboardControllerProvider.notifier).retry();
    }
  }

  DepositDraft get _draft => DepositDraft(
    id: record.depositId,
    customerId: record.customerId,
    amountCents: record.amountCents,
    bankName: record.bankName,
    productName: record.productName,
    termValue: record.termValue,
    termUnit: record.termUnit == null
        ? null
        : DepositTermUnit.values.byName(record.termUnit!),
    interestRateScaled: record.interestRateScaled,
    ratePrecision: record.ratePrecision,
    startDate: _parseDate(record.startDate),
    calculatedExpiryDate: record.calculatedExpiryDate == null
        ? null
        : _parseDate(record.calculatedExpiryDate!),
    finalExpiryDate: _parseDate(record.expiryDate),
  );

  LocalDate _parseDate(String value) {
    final parts = value.split('-');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Future<void> _showPrompt(BuildContext context) async {
    final amount = NumberFormat.currency(
      locale: 'zh_CN',
      symbol: '¥',
    ).format(record.amountCents / 100);
    final values = TemplateValues(
      customerName: record.customerName,
      amount: amount,
      bank: record.bankName,
      depositDate: record.startDate,
      expiryDate: record.expiryDate,
    );
    final rendered = renderMessage(
      const MessageTemplate(
        name: '到期提醒',
        body:
            '您好，{{customerName}}，您在{{bank}}的{{amount}}存款将于{{expiryDate}}到期，请问是否需要续期？',
      ),
      values,
    );
    final editor = TextEditingController(text: rendered);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('续期提示语'),
        content: TextField(controller: editor, maxLines: 6, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: editor.text));
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已复制')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('复制'),
          ),
        ],
      ),
    );
    editor.dispose();
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
