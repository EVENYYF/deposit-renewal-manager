import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../application/customer_controller.dart';
import '../domain/customer_repository.dart';

class CustomerDirectoryPage extends ConsumerStatefulWidget {
  const CustomerDirectoryPage({super.key});

  @override
  ConsumerState<CustomerDirectoryPage> createState() =>
      _CustomerDirectoryPageState();
}

class _CustomerDirectoryPageState extends ConsumerState<CustomerDirectoryPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(customerControllerProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '客户管理',
                      style: Theme.of(context).textTheme.headlineSmall,
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
                        ref
                            .read(customerControllerProvider.notifier)
                            .search(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: '新增客户',
                onPressed: () => _editCustomer(context),
                icon: const Icon(Icons.person_add_alt_1),
              ),
            ],
          ),
        ),
        Expanded(
          child: directory.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(customerControllerProvider.notifier).retry(),
                icon: const Icon(Icons.refresh),
                label: const Text('重新加载'),
              ),
            ),
            data: (state) => state.results.isEmpty
                ? Center(child: Text(state.query.isEmpty ? '暂无客户' : '没有匹配的客户'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: state.results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _CustomerCard(result: state.results[index]),
                  ),
          ),
        ),
      ],
    );
  }

  void _clear() {
    _search.clear();
    setState(() {});
    ref.read(customerControllerProvider.notifier).search('');
  }

  Future<void> _editCustomer(
    BuildContext context, [
    CustomerRecord? customer,
  ]) async {
    final name = TextEditingController(text: customer?.name);
    final phone = TextEditingController(text: customer?.phone);
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer == null ? '新增客户' : '编辑客户'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: '姓名'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入姓名' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '手机号（选填）'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await ref
          .read(customerControllerProvider.notifier)
          .saveAndRefresh(
            CustomerDraft(
              id: customer?.id ?? const Uuid().v4(),
              name: name.text,
              phone: phone.text,
            ),
          );
    }
    name.dispose();
    phone.dispose();
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.result});
  final CustomerSearchResult result;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
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
        else
          ...result.deposits.map(
            (deposit) => ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(
                deposit.bankName.isEmpty ? '未填写银行' : deposit.bankName,
              ),
              subtitle: Text('到期日 ${deposit.finalExpiryDate}'),
              trailing: Text(_lifecycleLabel(deposit.lifecycle.name)),
            ),
          ),
        OverflowBar(
          children: [
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.history),
              label: const Text('修改记录'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('新增存款'),
            ),
          ],
        ),
      ],
    ),
  );

  static String _lifecycleLabel(String value) => switch (value) {
    'active' => '有效',
    'renewed' => '已续期',
    _ => '已停止',
  };
}
