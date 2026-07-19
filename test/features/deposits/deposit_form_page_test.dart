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
}
