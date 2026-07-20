import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_dependencies.dart';
import '../../customers/application/customer_controller.dart';
import '../../customers/domain/customer_repository.dart';
import '../../customers/domain/name_search_index.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../application/deposit_workflow_controller.dart';
import '../domain/deposit_preset_repository.dart';
import '../domain/deposit_repository.dart';
import '../domain/expiry_calculator.dart';
import '../domain/local_date.dart';
import '../domain/product_catalog_repository.dart';

enum DepositFormMode { create, update, renew }

class DepositFormPage extends ConsumerStatefulWidget {
  const DepositFormPage({
    this.mode = DepositFormMode.create,
    this.sourceDepositId,
    this.initial,
    this.initialCustomerId,
    this.initialCustomerName,
    this.initialCustomerPhone,
    this.onSaved,
    super.key,
  });

  final DepositFormMode mode;
  final String? sourceDepositId;
  final DepositDraft? initial;
  final String? initialCustomerId;
  final String? initialCustomerName;
  final String? initialCustomerPhone;
  final VoidCallback? onSaved;

  @override
  ConsumerState<DepositFormPage> createState() => _DepositFormPageState();
}

class _DepositFormPageState extends ConsumerState<DepositFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerName;
  late final TextEditingController _customerPhone;
  late final TextEditingController _amount;
  late final TextEditingController _bank;
  late final TextEditingController _product;
  late final TextEditingController _rate;
  late final TextEditingController _start;
  late final TextEditingController _expiry;
  late final TextEditingController _term;
  String? _selectedCustomerId;
  List<CustomerSearchResult> _customerMatches = const [];
  Map<DepositPresetField, List<String>> _presets = const {};
  DepositTermUnit _termUnit = DepositTermUnit.month;
  bool _automatic = true;
  bool _expiryAdjusted = false;
  bool _saving = false;
  bool _searchingCustomers = false;
  int _customerSearchGeneration = 0;
  late int _ratePrecision;
  List<String> _catalogBanks = const [];
  List<ProductRecord> _catalogProducts = const [];
  String? _selectedProductId;
  bool _rateManuallyEdited = false;
  String? _rateMatchMessage;
  int _catalogGeneration = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _automatic = initial == null || initial.calculatedExpiryDate != null;
    _ratePrecision = initial?.ratePrecision ?? 2;
    _selectedCustomerId = initial?.customerId ?? widget.initialCustomerId;
    _customerName = TextEditingController(
      text: widget.initialCustomerName ?? '',
    );
    _customerPhone = TextEditingController(
      text: widget.initialCustomerPhone ?? '',
    );
    _amount = TextEditingController(
      text: initial == null
          ? ''
          : (initial.amountCents / 100).toStringAsFixed(2),
    );
    _bank = TextEditingController(text: initial?.bankName ?? '');
    _product = TextEditingController(text: initial?.productName ?? '');
    _rate = TextEditingController(text: _formatRate(initial));
    _start = TextEditingController(text: initial?.startDate.toString() ?? '');
    _expiry = TextEditingController(
      text: initial?.finalExpiryDate.toString() ?? '',
    );
    _term = TextEditingController(text: initial?.termValue?.toString() ?? '12');
    _termUnit = initial?.termUnit ?? DepositTermUnit.month;
    Future<void>.microtask(_loadPresets);
    Future<void>.microtask(_loadCatalog);
  }

  @override
  void dispose() {
    _customerSearchGeneration++;
    for (final controller in [
      _customerName,
      _customerPhone,
      _amount,
      _bank,
      _product,
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
        if (widget.mode == DepositFormMode.renew) ...[
          const SizedBox(height: 12),
          _RenewalSourceSummary(
            customerName: widget.initialCustomerName ?? '当前客户',
            customerPhone: widget.initialCustomerPhone,
            draft: widget.initial!,
          ),
        ],
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
          onSelectionChanged: (value) {
            setState(() => _automatic = value.single);
            if (_automatic) _calculateExpiry();
          },
        ),
        const SizedBox(height: 16),
        _customerFields(),
        _presetField(
          _amount,
          '金额（元）',
          DepositPresetField.amount,
          required: true,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        _presetField(
          _bank,
          '银行',
          DepositPresetField.bank,
          onChanged: _onBankChanged,
          onCandidateSelected: _selectBank,
        ),
        _presetField(
          _product,
          '产品名称',
          DepositPresetField.product,
          onChanged: _onProductChanged,
          onCandidateSelected: _selectProductByName,
        ),
        if (_similarProducts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '发现相似产品：${_similarProducts.join('、')}，请确认名称后再保存',
              key: const Key('similar-product-warning'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        _presetField(
          _rate,
          '年利率（%）',
          DepositPresetField.rate,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          onChanged: _markRateEdited,
        ),
        if (_rateMatchMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _rateMatchMessage!,
              key: const Key('catalog-rate-message'),
            ),
          ),
        _dateField(_start, '存入日期', onSelected: _onStartDateChanged),
        if (_automatic) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _presetField(
                  _term,
                  '存期',
                  DepositPresetField.term,
                  required: true,
                  keyboard: TextInputType.number,
                  onChanged: (_) => _calculateExpiry(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 112,
                child: DropdownButtonFormField<DepositTermUnit>(
                  key: const Key('term-unit'),
                  initialValue: _termUnit,
                  decoration: const InputDecoration(labelText: '单位'),
                  items: DepositTermUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(_termUnitLabel(unit)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (unit) {
                    if (unit == null) return;
                    setState(() => _termUnit = unit);
                    _calculateExpiry();
                  },
                ),
              ),
            ],
          ),
        ],
        _dateField(
          _expiry,
          '最终到期日',
          onSelected: (_) => setState(() => _expiryAdjusted = _automatic),
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

  Widget _customerFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextFormField(
        key: const Key('customer-name'),
        controller: _customerName,
        readOnly: widget.mode == DepositFormMode.renew,
        decoration: InputDecoration(
          labelText: '客户姓名',
          suffixIcon: _searchingCustomers
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.person_search_outlined),
        ),
        onChanged: (value) {
          _selectedCustomerId = null;
          _searchCustomers(value);
        },
        validator: (value) =>
            value == null || value.trim().isEmpty ? '请填写客户姓名' : null,
      ),
      if (_customerMatches.isNotEmpty && widget.mode != DepositFormMode.renew)
        Card(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          child: Column(
            children: _customerMatches
                .take(5)
                .map(
                  (result) => ListTile(
                    dense: true,
                    title: Text(_customerLabel(result.customer)),
                    onTap: () => _selectCustomer(result.customer),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      const SizedBox(height: 12),
      TextFormField(
        key: const Key('customer-phone'),
        controller: _customerPhone,
        readOnly: widget.mode == DepositFormMode.renew,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: '手机号（选填）'),
        onChanged: (value) {
          if (_selectedCustomerId != null) _selectedCustomerId = null;
          _searchCustomers(value);
        },
      ),
      if (_selectedCustomerId == null && widget.mode == DepositFormMode.create)
        const Padding(
          padding: EdgeInsets.only(top: 6, bottom: 8),
          child: Text('未选择已有客户，保存时将新建客户。'),
        ),
      const SizedBox(height: 4),
    ],
  );

  Widget _presetField(
    TextEditingController controller,
    String label,
    DepositPresetField field, {
    bool required = false,
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onCandidateSelected,
  }) {
    final values = _orderedCandidates(field, controller.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: Key('deposit-${field.name}'),
            controller: controller,
            keyboardType: keyboard,
            decoration: InputDecoration(labelText: label),
            onChanged: (value) {
              onChanged?.call(value);
              setState(() {});
            },
            validator: required
                ? (value) =>
                      value == null || value.trim().isEmpty ? '请填写$label' : null
                : null,
          ),
          if (values.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: values
                    .take(5)
                    .map(
                      (value) => ActionChip(
                        label: Text(value),
                        onPressed: () {
                          controller.text = value;
                          controller.selection = TextSelection.collapsed(
                            offset: value.length,
                          );
                          (onCandidateSelected ?? onChanged)?.call(value);
                          setState(() {});
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateField(
    TextEditingController controller,
    String label, {
    required ValueChanged<LocalDate> onSelected,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: Key(label == '存入日期' ? 'start-date' : 'expiry-date'),
      controller: controller,
      // 点击时优先使用日期选择器；保留文本输入以兼容键盘和桌面端录入。
      readOnly: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM-DD',
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: _tryDateTime(controller.text) ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
        );
        if (selected == null) return;
        final local = LocalDate(selected.year, selected.month, selected.day);
        controller.text = local.toString();
        onSelected(local);
      },
      onChanged: (_) {
        try {
          onSelected(_parseDate(controller.text));
        } catch (_) {}
      },
      validator: (value) =>
          value == null || value.trim().isEmpty ? '请选择$label' : null,
    ),
  );

  String get _title => switch (widget.mode) {
    DepositFormMode.create => '新增存款',
    DepositFormMode.update => '更新存款',
    DepositFormMode.renew => '续期',
  };

  String get _buttonLabel =>
      widget.mode == DepositFormMode.renew ? '确认续期' : '保存';

  Future<void> _loadPresets() async {
    try {
      final service = ref.read(depositPresetServiceProvider);
      final entries = await Future.wait(
        DepositPresetField.values.map(
          (field) async => MapEntry(field, await service.candidates(field)),
        ),
      );
      if (mounted) setState(() => _presets = Map.fromEntries(entries));
    } catch (_) {
      // 预设不可用不应阻止存款录入。
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final service = ref.read(productCatalogServiceProvider);
      final banks = await service.activeBanks();
      if (!mounted) return;
      setState(() => _catalogBanks = banks);
      if (_bank.text.trim().isNotEmpty) {
        await _loadProductsForBank(_bank.text, associateOnly: true);
      }
    } catch (_) {
      // 产品目录不可用时仍保留原有手工录入。
    }
  }

  Future<void> _loadProductsForBank(
    String bankName, {
    bool associateOnly = false,
  }) async {
    final generation = ++_catalogGeneration;
    try {
      final products = await ref
          .read(productCatalogServiceProvider)
          .activeProductsForBank(bankName);
      if (!mounted || generation != _catalogGeneration) return;
      final selected = products.where(
        (item) =>
            item.productName.toLowerCase() ==
            _product.text.trim().toLowerCase(),
      );
      setState(() {
        _catalogProducts = products;
        _selectedProductId = selected.isEmpty ? null : selected.first.id;
        if (!associateOnly) _rateMatchMessage = null;
      });
    } catch (_) {
      if (mounted && generation == _catalogGeneration) {
        setState(() {
          _catalogProducts = const [];
          _selectedProductId = null;
        });
      }
    }
  }

  void _onBankChanged(String value) {
    _selectedProductId = null;
    _rateMatchMessage = null;
    _loadProductsForBank(value);
  }

  void _selectBank(String value) {
    _bank.text = value;
    _onBankChanged(value);
  }

  void _onProductChanged(String value) {
    final matches = _catalogProducts.where(
      (item) => item.productName.toLowerCase() == value.trim().toLowerCase(),
    );
    _selectedProductId = matches.isEmpty ? null : matches.first.id;
    _matchCatalogRate(allowOverwrite: !_rateManuallyEdited);
  }

  void _selectProductByName(String value) {
    _product.text = value;
    _rateManuallyEdited = false;
    _onProductChanged(value);
    _matchCatalogRate(allowOverwrite: true);
  }

  void _markRateEdited(String value) {
    _rateManuallyEdited = true;
    setState(() => _rateMatchMessage = null);
  }

  void _onStartDateChanged(LocalDate value) {
    _calculateExpiry();
    _matchCatalogRate(allowOverwrite: !_rateManuallyEdited);
  }

  Future<void> _matchCatalogRate({required bool allowOverwrite}) async {
    final productId = _selectedProductId;
    if (productId == null) return;
    try {
      final start = _parseDate(_start.text);
      final matched = await ref
          .read(productCatalogServiceProvider)
          .matchRate(productId, start);
      if (!mounted || productId != _selectedProductId) return;
      setState(() {
        if (matched == null) {
          _rateMatchMessage = '该存入日期没有可用的产品利率，请手动填写';
          return;
        }
        _rateMatchMessage = '已匹配 ${matched.effectiveDate} 生效的产品利率';
        if (allowOverwrite) {
          _ratePrecision = matched.ratePrecision;
          _rate.text =
              (matched.interestRateScaled / _scaleFor(matched.ratePrecision))
                  .toStringAsFixed(matched.ratePrecision);
        }
      });
    } catch (_) {}
  }

  Future<void> _searchCustomers(String query) async {
    final generation = ++_customerSearchGeneration;
    final normalized = query.trim();
    if (normalized.isEmpty || widget.mode == DepositFormMode.renew) {
      setState(() {
        _customerMatches = const [];
        _searchingCustomers = false;
      });
      return;
    }
    setState(() => _searchingCustomers = true);
    try {
      final results = await ref.read(customerUseCasesProvider).load(normalized);
      if (!mounted || generation != _customerSearchGeneration) return;
      setState(() {
        _customerMatches = results;
        _searchingCustomers = false;
      });
    } catch (_) {
      if (mounted && generation == _customerSearchGeneration) {
        setState(() {
          _customerMatches = const [];
          _searchingCustomers = false;
        });
      }
    }
  }

  void _selectCustomer(CustomerRecord customer) {
    _customerSearchGeneration++;
    setState(() {
      _selectedCustomerId = customer.id;
      _customerName.text = customer.name;
      _customerPhone.text = customer.phone ?? '';
      _customerMatches = const [];
      _searchingCustomers = false;
    });
  }

  void _calculateExpiry() {
    if (!_automatic) return;
    try {
      final start = _parseDate(_start.text);
      final value = int.parse(_term.text);
      final term = switch (_termUnit) {
        DepositTermUnit.day => DepositTerm.days(value),
        DepositTermUnit.month => DepositTerm.months(value),
        DepositTermUnit.year => DepositTerm.years(value),
      };
      _expiry.text = ExpiryCalculator().calculate(start, term).toString();
      setState(() => _expiryAdjusted = false);
    } catch (_) {
      // 输入尚未完整时保留当前内容，由表单提交统一校验。
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null && widget.mode != DepositFormMode.create) {
      _showError('更新存款时请从搜索结果中选择已有客户');
      return;
    }
    try {
      final amountCents = (double.parse(_amount.text) * 100).round();
      final rateScaled =
          ((double.tryParse(_rate.text) ?? 0) * _scaleFor(_ratePrecision))
              .round();
      final start = _parseDate(_start.text);
      final expiry = _parseDate(_expiry.text);
      final termValue = _automatic ? int.parse(_term.text) : null;
      if (termValue != null && termValue <= 0) {
        throw const FormatException('存期必须大于 0');
      }
      var customerId = _selectedCustomerId;
      var createCustomer = customerId == null;
      if (createCustomer && widget.mode == DepositFormMode.create) {
        final duplicate = await _findExactCustomer();
        if (duplicate != null && mounted) {
          final useExisting = await _confirmDuplicateCustomer(duplicate);
          if (useExisting == null) return;
          if (useExisting) {
            customerId = duplicate.id;
            createCustomer = false;
            _selectCustomer(duplicate);
          }
        }
      }
      customerId ??= const Uuid().v4();
      final calculated = _automatic
          ? ExpiryCalculator().calculate(start, switch (_termUnit) {
              DepositTermUnit.day => DepositTerm.days(termValue!),
              DepositTermUnit.month => DepositTerm.months(termValue!),
              DepositTermUnit.year => DepositTerm.years(termValue!),
            })
          : null;
      final draft = DepositDraft(
        id: widget.mode == DepositFormMode.update
            ? widget.initial!.id
            : const Uuid().v4(),
        customerId: customerId,
        amountCents: amountCents,
        bankName: _bank.text.trim(),
        productName: _product.text.trim(),
        termValue: termValue,
        termUnit: _automatic ? _termUnit : null,
        interestRateScaled: rateScaled,
        ratePrecision: _ratePrecision,
        startDate: start,
        calculatedExpiryDate: calculated,
        finalExpiryDate: expiry,
      );
      setState(() => _saving = true);
      final workflow = ref.read(depositWorkflowProvider);
      switch (widget.mode) {
        case DepositFormMode.create:
          if (createCustomer) {
            await workflow.createWithCustomer(
              draft,
              CustomerDraft(
                id: customerId,
                name: _customerName.text.trim(),
                phone: _customerPhone.text.trim().isEmpty
                    ? null
                    : _customerPhone.text.trim(),
              ),
            );
          } else {
            await workflow.create(draft);
          }
        case DepositFormMode.update:
          await workflow.update(widget.sourceDepositId ?? draft.id, draft);
        case DepositFormMode.renew:
          await workflow.renew(widget.sourceDepositId!, draft);
      }
      await _learnPresets();
      await Future.wait([
        ref.read(customerControllerProvider.notifier).retry(),
        ref.read(dashboardControllerProvider.notifier).retry(),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存')));
        widget.onSaved?.call();
      }
    } on DepositNotActiveException {
      _showError('该存款已被处理，请刷新后重试');
    } on Object catch (error) {
      _showError('保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _learnPresets() async {
    try {
      final service = ref.read(depositPresetServiceProvider);
      final candidates = <MapEntry<DepositPresetField, String>>[
        MapEntry(DepositPresetField.amount, _amount.text),
        MapEntry(DepositPresetField.bank, _bank.text),
        MapEntry(DepositPresetField.product, _product.text),
        MapEntry(DepositPresetField.rate, _rate.text),
        if (_automatic) MapEntry(DepositPresetField.term, _term.text),
      ];
      await Future.wait(
        candidates
            .where((entry) => entry.value.trim().isNotEmpty)
            .map(
              (entry) => service.addCandidate(entry.key, entry.value.trim()),
            ),
      );
    } catch (_) {
      // 学习候选失败不影响已完成的业务保存。
    }
  }

  Future<CustomerRecord?> _findExactCustomer() async {
    final name = normalizeSearchText(_customerName.text);
    final phone = normalizePhone(_customerPhone.text);
    if (name.isEmpty || phone.isEmpty) return null;
    final candidates = await ref
        .read(customerUseCasesProvider)
        .load(_customerPhone.text.trim());
    for (final candidate in candidates) {
      if (normalizeSearchText(candidate.customer.name) == name &&
          normalizePhone(candidate.customer.phone ?? '') == phone) {
        return candidate.customer;
      }
    }
    return null;
  }

  Future<bool?> _confirmDuplicateCustomer(CustomerRecord customer) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('发现相同客户'),
          content: Text('${_customerLabel(customer)} 已存在，本次存款归入该客户吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('仍新增客户'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('归入已有客户'),
            ),
          ],
        ),
      );

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _orderedCandidates(DepositPresetField field, String query) {
    final catalog = switch (field) {
      DepositPresetField.bank => _catalogBanks,
      DepositPresetField.product =>
        _catalogProducts
            .map((product) => product.productName)
            .toList(growable: false),
      _ => const <String>[],
    };
    final values = <String>{...catalog, ...?_presets[field]}.toList();
    if (field != DepositPresetField.product || query.trim().isEmpty) {
      return values;
    }
    final similar = values.where((value) => _isSimilar(value, query)).toSet();
    return [
      ...values.where(similar.contains),
      ...values.where((value) => !similar.contains(value)),
    ];
  }

  List<String> get _similarProducts {
    final query = _product.text.trim();
    if (query.isEmpty) return const [];
    return (_presets[DepositPresetField.product] ?? const [])
        .where((value) => value.trim() != query && _isSimilar(value, query))
        .take(3)
        .toList(growable: false);
  }

  bool _isSimilar(String left, String right) {
    final a = _normalizeProduct(left);
    final b = _normalizeProduct(right);
    if (a.isEmpty || b.isEmpty) return false;
    if (a.contains(b) || b.contains(a)) return true;
    return _editDistance(a, b) <= (a.length > 6 && b.length > 6 ? 2 : 1);
  }

  String _normalizeProduct(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s\-_（）()]'), '');

  int _editDistance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 0; i < a.length; i++) {
      final current = <int>[i + 1];
      for (var j = 0; j < b.length; j++) {
        current.add(
          [
            current[j] + 1,
            previous[j + 1] + 1,
            previous[j] + (a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1),
          ].reduce((x, y) => x < y ? x : y),
        );
      }
      previous = current;
    }
    return previous.last;
  }

  String _customerLabel(CustomerRecord customer) {
    final phone = customer.phone?.trim();
    return phone == null || phone.isEmpty
        ? customer.name
        : '${customer.name}（$phone）';
  }

  String _formatRate(DepositDraft? initial) {
    if (initial == null) return '';
    return (initial.interestRateScaled / _scaleFor(_ratePrecision))
        .toStringAsFixed(_ratePrecision)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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

  DateTime? _tryDateTime(String value) {
    try {
      final date = _parseDate(value);
      return DateTime(date.year, date.month, date.day);
    } catch (_) {
      return null;
    }
  }

  int _scaleFor(int precision) {
    var scale = 1;
    for (var i = 0; i < precision; i++) {
      scale *= 10;
    }
    return scale;
  }

  String _termUnitLabel(DepositTermUnit unit) => switch (unit) {
    DepositTermUnit.day => '日',
    DepositTermUnit.month => '月',
    DepositTermUnit.year => '年',
  };
}

class _RenewalSourceSummary extends StatelessWidget {
  const _RenewalSourceSummary({
    required this.customerName,
    required this.customerPhone,
    required this.draft,
  });

  final String customerName;
  final String? customerPhone;
  final DepositDraft draft;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_customerLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('原银行：${draft.bankName}'),
          Text(
            '原产品：${draft.productName}',
            key: const Key('renewal-original-product'),
          ),
          Text('原金额：${(draft.amountCents / 100).toStringAsFixed(2)} 元'),
          Text(
            '原利率：${(draft.interestRateScaled / _scaleFor(draft.ratePrecision)).toStringAsFixed(draft.ratePrecision)}%',
            key: const Key('renewal-original-rate'),
          ),
          Text(
            '原到期日：${draft.finalExpiryDate}',
            key: const Key('renewal-original-expiry'),
          ),
        ],
      ),
    ),
  );

  String get _customerLabel {
    final phone = customerPhone?.trim();
    return phone == null || phone.isEmpty
        ? customerName
        : '$customerName（$phone）';
  }

  int _scaleFor(int precision) {
    var scale = 1;
    for (var i = 0; i < precision; i++) {
      scale *= 10;
    }
    return scale;
  }
}
