import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../domain/import_models.dart';

typedef PickSpreadsheet = Future<PickedSpreadsheet?> Function();

class PickedSpreadsheet {
  const PickedSpreadsheet({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class ExcelImportBindings {
  const ExcelImportBindings({
    required this.preview,
    required this.resolve,
    required this.commit,
  });
  final Future<ImportPreview> Function(
    Uint8List bytes, {
    Map<String, ImportField>? mapping,
  })
  preview;
  final Future<ImportPreview> Function(ImportPreview preview) resolve;
  final Future<ImportResult> Function(
    PickedSpreadsheet file,
    ImportPreview preview,
    Map<int, DuplicateDecision> decisions,
  )
  commit;
}

class ExcelImportWizard extends StatefulWidget {
  const ExcelImportWizard({super.key, required this.bindings, this.pickFile});
  final ExcelImportBindings bindings;
  final PickSpreadsheet? pickFile;

  @override
  State<ExcelImportWizard> createState() => _ExcelImportWizardState();
}

class _ExcelImportWizardState extends State<ExcelImportWizard> {
  int _step = 0;
  bool _busy = false;
  PickedSpreadsheet? _file;
  ImportPreview? _preview;
  ImportResult? _result;
  String? _error;
  final _decisions = <int, DuplicateDecision>{};
  final _mapping = <String, ImportField>{};
  final _skippedRows = <int>{};

  Future<PickedSpreadsheet?> _defaultPick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (result == null) return null;
    final selected = result.files.single;
    final bytes = selected.bytes;
    if (bytes == null) throw StateError('无法读取所选文件');
    return PickedSpreadsheet(name: selected.name, bytes: bytes);
  }

  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await (widget.pickFile ?? _defaultPick)();
      if (file == null) return;
      final preview = await widget.bindings.preview(file.bytes);
      if (!mounted) return;
      setState(() {
        _file = file;
        _preview = preview;
        _mapping
          ..clear()
          ..addAll(preview.mapping);
        _skippedRows.clear();
        _step = 1;
        _decisions.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyMapping() async {
    final file = _file;
    if (file == null || !_mappingIsComplete) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.bindings.preview(
        file.bytes,
        mapping: Map.unmodifiable(_mapping),
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _skippedRows.clear();
        _decisions.clear();
        _step = 2;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _mappingIsComplete {
    const required = {
      ImportField.name,
      ImportField.phone,
      ImportField.amount,
      ImportField.startDate,
      ImportField.term,
    };
    return _mapping.values.toSet().containsAll(required) &&
        _mapping.values.toSet().length == _mapping.length;
  }

  ImportPreview? get _effectivePreview {
    final preview = _preview;
    if (preview == null) return null;
    return preview.copyWith(
      rows: preview.rows
          .where((row) => !_skippedRows.contains(row.rowNumber))
          .toList(growable: false),
      candidates: const [],
      duplicatesResolved: false,
    );
  }

  Future<void> _resolve() async {
    final preview = _effectivePreview;
    if (preview == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resolved = await widget.bindings.resolve(preview);
      if (!mounted) return;
      setState(() {
        _preview = resolved;
        for (final c in resolved.candidates) {
          _decisions[c.row.rowNumber] = DuplicateDecision.attachToExisting;
        }
        _step = 3;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _replaceRow(ImportRow replacement) {
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _preview = preview.copyWith(
        rows: [
          for (final row in preview.rows)
            if (row.rowNumber == replacement.rowNumber) replacement else row,
        ],
        candidates: const [],
        duplicatesResolved: false,
      );
      _skippedRows.remove(replacement.rowNumber);
      _decisions.clear();
    });
  }

  Future<void> _commit() async {
    final file = _file;
    final preview = _preview;
    if (file == null || preview == null || preview.invalidRows.isNotEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.bindings.commit(file, preview, _decisions);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Excel 批量导入')),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (value) {
          if (value <= _step) setState(() => _step = value);
        },
        controlsBuilder: (_, details) => const SizedBox.shrink(),
        steps: [
          Step(
            title: const Text('选择文件'),
            isActive: _step >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('仅支持 .xlsx，取消选择不会修改任何数据。'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _choose,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(_file == null ? '选择文件' : '重新选择'),
                ),
                if (_file != null) Text(_file!.name),
              ],
            ),
          ),
          Step(
            title: const Text('映射字段'),
            isActive: _step >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview != null) Text('为每个表头选择对应字段，未使用的列可保持“忽略”。'),
                const SizedBox(height: 8),
                if (preview != null)
                  for (final header in preview.headers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DropdownButtonFormField<ImportField?>(
                        key: ValueKey('mapping-$header'),
                        initialValue: _mapping[header],
                        decoration: InputDecoration(
                          labelText: header,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('忽略'),
                          ),
                          for (final field in ImportField.values)
                            DropdownMenuItem(
                              value: field,
                              child: Text(_fieldLabel(field)),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (field) => setState(() {
                                if (field == null) {
                                  _mapping.remove(header);
                                } else {
                                  _mapping[header] = field;
                                }
                              }),
                      ),
                    ),
                if (preview != null && !_mappingIsComplete)
                  Text(
                    '姓名、手机号、金额、起息日和期限必须各映射一次。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: preview == null || !_mappingIsComplete || _busy
                      ? null
                      : _applyMapping,
                  child: const Text('确认映射'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('校验预览'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview != null)
                  Text(
                    '有效 ${preview.validRows.length} 行，错误 ${preview.invalidRows.length} 行',
                  ),
                if (preview != null)
                  for (final row in preview.invalidRows)
                    _InvalidRowTile(
                      row: row,
                      skipped: _skippedRows.contains(row.rowNumber),
                      onSkipChanged: (skip) => setState(() {
                        if (skip) {
                          _skippedRows.add(row.rowNumber);
                        } else {
                          _skippedRows.remove(row.rowNumber);
                        }
                      }),
                      onCorrected: _replaceRow,
                    ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed:
                      preview == null ||
                          preview.invalidRows.any(
                            (row) => !_skippedRows.contains(row.rowNumber),
                          ) ||
                          _busy
                      ? null
                      : _resolve,
                  child: const Text('检查重复客户'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('处理重复'),
            isActive: _step >= 3,
            content: Column(
              children: [
                if (preview != null && preview.candidates.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('没有重复客户'),
                  ),
                if (preview != null)
                  if (preview.candidates.length > 1)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MenuAnchor(
                        builder: (context, controller, child) =>
                            OutlinedButton.icon(
                              onPressed: () => controller.isOpen
                                  ? controller.close()
                                  : controller.open(),
                              icon: const Icon(Icons.playlist_add_check),
                              label: const Text('批量应用处理方式'),
                            ),
                        menuChildren: [
                          for (final decision in DuplicateDecision.values)
                            MenuItemButton(
                              onPressed: () => setState(() {
                                for (final candidate in preview.candidates) {
                                  _decisions[candidate.row.rowNumber] =
                                      decision;
                                }
                              }),
                              child: Text(_decisionLabel(decision)),
                            ),
                        ],
                      ),
                    ),
                if (preview != null)
                  for (final candidate in preview.candidates)
                    _DuplicateDecisionTile(
                      candidate: candidate,
                      value: _decisions[candidate.row.rowNumber],
                      onChanged: (value) => setState(
                        () => _decisions[candidate.row.rowNumber] = value,
                      ),
                    ),
                FilledButton(
                  onPressed:
                      preview == null ||
                          preview.candidates.any(
                            (c) => !_decisions.containsKey(c.row.rowNumber),
                          )
                      ? null
                      : () => setState(() => _step = 4),
                  child: const Text('确认重复处理'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('确认导入'),
            isActive: _step >= 4,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('导入前会自动创建本地快照。'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed:
                      _busy || preview == null || preview.invalidRows.isNotEmpty
                      ? null
                      : _commit,
                  icon: const Icon(Icons.file_download_done_outlined),
                  label: const Text('确认导入'),
                ),
                if (_result != null)
                  Text(
                    '已导入 ${_result!.importedRows} 行，跳过 '
                    '${_result!.skippedRows + _skippedRows.length} 行',
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _error == null
          ? null
          : Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
    );
  }
}

String _fieldLabel(ImportField field) => switch (field) {
  ImportField.name => '姓名',
  ImportField.phone => '手机号',
  ImportField.amount => '金额（元）',
  ImportField.bankName => '银行',
  ImportField.interestRate => '利率（%）',
  ImportField.startDate => '起息日',
  ImportField.term => '期限（月）',
  ImportField.expiryMode => '到期方式',
};

String _decisionLabel(DuplicateDecision decision) => switch (decision) {
  DuplicateDecision.attachToExisting => '全部归入已有客户',
  DuplicateDecision.createSeparate => '全部新增独立客户',
  DuplicateDecision.skip => '全部跳过',
};

class _InvalidRowTile extends StatelessWidget {
  const _InvalidRowTile({
    required this.row,
    required this.skipped,
    required this.onSkipChanged,
    required this.onCorrected,
  });

  final ImportRow row;
  final bool skipped;
  final ValueChanged<bool> onSkipChanged;
  final ValueChanged<ImportRow> onCorrected;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '第 ${row.rowNumber} 行',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            row.errors.join('；'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: skipped ? null : () => _edit(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('修正此行'),
              ),
              FilterChip(
                selected: skipped,
                onSelected: onSkipChanged,
                label: const Text('跳过此行'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<ImportRow>(
      context: context,
      builder: (_) => _RowCorrectionDialog(row: row),
    );
    if (result != null) onCorrected(result);
  }
}

class _RowCorrectionDialog extends StatefulWidget {
  const _RowCorrectionDialog({required this.row});
  final ImportRow row;

  @override
  State<_RowCorrectionDialog> createState() => _RowCorrectionDialogState();
}

class _RowCorrectionDialogState extends State<_RowCorrectionDialog> {
  late final Map<String, TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = widget.row.normalized;
    _controllers = {
      'name': TextEditingController(text: n['name']?.toString()),
      'phone': TextEditingController(text: n['phone']?.toString()),
      'amount': TextEditingController(
        text: n['amountCents'] is int
            ? ((n['amountCents'] as int) / 100).toString()
            : n['amount']?.toString(),
      ),
      'startDate': TextEditingController(text: n['startDate']?.toString()),
      'term': TextEditingController(text: n['term']?.toString()),
      'interestRate': TextEditingController(
        text: n['interestRateScaled'] is int
            ? ((n['interestRateScaled'] as int) / 100).toString()
            : n['interestRate']?.toString(),
      ),
      'bankName': TextEditingController(text: n['bankName']?.toString()),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _controllers['name']!.text.trim();
    final phone = _controllers['phone']!.text.replaceAll(RegExp(r'[ -]'), '');
    final amount = double.tryParse(_controllers['amount']!.text.trim());
    final date = parseImportDate(_controllers['startDate']!.text.trim());
    final term = int.tryParse(_controllers['term']!.text.trim());
    final rate = double.tryParse(_controllers['interestRate']!.text.trim());
    if (name.isEmpty ||
        !RegExp(r'^1[3-9]\d{9}$').hasMatch(phone) ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        date == null ||
        term == null ||
        term <= 0 ||
        rate == null ||
        !rate.isFinite ||
        rate < 0 ||
        rate > 100) {
      setState(() => _error = '请填写有效的姓名、手机号、金额、日期、期限和利率。');
      return;
    }
    final normalized = Map<String, Object?>.from(widget.row.normalized)
      ..addAll({
        'name': name,
        'phone': phone,
        'amountCents': (amount * 100).round(),
        'startDate': date.toString(),
        'term': term,
        'interestRateScaled': (rate * 100).round(),
        'ratePrecision': 2,
        'bankName': _controllers['bankName']!.text.trim(),
      });
    Navigator.of(context).pop(
      ImportRow(
        rowNumber: widget.row.rowNumber,
        raw: widget.row.raw,
        normalized: normalized,
        warnings: widget.row.warnings,
        availableDecisions: const {DuplicateDecision.createSeparate},
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('修正第 ${widget.row.rowNumber} 行'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in const [
            ('name', '姓名'),
            ('phone', '手机号'),
            ('amount', '金额（元）'),
            ('startDate', '起息日（YYYY-MM-DD）'),
            ('term', '期限（月）'),
            ('interestRate', '利率（%）'),
            ('bankName', '银行'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: ValueKey('correct-${entry.$1}'),
                controller: _controllers[entry.$1],
                decoration: InputDecoration(
                  labelText: entry.$2,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _save, child: const Text('应用修正')),
    ],
  );
}

class _DuplicateDecisionTile extends StatelessWidget {
  const _DuplicateDecisionTile({
    required this.candidate,
    required this.value,
    required this.onChanged,
  });
  final DuplicateCandidate candidate;
  final DuplicateDecision? value;
  final ValueChanged<DuplicateDecision> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('第 ${candidate.row.rowNumber} 行：手机号与已有客户重复'),
          RadioGroup<DuplicateDecision>(
            groupValue: value,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            child: const Column(
              children: [
                RadioListTile(
                  value: DuplicateDecision.attachToExisting,
                  title: Text('归入已有客户'),
                ),
                RadioListTile(
                  value: DuplicateDecision.createSeparate,
                  title: Text('新增独立客户'),
                ),
                RadioListTile(
                  value: DuplicateDecision.skip,
                  title: Text('跳过此行'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
