import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../application/customer_controller.dart';
import '../application/customer_history_service.dart';
import '../domain/customer_repository.dart';
import '../domain/name_search_index.dart';
import 'customer_history_formatter.dart';
import 'customer_detail_page.dart';
import '../../deposits/domain/deposit.dart';
import '../../deposits/domain/deposit_repository.dart';
import '../../deposits/domain/local_date.dart';
import '../../deposits/application/deposit_workflow_controller.dart';
import '../../deposits/presentation/deposit_form_page.dart';

class CustomerDirectoryPage extends ConsumerStatefulWidget {
  const CustomerDirectoryPage({super.key});

  @override
  ConsumerState<CustomerDirectoryPage> createState() =>
      _CustomerDirectoryPageState();
}

class _CustomerDirectoryPageState extends ConsumerState<CustomerDirectoryPage> {
  final _search = TextEditingController();
  String? _selectedBank;
  String? _selectedProduct;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(customerControllerProvider);
    ref.listen(customerRefreshMessageProvider, (previous, next) {
      if (next != null && next != previous) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next)));
      }
    });
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '客户管理',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filled(
                    tooltip: '新增客户',
                    onPressed: () => _editCustomer(context),
                    icon: const Icon(Icons.person_add_alt_1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SearchBar(
                controller: _search,
                hintText: '姓名、手机号或拼音',
                leading: const Icon(Icons.search),
                trailing: _search.text.isEmpty
                    ? null
                    : [
                        IconButton(
                          tooltip: '清除',
                          onPressed: _clear,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                onChanged: (value) {
                  setState(() {});
                  ref.read(customerControllerProvider.notifier).search(value);
                },
              ),
              const SizedBox(height: 12),
              directory.maybeWhen(
                data: (state) => _buildFilters(state.results),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(customerControllerProvider.notifier).retry(),
            child: directory.when(
              skipLoadingOnRefresh: true,
              skipError: true,
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 320,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
              error: (error, stack) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 320,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: () => ref
                            .read(customerControllerProvider.notifier)
                            .retry(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新加载'),
                      ),
                    ),
                  ),
                ],
              ),
              data: (state) {
                final results = _filter(state.results);
                return results.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 320,
                            child: Center(
                              child: Text(
                                state.query.isEmpty ? '暂无客户' : '没有匹配的客户',
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _CustomerCard(result: results[index]),
                      );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(List<CustomerSearchResult> results) {
    final banks = {
      for (final result in results)
        for (final deposit in result.deposits)
          if (deposit.bankName.trim().isNotEmpty) deposit.bankName.trim(),
    }.toList()..sort();
    final products = {
      for (final result in results)
        for (final deposit in result.deposits)
          if (deposit.productName.trim().isNotEmpty) deposit.productName.trim(),
    }.toList()..sort();
    final selectedBank = banks.contains(_selectedBank) ? _selectedBank : null;
    final selectedProduct = products.contains(_selectedProduct)
        ? _selectedProduct
        : null;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: const Key('customer-bank-filter'),
            initialValue: selectedBank,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '银行',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部银行')),
              for (final bank in banks)
                DropdownMenuItem(value: bank, child: Text(bank)),
            ],
            onChanged: (value) => setState(() => _selectedBank = value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: const Key('customer-product-filter'),
            initialValue: selectedProduct,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '产品',
              prefixIcon: Icon(Icons.savings_outlined),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部产品')),
              for (final product in products)
                DropdownMenuItem(value: product, child: Text(product)),
            ],
            onChanged: (value) => setState(() => _selectedProduct = value),
          ),
        ),
      ],
    );
  }

  List<CustomerSearchResult> _filter(List<CustomerSearchResult> results) =>
      results
          .where((result) {
            return result.deposits.any(
                  (deposit) =>
                      (_selectedBank == null ||
                          deposit.bankName.trim() == _selectedBank) &&
                      (_selectedProduct == null ||
                          deposit.productName.trim() == _selectedProduct),
                ) ||
                (_selectedBank == null && _selectedProduct == null);
          })
          .toList(growable: false);

  void _clear() {
    _search.clear();
    setState(() {});
    ref.read(customerControllerProvider.notifier).search('');
  }

  Future<void> _editCustomer(
    BuildContext context, [
    CustomerRecord? customer,
  ]) async {
    final draft = await showDialog<CustomerDraft>(
      context: context,
      builder: (_) => _CustomerEditDialog(customer: customer),
    );
    if (draft != null) {
      if (customer == null && (draft.phone?.trim().isNotEmpty ?? false)) {
        final matches = await ref
            .read(customerUseCasesProvider)
            .load(draft.phone!.trim());
        final duplicate = matches
            .map((result) => result.customer)
            .where(
              (candidate) =>
                  normalizeSearchText(candidate.name) ==
                      normalizeSearchText(draft.name) &&
                  normalizePhone(candidate.phone ?? '') ==
                      normalizePhone(draft.phone!),
            )
            .firstOrNull;
        if (duplicate != null && context.mounted) {
          final merge = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('发现相同客户'),
              content: Text('${duplicate.name}（${duplicate.phone}）已存在。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('仍新增'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('归入已有客户'),
                ),
              ],
            ),
          );
          if (merge == true) {
            return;
          }
        }
      }
      await ref.read(customerControllerProvider.notifier).saveAndRefresh(draft);
    }
  }
}

