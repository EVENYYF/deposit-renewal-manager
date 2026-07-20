import 'package:deposit_renewal_manager/features/deposits/application/product_catalog_service.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/product_catalog_repository.dart';
import 'package:deposit_renewal_manager/features/settings/presentation/product_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows products, rate versions and supports product changes', (
    tester,
  ) async {
    final repository = _MemoryCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: ProductManagementPage(service: ProductCatalogService(repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('稳健存款'), findsOneWidget);
    expect(find.textContaining('最新利率 2.15%'), findsOneWidget);
    await tester.tap(find.text('稳健存款'));
    await tester.pumpAndSettle();
    expect(find.text('2026-01-01 · 2.15%'), findsOneWidget);

    await tester.tap(find.byTooltip('新增产品'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '银行名称'), '乙银行');
    await tester.enterText(find.widgetWithText(TextField, '产品名称'), '成长存款');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('成长存款'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, '停用'));
    await tester.tap(find.widgetWithText(TextButton, '停用'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已停用'), findsOneWidget);
  });

  testWidgets('adds a rate version and rejects invalid input', (tester) async {
    final repository = _MemoryCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: ProductManagementPage(service: ProductCatalogService(repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('稳健存款'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '新增利率'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '生效日期（YYYY-MM-DD）'),
      '2026-02-31',
    );
    await tester.enterText(find.widgetWithText(TextField, '年利率（%）'), 'bad');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();
    expect(find.textContaining('请输入有效日期和非负利率'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '生效日期（YYYY-MM-DD）'),
      '2026-07-01',
    );
    await tester.enterText(find.widgetWithText(TextField, '年利率（%）'), '2.35');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('2026-07-01 · 2.35%'), findsOneWidget);
  });
}

final class _MemoryCatalog implements ProductCatalogRepository {
  final _products = <ProductRecord>[
    const ProductRecord(
      id: 'p1',
      bankName: '甲银行',
      productName: '稳健存款',
      isActive: true,
    ),
  ];
  final _rates = <ProductRateVersion>[
    ProductRateVersion(
      id: 'r1',
      productId: 'p1',
      interestRateScaled: 215,
      ratePrecision: 2,
      effectiveDate: LocalDate(2026, 1, 1),
    ),
  ];

  @override
  Future<List<ProductRecord>> listProducts({
    bool includeInactive = false,
  }) async {
    return _products
        .where((product) => includeInactive || product.isActive)
        .toList(growable: false);
  }

  @override
  Future<ProductRecord> saveProduct(ProductDraft draft) async {
    final id = draft.id.isEmpty ? 'p${_products.length + 1}' : draft.id;
    final value = ProductRecord(
      id: id,
      bankName: draft.bankName,
      productName: draft.productName,
      isActive: draft.isActive,
    );
    final index = _products.indexWhere((product) => product.id == id);
    if (index < 0) {
      _products.add(value);
    } else {
      _products[index] = value;
    }
    return value;
  }

  @override
  Future<void> setProductActive(String productId, bool active) async {
    final index = _products.indexWhere((product) => product.id == productId);
    final product = _products[index];
    _products[index] = ProductRecord(
      id: product.id,
      bankName: product.bankName,
      productName: product.productName,
      isActive: active,
    );
  }

  @override
  Future<List<ProductRateVersion>> listRates(String productId) async {
    final result = _rates
        .where((rate) => rate.productId == productId)
        .toList(growable: false);
    result.sort(
      (left, right) => right.effectiveDate.compareTo(left.effectiveDate),
    );
    return result;
  }

  @override
  Future<ProductRateVersion> saveRate(ProductRateDraft draft) async {
    final existing = _rates.indexWhere(
      (rate) =>
          rate.productId == draft.productId &&
          rate.effectiveDate == draft.effectiveDate,
    );
    final value = ProductRateVersion(
      id: existing < 0 ? 'r${_rates.length + 1}' : _rates[existing].id,
      productId: draft.productId,
      interestRateScaled: draft.interestRateScaled,
      ratePrecision: draft.ratePrecision,
      effectiveDate: draft.effectiveDate,
    );
    if (existing < 0) {
      _rates.add(value);
    } else {
      _rates[existing] = value;
    }
    return value;
  }

  @override
  Future<ProductRateVersion?> matchRate(
    String productId,
    LocalDate startDate,
  ) async {
    final candidates = (await listRates(
      productId,
    )).where((rate) => rate.effectiveDate.compareTo(startDate) <= 0);
    return candidates.isEmpty ? null : candidates.first;
  }
}
