import 'package:deposit_renewal_manager/features/deposits/domain/deposit.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/deposits/presentation/deposit_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('active details expose actions and formatted values', (
    tester,
  ) async {
    final data = DepositDetailsViewData(
      depositId: 'd1',
      customerName: 'Alice',
      bankName: 'Bank',
      productName: 'Fixed',
      amountCents: 12345,
      interestRateScaled: 215,
      ratePrecision: 2,
      startDate: LocalDate(2026, 1, 1),
      expiryDate: LocalDate(2027, 1, 1),
      lifecycle: DepositLifecycle.active,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDepositDetailsDialog(
              context,
              data: data,
              allowActions: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('金额：123.45 元'), findsOneWidget);
    expect(find.text('年利率：2.15%'), findsOneWidget);
    expect(find.text('续期'), findsOneWidget);
    expect(find.text('停止续期'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
  });
}