class _CustomerEditDialog extends StatefulWidget {
  const _CustomerEditDialog({this.customer});
  final CustomerRecord? customer;

  @override
  State<_CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<_CustomerEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer?.name);
    _phone = TextEditingController(text: widget.customer?.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.customer == null ? '新增客户' : '编辑客户'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: '姓名'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入姓名' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '手机号（选填）'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            CustomerDraft(
              id: widget.customer?.id ?? const Uuid().v4(),
              name: _name.text,
              phone: _phone.text,
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _CustomerCard extends ConsumerStatefulWidget {
  const _CustomerCard({required this.result});
  final CustomerSearchResult result;

  @override
  ConsumerState<_CustomerCard> createState() => _CustomerCardState();
}

enum _DepositDetailAction { renew, stop, edit }

class _CustomerCardState extends ConsumerState<_CustomerCard> {
  Future<List<CustomerDepositChain>>? _chains;
  final _mutatingDeposits = <String>{};

  CustomerSearchResult get result => widget.result;

  @override
  void didUpdateWidget(covariant _CustomerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_chains != null && oldWidget.result != widget.result) {
      _chains = _loadDepositChains();
    }
  }

  Future<List<CustomerDepositChain>> _loadDepositChains() =>
      ref.read(customerDepositHistoryUseCasesProvider).load(widget.result);

  void _loadDeposits() {
    _chains ??= _loadDepositChains();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      onExpansionChanged: (expanded) {
        if (expanded) setState(_loadDeposits);
      },
      trailing: IconButton(
        tooltip: '客户详情',
        icon: const Icon(Icons.chevron_right),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CustomerDetailPage(
              customerId: result.customer.id,
              initialResult: result,
            ),
          ),
        ),
      ),
      leading: CircleAvatar(child: Text(result.customer.name.characters.first)),
      title: Text(
        result.customer.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${result.customer.phone ?? '未填写手机号'} · ${result.deposits.length} 笔存款',
      ),
      children: [
        if (result.deposits.isEmpty)
          const ListTile(title: Text('暂无存款'))
        else if (_chains != null)
          FutureBuilder<List<CustomerDepositChain>>(
            future: _chains,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('存款详情加载失败'),
                  trailing: IconButton(
                    tooltip: '重试',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {
                      _chains = _loadDepositChains();
                    }),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              return Column(
                children: [
                  for (final chain in snapshot.data!) _buildChain(chain),
                ],
              );
            },
          ),
        OverflowBar(
          children: [
            TextButton.icon(
              onPressed: () => _showHistory(context, ref),
              icon: const Icon(Icons.history),
              label: const Text('修改记录'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _addDeposit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('新增存款'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildChain(CustomerDepositChain chain) => Column(
    children: [
      for (var index = 0; index < chain.versions.length; index++)
        Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 28),
          child: _buildDepositTile(chain.versions[index], isRenewal: index > 0),
        ),
    ],
  );

  Widget _buildDepositTile(
    CustomerDepositVersion deposit, {
    required bool isRenewal,
  }) {
    final appearance = _appearance(deposit);
    final bank = deposit.bankName.isEmpty ? '未填写银行' : deposit.bankName;
    final product = deposit.productName.trim();
    final title = product.isEmpty ? bank : '$bank · $product';
    return ListTile(
      key: Key('customer-deposit-${deposit.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        isRenewal ? Icons.subdirectory_arrow_right : Icons.account_balance,
        color: appearance.color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: appearance.color,
          decoration: deposit.lifecycle == DepositLifecycle.renewed
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      subtitle: Text('到期日 ${deposit.finalExpiryDate}'),
      trailing: Text(
        appearance.label,
        style: TextStyle(color: appearance.color, fontWeight: FontWeight.w600),
      ),
      onTap: () => _showDepositDetails(context, deposit),
    );
  }

  _DepositAppearance _appearance(CustomerDepositVersion deposit) {
    if (deposit.lifecycle == DepositLifecycle.renewed) {
      return const _DepositAppearance('已续期', Colors.grey);
    }
    if (deposit.lifecycle == DepositLifecycle.stopped) {
      return const _DepositAppearance('已停止', Color(0xFF4B5563));
    }
    final now = DateTime.now();
    final today = LocalDate(now.year, now.month, now.day);
    if (deposit.finalExpiryDate.isBefore(today)) {
      return const _DepositAppearance('已到期', Color(0xFFC62828));
    }
    return const _DepositAppearance('生效中', Color(0xFF2E7D32));
  }

  Future<void> _addDeposit(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 560,
          height: 700,
          child: DepositFormPage(
            initialCustomerId: result.customer.id,
            initialCustomerName: result.customer.name,
            initialCustomerPhone: result.customer.phone,
            onSaved: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
    if (context.mounted) {
      await ref.read(customerControllerProvider.notifier).retry();
      if (mounted) {
        setState(() {
          _chains = ref
              .read(customerDepositHistoryUseCasesProvider)
              .load(widget.result);
        });
      }
    }
  }

  Future<void> _showDepositDetails(
    BuildContext context,
    CustomerDepositVersion deposit,
  ) async {
    final appearance = _appearance(deposit);
    final action = await showDialog<_DepositDetailAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('存款详情'),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: [
              _detailRow('客户', result.customer.name),
              _detailRow('手机号', result.customer.phone ?? '未填写'),
              _detailRow(
                '银行',
                deposit.bankName.isEmpty ? '未填写' : deposit.bankName,
              ),
              _detailRow(
                '产品',
                deposit.productName.isEmpty ? '未填写' : deposit.productName,
              ),
              if (deposit.amountCents != null)
                _detailRow(
                  '金额',
                  '¥${(deposit.amountCents! / 100).toStringAsFixed(2)}',
                ),
              if (deposit.interestRateScaled != null)
                _detailRow('年利率', '${_formatRate(deposit)}%'),
              if (deposit.startDate != null)
                _detailRow('存入日期', deposit.startDate.toString()),
              _detailRow('到期日期', deposit.finalExpiryDate.toString()),
              _detailRow('状态', appearance.label, valueColor: appearance.color),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          if (deposit.lifecycle == DepositLifecycle.active &&
              deposit.editableDraft != null &&
              !_mutatingDeposits.contains(deposit.id)) ...[
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DepositDetailAction.stop),
              child: const Text('停止续期'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DepositDetailAction.renew),
              icon: const Icon(Icons.autorenew),
              label: const Text('续期'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DepositDetailAction.edit),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('编辑'),
            ),
          ],
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _DepositDetailAction.renew:
        await _showDepositForm(this.context, deposit, DepositFormMode.renew);
        return;
      case _DepositDetailAction.stop:
        await _stopDeposit(this.context, deposit);
        return;
      case _DepositDetailAction.edit:
        await _showDepositForm(this.context, deposit, DepositFormMode.update);
        return;
    }
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  String _formatRate(CustomerDepositVersion deposit) {
    final divisor = _pow10(deposit.ratePrecision);
    return (deposit.interestRateScaled! / divisor)
        .toStringAsFixed(deposit.ratePrecision)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  int _pow10(int exponent) {
    var result = 1;
    for (var index = 0; index < exponent; index++) {
      result *= 10;
    }
    return result;
  }

  Future<void> _showDepositForm(
    BuildContext context,
    CustomerDepositVersion deposit,
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
            sourceDepositId: deposit.id,
            initial: deposit.editableDraft,
            initialCustomerName: result.customer.name,
            initialCustomerPhone: result.customer.phone,
            onSaved: () => Navigator.pop(dialogContext, true),
          ),
        ),
      ),
    );
    if (saved == true) await _refreshAfterMutation();
  }

  Future<void> _stopDeposit(
    BuildContext context,
    CustomerDepositVersion deposit,
  ) async {
    final confirmed = await showDialog<bool>(
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
    );
    if (confirmed != true || !mounted) return;
    setState(() => _mutatingDeposits.add(deposit.id));
    try {
      await ref.read(depositWorkflowProvider).stop(deposit.id);
    } on DepositNotActiveException {
      _showDepositError('该存款已被处理，请刷新后重试');
    } on Object {
      _showDepositError('停止续期失败，请稍后重试');
    }
    try {
      await _refreshAfterMutation();
    } finally {
      if (mounted) setState(() => _mutatingDeposits.remove(deposit.id));
    }
  }

  Future<void> _refreshAfterMutation() async {
    await ref.read(customerControllerProvider.notifier).retry();
  }

  void _showDepositError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showHistory(BuildContext context, WidgetRef ref) async {
    final history = await ref
        .read(customerHistoryUseCasesProvider)
        .load(result.customer.id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${result.customer.name}的修改记录'),
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
                            _historyChange(
                              context,
                              changes[changeIndex],
                              changeIndex,
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  static String _operationLabel(String value) => switch (value) {
    'create' => '新建',
    'update' => '更新',
    'renew' => '续期',
    'create_from_renewal' => '续期生成新存款',
    'stop' => '停止续期',
    'deactivate' => '停用客户',
    _ => value,
  };

  static String _entityLabel(String? value) => switch (value) {
    'customer' => '客户',
    'deposit' => '存款',
    _ => '记录',
  };

  Widget _historyChange(
    BuildContext context,
    FormattedHistoryChange change,
    int index,
  ) => Padding(
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

final class _DepositAppearance {
  const _DepositAppearance(this.label, this.color);
  final String label;
  final Color color;
}
