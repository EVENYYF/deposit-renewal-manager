// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../deposits/presentation/deposit_details_view.dart';
import '../../deposits/application/deposit_details_service.dart';
import '../../deposits/application/deposit_workflow_controller.dart';
import '../../deposits/presentation/deposit_form_page.dart';
import '../application/customer_controller.dart';
import '../domain/customer_repository.dart';
import 'customer_edit_dialog.dart';
import 'customer_history_dialog.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({
    required this.customerId,
    this.initialResult,
    super.key,
  });
  final String customerId;
  final CustomerSearchResult? initialResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerControllerProvider);
    final result =
        state.asData?.value.results
            .where((item) => item.customer.id == customerId)
            .firstOrNull ??
        initialResult;
    if (result == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(result.customer.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(result.customer.name),
            subtitle: Text(result.customer.phone ?? '添加手机号'),
            trailing: IconButton(
              onPressed: result.customer.phone == null
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: result.customer.phone!),
                      );
                      if (context.mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('已复制手机号')));
                    },
              icon: const Icon(Icons.copy_outlined),
              tooltip: '复制手机号',
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              await showCustomerEditDialog(
                context,
                customer: result.customer,
                onSave: (draft) => ref
                    .read(customerControllerProvider.notifier)
                    .saveAndRefresh(draft),
              );
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('编辑客户资料'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DepositFormPage(
                  initialCustomerId: result.customer.id,
                  initialCustomerName: result.customer.name,
                  initialCustomerPhone: result.customer.phone,
                  onSaved: () =>
                      ref.read(customerControllerProvider.notifier).retry(),
                ),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('新增存款'),
          ),
          OutlinedButton.icon(
            onPressed: () => showCustomerHistoryDialog(
              context,
              ref,
              customerId: result.customer.id,
              customerName: result.customer.name,
            ),
            icon: const Icon(Icons.history),
            label: const Text('修改记录'),
          ),
          const SizedBox(height: 16),
          const Text('存款'),
          for (final deposit in result.deposits)
            ListTile(
              title: Text(
                deposit.productName.isEmpty
                    ? deposit.bankName
                    : deposit.productName,
              ),
              subtitle: Text(
                '${deposit.bankName} · ${deposit.finalExpiryDate}',
              ),
              onTap: () async {
                final record = await ref
                    .read(depositDetailsUseCasesProvider)
                    .load(deposit.id);
                if (record != null && context.mounted) {
                  final action = await showDepositDetailsDialog(
                    context,
                    data: record.data,
                    allowActions: record.editableDraft != null,
                  );
                  if (!context.mounted ||
                      action == null ||
                      record.editableDraft == null)
                    return;
                  if (action == DepositDetailsAction.stop) {
                    await ref.read(depositWorkflowProvider).stop(deposit.id);
                    await ref.read(customerControllerProvider.notifier).retry();
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DepositFormPage(
                        mode: action == DepositDetailsAction.renew
                            ? DepositFormMode.renew
                            : DepositFormMode.update,
                        sourceDepositId: deposit.id,
                        initial: record.editableDraft,
                        initialCustomerId: result.customer.id,
                        initialCustomerName: result.customer.name,
                        initialCustomerPhone: result.customer.phone,
                        onSaved: () => ref
                            .read(customerControllerProvider.notifier)
                            .retry(),
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
