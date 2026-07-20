import 'package:deposit_renewal_manager/features/statistics/application/deposit_statistics.dart';
import 'package:deposit_renewal_manager/features/statistics/presentation/deposit_statistics_detail_page.dart';
import 'package:deposit_renewal_manager/features/deposits/application/deposit_details_service.dart';
import 'package:deposit_renewal_manager/features/deposits/application/deposit_workflow_controller.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/deposits/presentation/deposit_details_view.dart';
import 'package:deposit_renewal_manager/features/deposits/presentation/deposit_form_page.dart';
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
          depositStatisticsUseCasesProvider.overrideWithValue(_DetailCases()),
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

  testWidgets('停止续期需要确认并刷新明细', (tester) async {
    final cases = _DetailCases();
    final workflow = _Workflow();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          depositStatisticsUseCasesProvider.overrideWithValue(cases),
          depositDetailsUseCasesProvider.overrideWithValue(const _Details()),
          depositWorkflowProvider.overrideWithValue(workflow),
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

    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停止续期'));
    await tester.pumpAndSettle();
    expect(find.text('停止续期？'), findsOneWidget);
    await tester.tap(find.text('确认停止'));
    await tester.pumpAndSettle();

    expect(workflow.stoppedIds, ['d1']);
    expect(cases.detailLoads, 2);
  });

  testWidgets('续期操作打开预填表单', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          depositStatisticsUseCasesProvider.overrideWithValue(_DetailCases()),
          depositDetailsUseCasesProvider.overrideWithValue(const _Details()),
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

    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('续期'));
    await tester.pumpAndSettle();

    final form = tester.widget<DepositFormPage>(find.byType(DepositFormPage));
    expect(form.mode, DepositFormMode.renew);
    expect(form.sourceDepositId, 'd1');
    expect(form.initial?.amountCents, 120000);
  });
}

final class _DetailCases implements DepositStatisticsUseCases {
  int detailLoads = 0;

  @override
  Future<DepositStatisticsSnapshot> load({DateTime? now}) async =>
      const DepositStatisticsSnapshot();

  @override
  Future<List<DepositStatisticsDetail>> loadDetails(
    DepositStatisticsDetailQuery query,
  ) async {
    detailLoads++;
    return const [
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
}

final class _Details implements DepositDetailsUseCases {
  const _Details();

  @override
  Future<DepositDetailsRecord?> load(String depositId) async =>
      DepositDetailsRecord(
        data: DepositDetailsViewData(
          depositId: 'd1',
          customerName: '张三',
          customerPhone: '13800000000',
          bankName: '建设银行',
          productName: '稳健一年',
          amountCents: 120000,
          interestRateScaled: 215,
          ratePrecision: 2,
          startDate: LocalDate(2026, 7, 20),
          expiryDate: LocalDate(2027, 7, 20),
          lifecycle: DepositLifecycle.active,
        ),
        editableDraft: DepositDraft(
          id: 'd1',
          customerId: 'c1',
          amountCents: 120000,
          bankName: '建设银行',
          productName: '稳健一年',
          interestRateScaled: 215,
          ratePrecision: 2,
          startDate: LocalDate(2026, 7, 20),
          calculatedExpiryDate: LocalDate(2027, 7, 20),
          finalExpiryDate: LocalDate(2027, 7, 20),
        ),
      );
}

final class _Workflow implements DepositWorkflow {
  final stoppedIds = <String>[];

  @override
  Future<void> stop(String depositId) async => stoppedIds.add(depositId);
  @override
  Future<void> create(DepositDraft draft) async {}
  @override
  Future<void> createWithCustomer(DepositDraft draft, customer) async {}
  @override
  Future<void> renew(String sourceDepositId, DepositDraft draft) async {}
  @override
  Future<void> update(String depositId, DepositDraft draft) async {}
}
