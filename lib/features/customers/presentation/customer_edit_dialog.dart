// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../domain/customer_repository.dart';

Future<bool> showCustomerEditDialog(
  BuildContext context, {
  CustomerRecord? customer,
  required Future<void> Function(CustomerDraft draft) onSave,
}) async {
  final name = TextEditingController(text: customer?.name);
  final phone = TextEditingController(text: customer?.phone);
  var saving = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(customer == null ? '新增客户' : '编辑客户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '姓名'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号（选填）'),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (name.text.trim().isEmpty) {
                      setState(() => error = '姓名不能为空');
                      return;
                    }
                    setState(() => saving = true);
                    try {
                      await onSave(
                        CustomerDraft(
                          id: customer?.id ?? '',
                          name: name.text.trim(),
                          phone: phone.text.trim().isEmpty
                              ? null
                              : phone.text.trim(),
                        ),
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (_) {
                      if (context.mounted)
                        setState(() {
                          saving = false;
                          error = '客户资料保存失败，请重试';
                        });
                    }
                  },
            child: Text(saving ? '保存中' : '保存'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  phone.dispose();
  return result ?? false;
}
