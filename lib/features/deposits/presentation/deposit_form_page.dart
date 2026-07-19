import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../customers/application/customer_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../application/deposit_workflow_controller.dart';
import '../domain/deposit_repository.dart';
import '../domain/expiry_calculator.dart';
import '../domain/local_date.dart';

enum DepositFormMode { create, update, renew }

class DepositFormPage extends ConsumerStatefulWidget {
  const DepositFormPage({
    this.mode = DepositFormMode.create,
    this.sourceDepositId,
    this.initial,
    this.initialCustomerId,
    this.onSaved,
    super.key,
  });

  final DepositFormMode mode;
  final String? sourceDepositId;
  final DepositDraft? initial;
  final String? initialCustomerId;
  final VoidCallback? onSaved;

  @override
  ConsumerState<DepositFormPage> createState() => _DepositFormPageState();
}

class _DepositFormPageState extends ConsumerState<DepositFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customer;
  late final TextEditingController _amount;
  late final TextEditingController _bank;
  late final TextEditingController _rate;
  late final TextEditingController _start;
  late final TextEditingController _expiry;
  late final TextEditingController _term;
  bool _automatic = true;
  bool _expiryAdjusted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _automatic = initial?.calculatedExpiryDate != null;
    _customer = TextEditingController(
      text: initial?.customerId ?? widget.initialCustomerId ?? '',
    );
    _amount = TextEditingController(
      text: initial == null
          ? ''
          : (initial.amountCents / 100).toStringAsFixed(2),
    );
    _bank = TextEditingController(text: initial?.bankName ?? '');
    _rate = TextEditingController(
      text: initial == null
          ? ''
          : (initial.interestRateScaled / 10000).toString(),
    );
    _start = TextEditingController(text: initial?.startDate.toString() ?? '');
    _expiry = TextEditingController(
      text: initial?.finalExpiryDate.toString() ?? '',
    );
    _term = TextEditingController(text: '12');
  }

  @override
  void dispose() {
    for (final controller in [
      _customer,
      _amount,
      _bank,
      _rate,
      _start,
      _expiry,
      _term,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text(_title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              label: Text('自动计算'),
              icon: Icon(Icons.calculate_outlined),
            ),
            ButtonSegment(
              value: false,
              label: Text('直接填写'),
              icon: Icon(Icons.edit_calendar_outlined),
            ),
          ],
          selected: {_automatic},
          onSelectionChanged: (value) =>
              setState(() => _automatic = value.single),
        ),
        const SizedBox(height: 16),
        _field(_customer, '客户编号', required: true),
        _field(
          _amount,
          '金额（元）',
          required: true,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        _field(_bank, '银行'),
        _field(
          _rate,
          '年利率（%）',
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        _field(_start, '存入日期', required: true, hint: 'YYYY-MM-DD'),
        if (_automatic)
          _field(
            _term,
            '存期（月）',
            required: true,
            keyboard: TextInputType.number,
            onChanged: (_) => _calculateExpiry(),
          ),
        _field(
          _expiry,
          '最终到期日',
          required: true,
          hint: 'YYYY-MM-DD',
          onChanged: (_) => setState(() => _expiryAdjusted = _automatic),
        ),
        if (_automatic && _expiryAdjusted)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 8),
                Text('到期日已人工调整'),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? '保存中' : _buttonLabel),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? hint,
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: onChanged,
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? '请填写$label' : null
          : null,
    ),
  );

  String get _title => switch (widget.mode) {
    DepositFormMode.create => '新增存款',
    DepositFormMode.update => '更新存款',
    DepositFormMode.renew => '续期',
  };

  String get _buttonLabel =>
      widget.mode == DepositFormMode.renew ? '确认续期' : '保存';

  void _calculateExpiry() {
    try {
      final start = _parseDate(_start.text);
      final term = int.parse(_term.text);
      _expiry.text = ExpiryCalculator()
          .calculate(start, DepositTerm.months(term))
          .toString();
      setState(() => _expiryAdjusted = false);
    } catch (_) {
      // 输入尚未完整时保留当前内容，由表单提交统一校验。
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final amountCents = (double.parse(_amount.text) * 100).round();
      final rateScaled = ((double.tryParse(_rate.text) ?? 0) * 10000).round();
      final start = _parseDate(_start.text);
      final expiry = _parseDate(_expiry.text);
      final calculated = _automatic
          ? ExpiryCalculator().calculate(
              start,
              DepositTerm.months(int.parse(_term.text)),
            )
          : null;
      final draft = DepositDraft(
        id: widget.mode == DepositFormMode.update
            ? widget.initial!.id
            : const Uuid().v4(),
        customerId: _customer.text.trim(),
        amountCents: amountCents,
        bankName: _bank.text,
        interestRateScaled: rateScaled,
        ratePrecision: 4,
        startDate: start,
        calculatedExpiryDate: calculated,
        finalExpiryDate: expiry,
      );
      setState(() => _saving = true);
      final workflow = ref.read(depositWorkflowProvider);
      switch (widget.mode) {
        case DepositFormMode.create:
          await workflow.create(draft);
        case DepositFormMode.update:
          await workflow.update(widget.sourceDepositId ?? draft.id, draft);
        case DepositFormMode.renew:
          await workflow.renew(widget.sourceDepositId!, draft);
      }
      if (mounted) {
        ref.invalidate(customerControllerProvider);
        ref.invalidate(dashboardControllerProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存')));
        widget.onSaved?.call();
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  LocalDate _parseDate(String value) {
    final parts = value.trim().split('-');
    if (parts.length != 3) throw const FormatException('日期格式应为 YYYY-MM-DD');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
