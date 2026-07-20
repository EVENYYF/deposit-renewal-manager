import 'package:flutter/material.dart';

import '../../deposits/application/product_catalog_service.dart';
import '../../deposits/domain/local_date.dart';
import '../../deposits/domain/product_catalog_repository.dart';

final class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({required this.service, super.key});

  final ProductCatalogService service;

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  final _search = TextEditingController();
  List<ProductRecord> _products = const [];
  final _rates = <String, List<ProductRateVersion>>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final products = await widget.service.list(includeInactive: true);
      final rates = <String, List<ProductRateVersion>>{};
      for (final product in products) {
        rates[product.id] = await widget.service.listRates(product.id);
      }
      if (!mounted) return;
      setState(() {
        _products = products;
        _rates
          ..clear()
          ..addAll(rates);
        _loading = false;
        _error = null;
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

  List<ProductRecord> get _visibleProducts {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products
        .where(
          (product) =>
              product.bankName.toLowerCase().contains(query) ||
              product.productName.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  Future<void> _editProduct([ProductRecord? product]) async {
    final result = await showDialog<ProductDraft>(
      context: context,
      builder: (_) => _ProductDialog(product: product),
    );
    if (result == null) return;
    try {
      await widget.service.saveProduct(result);
      await _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggle(ProductRecord product) async {
    try {
      await widget.service.setProductActive(product.id, !product.isActive);
      await _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editRate(
    ProductRecord product, [
    ProductRateVersion? rate,
  ]) async {
    final result = await showDialog<ProductRateDraft>(
      context: context,
      builder: (_) => _RateDialog(productId: product.id, rate: rate),
    );
    if (result == null) return;
    try {
      await widget.service.saveRate(result);
      await _reload();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('产品管理'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _editProduct(),
            tooltip: '新增产品',
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: '搜索银行或产品',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
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
                const SizedBox(height: 12),
                if (products.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('暂无产品'),
                    subtitle: Text('点击右上角添加银行产品和利率版本'),
                  ),
                for (final product in products) _productTile(product),
              ],
            ),
    );
  }

  Widget _productTile(ProductRecord product) {
    final rates = _rates[product.id] ?? const <ProductRateVersion>[];
    final latest = rates.isEmpty ? null : rates.first;
    return ExpansionTile(
      key: ValueKey('product-${product.id}'),
      title: Text(product.productName),
      subtitle: Text(
        '${product.bankName} · ${product.isActive ? '启用' : '已停用'}'
        '${latest == null ? '' : ' · 最新利率 ${_formatRate(latest)}'}',
      ),
      leading: Icon(
        product.isActive ? Icons.account_balance_outlined : Icons.pause_circle,
        color: product.isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).disabledColor,
      ),
      children: [
        for (final rate in rates)
          ListTile(
            dense: true,
            title: Text('${rate.effectiveDate} · ${_formatRate(rate)}'),
            trailing: IconButton(
              onPressed: () => _editRate(product, rate),
              tooltip: '编辑利率',
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        OverflowBar(
          children: [
            TextButton.icon(
              onPressed: () => _editProduct(product),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('编辑产品'),
            ),
            TextButton.icon(
              onPressed: () => _toggle(product),
              icon: Icon(product.isActive ? Icons.pause : Icons.play_arrow),
              label: Text(product.isActive ? '停用' : '启用'),
            ),
            FilledButton.icon(
              onPressed: () => _editRate(product),
              icon: const Icon(Icons.percent),
              label: const Text('新增利率'),
            ),
          ],
        ),
      ],
    );
  }

  String _formatRate(ProductRateVersion rate) =>
      '${(rate.interestRateScaled / _pow10(rate.ratePrecision)).toStringAsFixed(rate.ratePrecision)}%';

  int _pow10(int precision) {
    var value = 1;
    for (var i = 0; i < precision; i++) {
      value *= 10;
    }
    return value;
  }
}

final class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});
  final ProductRecord? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _bank;
  late final TextEditingController _name;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bank = TextEditingController(text: widget.product?.bankName);
    _name = TextEditingController(text: widget.product?.productName);
  }

  @override
  void dispose() {
    _bank.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? '新增产品' : '编辑产品'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _bank,
            autofocus: true,
            decoration: const InputDecoration(labelText: '银行名称'),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '产品名称'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final bank = _bank.text.trim();
          final name = _name.text.trim();
          if (bank.isEmpty || name.isEmpty) {
            setState(() => _error = '银行和产品名称不能为空');
            return;
          }
          Navigator.pop(
            context,
            ProductDraft(
              id: widget.product?.id ?? '',
              bankName: bank,
              productName: name,
              isActive: widget.product?.isActive ?? true,
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}

final class _RateDialog extends StatefulWidget {
  const _RateDialog({required this.productId, this.rate});
  final String productId;
  final ProductRateVersion? rate;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  late final TextEditingController _date;
  late final TextEditingController _rate;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = TextEditingController(text: widget.rate?.effectiveDate.toString());
    final rate = widget.rate;
    _rate = TextEditingController(
      text: rate == null
          ? ''
          : (rate.interestRateScaled / _pow10(rate.ratePrecision))
                .toStringAsFixed(rate.ratePrecision),
    );
  }

  @override
  void dispose() {
    _date.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.rate == null ? '新增利率版本' : '编辑利率版本'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _date,
            decoration: InputDecoration(
              labelText: '生效日期（YYYY-MM-DD）',
              suffixIcon: IconButton(
                tooltip: '选择日期',
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: _pickDate,
              ),
            ),
          ),
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '年利率（%）'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _save, child: const Text('保存')),
    ],
  );

  Future<void> _pickDate() async {
    final current = _parseDate(_date.text) ?? LocalDate(2026, 1, 1);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      initialDate: DateTime(current.year, current.month, current.day),
    );
    if (picked != null) {
      _date.text = LocalDate(picked.year, picked.month, picked.day).toString();
    }
  }

  void _save() {
    final date = _parseDate(_date.text);
    final parsed = _parseRate(_rate.text);
    if (date == null || parsed == null) {
      setState(() => _error = '请输入有效日期和非负利率（最多 9 位小数）');
      return;
    }
    Navigator.pop(
      context,
      ProductRateDraft(
        id: widget.rate?.id ?? '',
        productId: widget.productId,
        interestRateScaled: parsed.$1,
        ratePrecision: parsed.$2,
        effectiveDate: date,
      ),
    );
  }

  LocalDate? _parseDate(String value) {
    final parts = value.trim().split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    try {
      return LocalDate(year, month, day);
    } on ArgumentError {
      return null;
    }
  }

  (int, int)? _parseRate(String value) {
    final text = value.trim();
    final match = RegExp(r'^\d+(?:\.\d{1,9})?$').firstMatch(text);
    if (match == null) return null;
    final decimal = text.split('.');
    final precision = decimal.length == 1 ? 0 : decimal[1].length;
    final scaled = int.tryParse(decimal.join());
    return scaled == null ? null : (scaled, precision);
  }

  int _pow10(int precision) {
    var value = 1;
    for (var i = 0; i < precision; i++) {
      value *= 10;
    }
    return value;
  }
}
