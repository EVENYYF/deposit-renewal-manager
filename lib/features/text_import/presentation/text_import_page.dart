import 'package:flutter/material.dart';

import '../application/parse_deposit_text.dart';
import '../domain/text_deposit_parser.dart';

/// Offline text recognition with an explicit human confirmation gate.
class TextImportPage extends StatefulWidget {
  const TextImportPage({
    super.key,
    this.parse = const ParseDepositText(TextDepositParser()),
    this.onConfirmedSave,
  });

  final ParseDepositText parse;
  final Future<void> Function(ParseResult result)? onConfirmedSave;

  @override
  State<TextImportPage> createState() => _TextImportPageState();
}

class _TextImportPageState extends State<TextImportPage> {
  final _controller = TextEditingController();
  ParseResult? _result;
  bool _confirmed = false;
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() {
      _result = _controller.text.trim().isEmpty
          ? null
          : widget.parse(_controller.text);
      _confirmed = false;
      _saved = false;
    });
  }

  Future<void> _save() async {
    final result = _result;
    if (!_confirmed || result == null || widget.onConfirmedSave == null) return;
    setState(() => _saving = true);
    try {
      await widget.onConfirmedSave!(result);
      if (mounted) {
        setState(() {
          _result = null;
          _confirmed = false;
          _saved = true;
          _controller.clear();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存客户存款信息')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final canSave = _confirmed && result != null && !_saving && !_saved;
    return Scaffold(
      appBar: AppBar(title: const Text('文字识别导入')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('粘贴客户存款描述，识别结果仅作为草稿。'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: '原始文字',
              hintText: '例如：张三 13800138000 工行 10万元 定期1年 2026-07-19',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _parse,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('识别字段'),
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            _ResultView(result: result),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (value) => setState(() => _confirmed = value ?? false),
              title: const Text('我已核对识别结果，允许写入本地数据库'),
              subtitle: result.conflicts.isNotEmpty
                  ? const Text('存在冲突字段，解决冲突后才能保存')
                  : null,
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: canSave && result.conflicts.isEmpty ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final ParseResult result;

  @override
  Widget build(BuildContext context) {
    final values = <String, Object?>{
      '姓名': result.name,
      '手机号': result.phone,
      '金额（分）': result.amountCents,
      '银行': result.bank,
      '产品': result.product,
      '利率': result.interestRatePercent,
      '起息日': result.depositDate,
      '到期日': result.expiryDate,
      '期限': result.term,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('识别预览', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in values.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                trailing: Text(entry.value?.toString() ?? '未识别'),
              ),
            if (result.conflicts.isNotEmpty)
              Text(
                '冲突字段：${result.conflicts.map((e) => e.field.name).join('、')}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
