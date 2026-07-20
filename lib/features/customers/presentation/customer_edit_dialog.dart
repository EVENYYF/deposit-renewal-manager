import 'package:flutter/material.dart';

import '../domain/customer_repository.dart';

Future<bool> showCustomerEditDialog(
  BuildContext context, {
  CustomerRecord? customer,
  required Future<void> Function(CustomerDraft draft) onSave,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerEditDialog(customer: customer, onSave: onSave),
    ) ??
    false;

class _CustomerEditDialog extends StatefulWidget {
  const _CustomerEditDialog({required this.customer, required this.onSave});

  final CustomerRecord? customer;
  final Future<void> Function(CustomerDraft draft) onSave;

  @override
  State<_CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<_CustomerEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;
  String? _error;

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
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: '姓名'),
        ),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: '手机号（选填）'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? '保存中' : '保存'),
      ),
    ],
  );

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = '姓名不能为空');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        CustomerDraft(
          id: widget.customer?.id ?? '',
          name: _name.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '客户资料保存失败，请重试';
      });
    }
  }
}
