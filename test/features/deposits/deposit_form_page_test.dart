import 'package:deposit_renewal_manager/features/customers/application/customer_controller.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/deposits/presentation/deposit_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

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
