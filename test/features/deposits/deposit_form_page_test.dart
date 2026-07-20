import 'package:deposit_renewal_manager/app/app_dependencies.dart';
import 'package:deposit_renewal_manager/features/customers/application/customer_controller.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/application/deposit_workflow_controller.dart';
import 'package:deposit_renewal_manager/features/deposits/application/product_catalog_service.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/product_catalog_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/presentation/deposit_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('matches catalog rate by bank, product and start date', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productCatalogServiceProvider.overrideWithValue(
            ProductCatalogService(_Catalog()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DepositFormPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, '甲银行'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, '稳健存款'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, '稳健存款'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-date')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('start-date')), '2026-07-01');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('deposit-rate')))
          .controller!
          .text,
      '2.30',
    );
  });

  testWidgets('displays interest rate with its stored precision', (
    tester,
  ) async {
    final draft = DepositDraft(
      id: 'deposit-1',
      customerId: 'customer-1',
      amountCents: 100000,
      interestRateScaled: 215,
      ratePrecision: 2,
      startDate: LocalDate(2026, 1, 1),
      calculatedExpiryDate: LocalDate(2027, 1, 1),
      finalExpiryDate: LocalDate(2027, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: DepositFormPage(initial: draft)),
        ),
      ),
    );

    expect(find.widgetWithText(TextFormField, '2.15'), findsOneWidget);
  });

  testWidgets('searches existing customers and shows name with phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerUseCasesProvider.overrideWithValue(const _CustomerCases()),
        ],
        child: const MaterialApp(home: Scaffold(body: DepositFormPage())),
      ),
    );

    await tester.enterText(find.byKey(const Key('customer-name')), '张');
    await tester.pumpAndSettle();

    expect(find.text('张三（13800000000）'), findsOneWidget);
  });

  testWidgets('recalculates expiry for a day-based term', (tester) async {
    final draft = DepositDraft(
      id: 'deposit-1',
      customerId: 'customer-1',
      amountCents: 100000,
      termValue: 1,
      termUnit: DepositTermUnit.day,
      interestRateScaled: 215,
      ratePrecision: 2,
      startDate: LocalDate(2026, 1, 1),
      calculatedExpiryDate: LocalDate(2026, 1, 2),
      finalExpiryDate: LocalDate(2026, 1, 2),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: DepositFormPage(initial: draft)),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('deposit-term')), '2');
    await tester.pump();

    final expiry = tester.widget<TextFormField>(
      find.byKey(const Key('expiry-date')),
    );
    expect(expiry.controller!.text, '2026-01-03');
  });

  testWidgets(
    'renewal separates read-only source values from editable values',
    (tester) async {
      final draft = _renewalDraft();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DepositFormPage(
                mode: DepositFormMode.renew,
                sourceDepositId: draft.id,
                initial: draft,
                initialCustomerName: '李明',
                initialCustomerPhone: '13800000000',
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('renewal-original-product')), findsOneWidget);
      expect(find.byKey(const Key('renewal-original-rate')), findsOneWidget);
      expect(find.byKey(const Key('renewal-original-expiry')), findsOneWidget);
      expect(find.text('原银行：旧银行'), findsOneWidget);
      expect(find.text('原产品：旧产品'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      final product = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('deposit-product')),
          matching: find.byType(EditableText),
        ),
      );
      final rate = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('deposit-rate')),
          matching: find.byType(EditableText),
        ),
      );
      expect(product.readOnly, isFalse);
      expect(rate.readOnly, isFalse);
    },
  );

  testWidgets('renewal exposes an inactive source as a readable message', (
    tester,
  ) async {
    final draft = _renewalDraft();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          depositWorkflowProvider.overrideWithValue(
            const _InactiveDepositWorkflow(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DepositFormPage(
              mode: DepositFormMode.renew,
              sourceDepositId: draft.id,
              initial: draft,
              initialCustomerName: '李明',
            ),
          ),
        ),
      ),
    );

    for (var index = 0; index < 4; index++) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
    }
    final submit = find.text('确认续期');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('该存款已被处理，请刷新后重试'), findsOneWidget);
    expect(find.textContaining('DepositNotActiveException'), findsNothing);
  });
}

DepositDraft _renewalDraft() => DepositDraft(
  id: 'deposit-1',
  customerId: 'customer-1',
  amountCents: 100000,
  bankName: '旧银行',
  productName: '旧产品',
  termValue: 12,
  termUnit: DepositTermUnit.month,
  interestRateScaled: 215,
  ratePrecision: 2,
  startDate: LocalDate(2026, 1, 1),
  calculatedExpiryDate: LocalDate(2027, 1, 1),
  finalExpiryDate: LocalDate(2027, 1, 1),
);

final class _CustomerCases implements CustomerUseCases {
  const _CustomerCases();

  @override
  Future<List<CustomerSearchResult>> load(String query) async => [
    CustomerSearchResult(
      customer: const CustomerRecord(
        id: 'customer-1',
        name: '张三',
        phone: '13800000000',
        isActive: true,
      ),
      deposits: const [],
    ),
  ];

  @override
  Future<void> save(CustomerDraft draft) async {}
}

final class _InactiveDepositWorkflow implements DepositWorkflow {
  const _InactiveDepositWorkflow();

  @override
  Future<void> create(DepositDraft draft) async {}

  @override
  Future<void> createWithCustomer(
    DepositDraft draft,
    CustomerDraft customer,
  ) async {}

  @override
  Future<void> renew(String sourceDepositId, DepositDraft draft) =>
      throw DepositNotActiveException(sourceDepositId);

  @override
  Future<void> stop(String depositId) async {}

  @override
  Future<void> update(String depositId, DepositDraft draft) async {}
}

final class _Catalog implements ProductCatalogRepository {
  @override
  Future<List<ProductRecord>> listProducts({
    bool includeInactive = false,
  }) async => const [
    ProductRecord(
      id: 'p1',
      bankName: '甲银行',
      productName: '稳健存款',
      isActive: true,
    ),
    ProductRecord(
      id: 'p2',
      bankName: '乙银行',
      productName: '其他存款',
      isActive: true,
    ),
  ];

  @override
  Future<ProductRateVersion?> matchRate(
    String productId,
    LocalDate startDate,
  ) async => startDate.isBefore(LocalDate(2026, 6, 1))
      ? null
      : ProductRateVersion(
          id: 'r1',
          productId: productId,
          interestRateScaled: 230,
          ratePrecision: 2,
          effectiveDate: LocalDate(2026, 6, 1),
        );

  @override
  Future<List<ProductRateVersion>> listRates(String productId) async =>
      const [];
  @override
  Future<ProductRecord> saveProduct(ProductDraft draft) =>
      throw UnimplementedError();
  @override
  Future<ProductRateVersion> saveRate(ProductRateDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> setProductActive(String productId, bool active) =>
      throw UnimplementedError();
}
