import 'package:flutter/material.dart';

import '../../deposits/domain/expiry_calculator.dart';
import '../../deposits/domain/local_date.dart';
import '../application/parse_deposit_text.dart';
import '../domain/text_deposit_parser.dart';

/// Offline text recognition with editable fields and an explicit confirmation gate.
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
  final _sourceController = TextEditingController();
  final _fieldControllers = <ParseField, TextEditingController>{};
  ParseResult? _result;
  String _termUnit = 'months';
  bool _confirmed = false;
  bool _draftApplied = false;
  bool _saving = false;
  bool _saved = false;
  String? _editError;

  @override
  void dispose() {
    _sourceController.dispose();
    _disposeFieldControllers();
    super.dispose();
  }

  void _disposeFieldControllers() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    _fieldControllers.clear();
  }

  void _parse() {
    final source = _sourceController.text.trim();
    final result = source.isEmpty ? null : widget.parse(source);
    _disposeFieldControllers();
    if (result != null) {
      for (final field in ParseField.values) {
        _fieldControllers[field] = TextEditingController(
          text: _displayValue(result, field),
        );
      }
      final term = _firstValue(result, ParseField.term);
      _termUnit = switch (term) {
        DayTerm() => 'days',
        YearTerm() => 'years',
        _ => 'months',
      };
    }
    setState(() {
      _result = result;
      _confirmed = false;
      _draftApplied = result != null && result.conflicts.isEmpty;
      _saved = false;
      _editError = null;
    });
  }

  void _markDirty() {
    if (_draftApplied || _confirmed || _editError != null) {
      setState(() {
        _draftApplied = false;
        _confirmed = false;
        _editError = null;
      });
    }
  }

  void _applyEdits() {
    final original = _result;
    if (original == null) return;
    try {
      final candidates = <ParseCandidate>[];
      void add(ParseField field, Object? value) {
        if (value == null || (value is String && value.trim().isEmpty)) return;
        candidates.add(
          ParseCandidate(
            field: field,
            value: value,
            source: _fieldControllers[field]!.text.trim(),
            confidence: 1,
            sourceStart: 0,
            sourceEnd: 0,
          ),
        );
      }

      final name = _text(ParseField.name);
      final phone = _text(ParseField.phone).replaceAll(RegExp(r'[ -]'), '');
      final amountYuan = double.tryParse(_text(ParseField.amount));
      final rate = _optionalDouble(ParseField.interestRate);
      final depositDate = _optionalDate(ParseField.depositDate);
      final expiryDate = _optionalDate(ParseField.expiryDate);
      final termValue = int.tryParse(_text(ParseField.term));
      if (name.isEmpty ||
          amountYuan == null ||
          !amountYuan.isFinite ||
          amountYuan <= 0 ||
          depositDate == null ||
          (expiryDate == null && (termValue == null || termValue <= 0))) {
        throw const FormatException('姓名、金额、存入日期，以及期限或到期日必须有效。');
      }
      if (phone.isNotEmpty && !RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
        throw const FormatException('手机号格式不正确。');
      }
      if (rate != null && (rate < 0 || rate > 100)) {
        throw const FormatException('利率应在 0 到 100 之间。');
      }

      add(ParseField.name, name);
      add(ParseField.phone, phone);
      add(ParseField.amount, (amountYuan * 100).round());
      add(ParseField.bank, _text(ParseField.bank));
      add(ParseField.product, _text(ParseField.product));
      add(ParseField.interestRate, rate);
      add(ParseField.depositDate, depositDate);
      add(ParseField.expiryDate, expiryDate);
      if (termValue != null && termValue > 0) {
        add(ParseField.term, switch (_termUnit) {
          'days' => DepositTerm.days(termValue),
          'years' => DepositTerm.years(termValue),
          _ => DepositTerm.months(termValue),
        });
      }
      setState(() {
        _result = ParseResult(
          original: original.original,
          candidates: List.unmodifiable(candidates),
          conflicts: const [],
          remainingText: original.remainingText,
        );
        _draftApplied = true;
        _confirmed = false;
        _editError = null;
      });
    } on FormatException catch (error) {
      setState(() => _editError = error.message);
    }
  }

  String _text(ParseField field) => _fieldControllers[field]!.text.trim();

  double? _optionalDouble(ParseField field) {
    final value = _text(field);
    if (value.isEmpty) return null;
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('${_fieldLabel(field)}格式不正确。');
    }
    return parsed;
  }

  LocalDate? _optionalDate(ParseField field) {
    final value = _text(field);
    if (value.isEmpty) return null;
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('${_fieldLabel(field)}格式应为 YYYY-MM-DD。');
    }
    try {
      return LocalDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } catch (_) {
      throw FormatException('${_fieldLabel(field)}不是有效日期。');
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (!_confirmed ||
        !_draftApplied ||
        result == null ||
        widget.onConfirmedSave == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onConfirmedSave!(result);
      if (mounted) {
        _disposeFieldControllers();
        setState(() {
          _result = null;
          _confirmed = false;
          _draftApplied = false;
          _saved = true;
          _sourceController.clear();
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
    final canSave =
        _confirmed &&
        _draftApplied &&
        result != null &&
        !_saving &&
        !_saved &&
        result.conflicts.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('文字识别导入')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('粘贴客户存款描述，识别结果仅作为草稿。'),
          const SizedBox(height: 8),
          TextField(
            controller: _sourceController,
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
            _EditableResult(
              result: result,
              controllers: _fieldControllers,
              termUnit: _termUnit,
              onTermUnitChanged: (value) {
                setState(() => _termUnit = value);
                _markDirty();
              },
              onChanged: _markDirty,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _applyEdits,
              icon: const Icon(Icons.check_outlined),
              label: Text(result.conflicts.isEmpty ? '应用字段修改' : '确认字段并消除冲突'),
            ),
            if (_editError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _editError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: _draftApplied
                  ? (value) => setState(() => _confirmed = value ?? false)
                  : null,
              title: const Text('我已核对识别结果，允许写入本地数据库'),
              subtitle: !_draftApplied ? const Text('请先应用字段修改并解决冲突') : null,
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: canSave ? _save : null,
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

class _EditableResult extends StatelessWidget {
  const _EditableResult({
    required this.result,
    required this.controllers,
    required this.termUnit,
    required this.onTermUnitChanged,
    required this.onChanged,
  });

  final ParseResult result;
  final Map<ParseField, TextEditingController> controllers;
  final String termUnit;
  final ValueChanged<String> onTermUnitChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final conflictFields = result.conflicts
        .map((conflict) => conflict.field)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('识别结果', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final field in ParseField.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: field == ParseField.term
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _field(context, field, conflictFields)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 112,
                        child: DropdownButtonFormField<String>(
                          initialValue: termUnit,
                          decoration: const InputDecoration(
                            labelText: '期限单位',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'days', child: Text('天')),
                            DropdownMenuItem(value: 'months', child: Text('月')),
                            DropdownMenuItem(value: 'years', child: Text('年')),
                          ],
                          onChanged: (value) {
                            if (value != null) onTermUnitChanged(value);
                          },
                        ),
                      ),
                    ],
                  )
                : _field(context, field, conflictFields),
          ),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    ParseField field,
    Set<ParseField> conflictFields,
  ) => TextField(
    key: ValueKey('parsed-${field.name}'),
    controller: controllers[field],
    onChanged: (_) => onChanged(),
    decoration: InputDecoration(
      labelText: _fieldLabel(field),
      helperText: conflictFields.contains(field) ? '检测到多个候选，请确认此值' : null,
      helperStyle: conflictFields.contains(field)
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
      border: const OutlineInputBorder(),
    ),
  );
}

String _fieldLabel(ParseField field) => switch (field) {
  ParseField.name => '姓名',
  ParseField.phone => '手机号',
  ParseField.amount => '金额（元）',
  ParseField.bank => '银行',
  ParseField.product => '产品',
  ParseField.interestRate => '利率（%）',
  ParseField.depositDate => '存入日期（YYYY-MM-DD）',
  ParseField.expiryDate => '到期日期（YYYY-MM-DD）',
  ParseField.term => '期限',
};

Object? _firstValue(ParseResult result, ParseField field) {
  for (final candidate in result.candidates) {
    if (candidate.field == field && candidate.isValid) return candidate.value;
  }
  return null;
}

String _displayValue(ParseResult result, ParseField field) {
  final value = _firstValue(result, field);
  return switch (value) {
    null => '',
    int cents when field == ParseField.amount => (cents / 100).toString(),
    DepositTerm(:final value) => value.toString(),
    _ => value.toString(),
  };
}
