import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/render_message.dart';
import '../domain/message_template.dart';

final class TemplateBindings {
  const TemplateBindings({required this.load, required this.save});

  final Future<List<MessageTemplate>> Function() load;
  final Future<MessageTemplate> Function(MessageTemplate template) save;
}

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key, required this.bindings});
  final TemplateBindings bindings;

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  List<MessageTemplate> _templates = const [];
  int _selected = 0;
  final _body = TextEditingController();
  final _name = TextEditingController();
  bool _enabled = true;
  bool _isDefault = false;
  bool _loading = true;
  bool _saving = false;
  String? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload({String? selectedId}) async {
    try {
      final loaded = await widget.bindings.load();
      if (!mounted) return;
      setState(() {
        _templates = loaded.isEmpty
            ? const [
                MessageTemplate(
                  name: '到期提醒',
                  body:
                      '{{customerName}}您好，您的{{bank}}{{product}}将于{{expiryDate}}到期。',
                  isDefault: true,
                ),
              ]
            : loaded;
        final index = selectedId == null
            ? 0
            : _templates.indexWhere((item) => item.id == selectedId);
        _selected = index < 0 ? 0 : index;
        _loading = false;
        _loadSelected();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败：$error';
        });
      }
    }
  }

  void _loadSelected() {
    final selected = _templates[_selected];
    _name.text = selected.name;
    _body.text = selected.body;
    _enabled = selected.isEnabled;
    _isDefault = selected.isDefault;
    _preview = null;
    _error = null;
  }

  @override
  void dispose() {
    _body.dispose();
    _name.dispose();
    super.dispose();
  }

  void _startNew() {
    setState(() {
      _templates = [
        ..._templates,
        const MessageTemplate(name: '新模板', body: ''),
      ];
      _selected = _templates.length - 1;
      _loadSelected();
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.bindings.save(
        MessageTemplate(
          id: _templates[_selected].id,
          name: _name.text,
          body: _body.text,
          isEnabled: _enabled,
          isDefault: _isDefault,
        ),
      );
      await _reload(selectedId: saved.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('模板已保存')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    if (_preview == null) return;
    await Clipboard.setData(ClipboardData(text: _preview!));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('续期提示语'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _startNew,
          tooltip: '新增模板',
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
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
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${_templates[i].name}${_templates[i].isDefault ? '（默认）' : ''}',
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用模板'),
                value: _enabled,
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _enabled = value;
                        if (!value) _isDefault = false;
                      }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('设为默认模板'),
                subtitle: const Text('设置后会取消其他模板的默认状态'),
                value: _isDefault,
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _isDefault = value;
                        if (value) _enabled = true;
                      }),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _save,
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
