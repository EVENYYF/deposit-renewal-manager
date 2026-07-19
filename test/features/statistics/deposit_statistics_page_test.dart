import 'package:deposit_renewal_manager/features/statistics/application/deposit_statistics.dart';
import 'package:deposit_renewal_manager/features/statistics/presentation/deposit_statistics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows summary, lifecycle and current breakdowns on phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          depositStatisticsUseCasesProvider.overrideWithValue(
            const _FakeStatisticsUseCases(),
          ),
        ],
        child: const MaterialApp(home: DepositStatisticsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('存款统计'), findsOneWidget);
    expect(find.text('¥2,000.00'), findsOneWidget);
    expect(find.text('4 笔'), findsOneWidget);
    expect(find.text('已续期历史'), findsOneWidget);
    expect(find.text('建设银行'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('稳健一年'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows empty breakdown state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          depositStatisticsUseCasesProvider.overrideWithValue(
            const EmptyDepositStatisticsUseCases(),
          ),
        ],
        child: const MaterialApp(home: DepositStatisticsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无生效中的存款'), findsNWidgets(2));
  });
}

final class _FakeStatisticsUseCases implements DepositStatisticsUseCases {
  const _FakeStatisticsUseCases();

  @override
  Future<DepositStatisticsSnapshot> load({DateTime? now}) async =>
      const DepositStatisticsSnapshot(
        totalCount: 4,
        activeCount: 2,
        overdueCount: 1,
        renewedCount: 1,
        stoppedCount: 1,
        currentPrincipalCents: 200000,
        customerCount: 2,
        renewalCount: 1,
        byBank: [
          DepositStatisticsBreakdown(
            name: '建设银行',
            amountCents: 170000,
            depositCount: 2,
            customerCount: 1,
          ),
        ],
        byProduct: [
          DepositStatisticsBreakdown(
            name: '稳健一年',
            amountCents: 120000,
            depositCount: 1,
            customerCount: 1,
          ),
        ],
      );
}
