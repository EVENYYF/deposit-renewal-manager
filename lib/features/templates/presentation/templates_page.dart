import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/render_message.dart';
import '../domain/message_template.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key, this.initial = const []});
  final List<MessageTemplate> initial;

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  late final List<MessageTemplate> _templates = [...widget.initial];
  int _selected = 0;
  final _body = TextEditingController();
  final _name = TextEditingController();
  String? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_templates.isEmpty) {
      _templates.add(
        const MessageTemplate(
          name: '到期提醒',
          body: '{{customerName}}您好，您的{{bank}}{{product}}将于{{expiryDate}}到期。',
          isDefault: true,
        ),
      );
    }
    _loadSelected();
  }

  void _loadSelected() {
    _name.text = _templates[_selected].name;
    _body.text = _templates[_selected].body;
    _preview = null;
    _error = null;
  }

  @override
  void dispose() {
    _body.dispose();
    _name.dispose();
    super.dispose();
  }

  void _saveDraft() {
    setState(() {
      _templates[_selected] = MessageTemplate(
        name: _name.text.trim(),
        body: _body.text,
      );
      _error = null;
    });
  }

  void _render() {
    try {
      final value = renderMessage(
        MessageTemplate(name: _name.text, body: _body.text),
        const TemplateValues(
          customerName: '张三',
          amount: '100,000.00元',
          bank: '工商银行',
          product: '定期存款',
          interestRate: '2.15%',
          depositDate: '2026-01-01',
          expiryDate: '2027-01-01',
        ),
      );
      setState(() {
        _preview = value;
        _error = null;
      });
    } on TemplateRenderException catch (error) {
      setState(() {
        _error = error.message;
        _preview = null;
      });
    }
  }

  Future<void> _copy() async {
    if (_preview == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _preview!));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('续期提示语')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(
          initialValue: _selected,
          decoration: const InputDecoration(
            labelText: '模板',
            border: OutlineInputBorder(),
          ),
          items: [
            for (var i = 0; i < _templates.length; i++)
              DropdownMenuItem(value: i, child: Text(_templates[i].name)),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selected = value;
                _loadSelected();
              });
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: '模板名称',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _body,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: '模板内容',
            helperText: '可用变量：{{customerName}}、{{expiryDate}} 等',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _saveDraft,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存模板'),
            ),
            FilledButton.icon(
              onPressed: _render,
              icon: const Icon(Icons.preview_outlined),
              label: const Text('生成预览'),
            ),
            OutlinedButton.icon(
              onPressed: _preview == null ? null : _copy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('复制'),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_preview != null)
          Card(
            margin: const EdgeInsets.only(top: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_preview!),
            ),
          ),
      ],
    ),
  );
}
