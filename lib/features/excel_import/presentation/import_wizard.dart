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
  final Future<ImportPreview> Function(Uint8List bytes) preview;
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
        _step = 1;
        _decisions.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    final preview = _preview;
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
                if (preview != null)
                  Text(
                    '已识别 ${preview.mapping.length} 个字段：${preview.mapping.keys.join('、')}',
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: preview == null
                      ? null
                      : () => setState(() => _step = 2),
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
                if (preview != null && preview.invalidRows.isNotEmpty)
                  const Text('错误行需修正源文件或移除后重新选择。'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed:
                      preview == null || preview.invalidRows.isNotEmpty || _busy
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
                    '已导入 ${_result!.importedRows} 行，跳过 ${_result!.skippedRows} 行',
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
