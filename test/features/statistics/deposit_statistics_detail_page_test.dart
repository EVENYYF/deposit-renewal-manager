import 'package:deposit_renewal_manager/features/statistics/application/deposit_statistics.dart';
import 'package:deposit_renewal_manager/features/statistics/presentation/deposit_statistics_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows deposit fields and supports pull to refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          depositStatisticsUseCasesProvider.overrideWithValue(
            const _DetailCases(),
          ),
        ],
        child: const MaterialApp(
          home: DepositStatisticsDetailPage(
            dimension: DepositStatisticsDimension.product,
            value: '稳健一年',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('产品：稳健一年'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('建设银行 · 稳健一年'), findsOneWidget);
    expect(find.text('¥1,200.00'), findsOneWidget);
    expect(find.text('2.15%'), findsOneWidget);
    expect(find.text('2027-07-20'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
}

final class _DetailCases implements DepositStatisticsUseCases {
  const _DetailCases();

  @override
  Future<DepositStatisticsSnapshot> load({DateTime? now}) async =>
      const DepositStatisticsSnapshot();

  @override
  Future<List<DepositStatisticsDetail>> loadDetails(
    DepositStatisticsDimension dimension,
    String value,
  ) async => const [
    DepositStatisticsDetail(
      depositId: 'd1',
      customerName: '张三',
      customerPhone: '13800000000',
      bankName: '建设银行',
      productName: '稳健一年',
      amountCents: 120000,
      interestRateScaled: 215,
      ratePrecision: 2,
      expiryDate: '2027-07-20',
    ),
  ];
}
