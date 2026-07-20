import 'dart:async';

import 'package:deposit_renewal_manager/features/customers/application/customer_controller.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/customers/domain/name_search_index.dart';
import 'package:deposit_renewal_manager/features/customers/presentation/customer_pages.dart';
import 'package:deposit_renewal_manager/features/customers/application/customer_history_service.dart';
import 'package:deposit_renewal_manager/features/deposits/application/deposit_workflow_controller.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/deposits/presentation/deposit_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search field loads customer result', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [customerUseCasesProvider.overrideWithValue(const _Cases())],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), 'zhangsan');
    await tester.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);

    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增存款'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-name')), findsOneWidget);
  });

  testWidgets('history action displays persisted audit entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerUseCasesProvider.overrideWithValue(const _Cases()),
          customerHistoryUseCasesProvider.overrideWithValue(const _History()),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改记录'));
    await tester.pumpAndSettle();
    expect(find.text('张三的修改记录'), findsOneWidget);
    expect(find.text('更新'), findsOneWidget);
    expect(find.text('手机号：'), findsOneWidget);
    expect(find.text('13800000000'), findsOneWidget);
    expect(find.text('13900000000'), findsOneWidget);

    final before = tester.widget<Text>(
      find.byKey(const Key('history-before-0')),
    );
    final after = tester.widget<Text>(find.byKey(const Key('history-after-0')));
    expect(
      before.style?.color,
      Theme.of(tester.element(find.byType(AlertDialog))).colorScheme.error,
    );
    expect(after.style?.color, const Color(0xFF2E7D32));
  });

  testWidgets('filters customers by bank and product', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerUseCasesProvider.overrideWithValue(const _FilterCases()),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('customer-bank-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('建设银行').last);
    await tester.pumpAndSettle();
    expect(find.text('李四'), findsOneWidget);
    expect(find.text('张三'), findsNothing);

    await tester.tap(find.byKey(const Key('customer-product-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('稳健存款').last);
    await tester.pumpAndSettle();
    expect(find.text('李四'), findsOneWidget);

    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('李四'), findsOneWidget);
    expect(find.text('张三'), findsNothing);
  });

  testWidgets('renders renewal versions and deposit details', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerUseCasesProvider.overrideWithValue(const _DepositCases()),
          customerDepositHistoryUseCasesProvider.overrideWithValue(
            const _DepositHistory(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();

    expect(find.text('已续期'), findsOneWidget);
    expect(find.text('生效中'), findsOneWidget);
    final renewedTitle = tester.widget<Text>(find.text('中国银行 · 稳健存款').first);
    expect(renewedTitle.style?.decoration, TextDecoration.lineThrough);

    await tester.tap(find.byKey(const Key('customer-deposit-d2')));
    await tester.pumpAndSettle();
    expect(find.text('存款详情'), findsOneWidget);
    expect(find.text('¥1000.00'), findsOneWidget);
    expect(find.text('2.15%'), findsOneWidget);
    expect(find.text('续期'), findsOneWidget);
    expect(find.text('停止续期'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-deposit-d1')));
    await tester.pumpAndSettle();
    expect(find.text('存款详情'), findsOneWidget);
    expect(find.text('续期'), findsNothing);
    expect(find.text('停止续期'), findsNothing);
    expect(find.text('编辑'), findsNothing);
  });

  testWidgets('active deposit details open a prefilled renewal form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerUseCasesProvider.overrideWithValue(const _DepositCases()),
          customerDepositHistoryUseCasesProvider.overrideWithValue(
            const _DepositHistory(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-deposit-d2')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('续期'));
    await tester.pumpAndSettle();

    final form = tester.widget<DepositFormPage>(find.byType(DepositFormPage));
    expect(form.mode, DepositFormMode.renew);
    expect(form.sourceDepositId, 'd2');
    expect(form.initialCustomerName, '张三');
    expect(form.initialCustomerPhone, '13800000000');
  });

  testWidgets('stopping from deposit details refreshes customer deposits', (
    tester,
  ) async {
    final cases = _ActionDepositCases();
    final history = _ActionDepositHistory();
    final workflow = _RecordingDepositWorkflow();
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerUseCasesProvider.overrideWithValue(cases),
          customerDepositHistoryUseCasesProvider.overrideWithValue(history),
          depositWorkflowProvider.overrideWithValue(workflow),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-deposit-d2')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('停止续期'));
    await tester.pumpAndSettle();
    expect(find.text('停止续期？'), findsOneWidget);
    await tester.tap(find.text('确认停止'));
    await tester.pumpAndSettle();

    expect(workflow.stopCalls, ['d2']);
    expect(cases.loadCalls, 2);
    expect(history.loadCalls, 2);
  });

  testWidgets('stale stop action shows a readable message', (tester) async {
    final workflow = _RecordingDepositWorkflow(
      stopError: const DepositNotActiveException('d2'),
    );
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerUseCasesProvider.overrideWithValue(const _DepositCases()),
          customerDepositHistoryUseCasesProvider.overrideWithValue(
            const _DepositHistory(),
          ),
          depositWorkflowProvider.overrideWithValue(workflow),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-deposit-d2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停止续期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认停止'));
    await tester.pumpAndSettle();

    expect(find.text('该存款已被处理，请刷新后重试'), findsOneWidget);
  });

  testWidgets('refresh reloads deposit chains for an expanded customer', (
    tester,
  ) async {
    final cases = _ChangingDepositCases();
    final history = _ChangingDepositHistory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerUseCasesProvider.overrideWithValue(cases),
          customerDepositHistoryUseCasesProvider.overrideWithValue(history),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();

    expect(history.loadCalls, 1);
    expect(find.text('已续期'), findsNothing);
    expect(find.text('生效中'), findsOneWidget);

    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    expect(history.loadCalls, 2);
    expect(find.text('已续期'), findsOneWidget);
    expect(find.text('生效中'), findsOneWidget);
  });

  testWidgets('refresh does not preload chains for a collapsed customer', (
    tester,
  ) async {
    final cases = _ChangingDepositCases();
    final history = _ChangingDepositHistory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerUseCasesProvider.overrideWithValue(cases),
          customerDepositHistoryUseCasesProvider.overrideWithValue(history),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();

    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    expect(history.loadCalls, 0);
  });

  testWidgets('refresh failure keeps customers and shows feedback', (
    tester,
  ) async {
    final cases = _RefreshFailureCases();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [customerUseCasesProvider.overrideWithValue(cases)],
        child: const MaterialApp(home: Scaffold(body: CustomerDirectoryPage())),
      ),
    );
    await tester.pumpAndSettle();

    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final pendingRefresh = refresh.onRefresh();
    cases.refresh.completeError(StateError('offline'));
    await pendingRefresh;
    await tester.pump();

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('客户列表刷新失败，请稍后重试'), findsOneWidget);
  });

  test('audit JSON is converted to changed fields and tolerates old data', () {
    final entry = CustomerHistoryEntry(
      operation: 'update',
      occurredAt: DateTime(2026, 7, 19),
      beforeJson: '{"bank_name":"中国银行","unchanged":1}',
      afterJson: '{"bank_name":"建设银行","unchanged":1}',
    );
    expect(entry.changes, hasLength(1));
    expect(entry.changes.single.field, 'bank_name');
    expect(entry.changes.single.before, '中国银行');
    expect(entry.changes.single.after, '建设银行');

    final legacy = CustomerHistoryEntry(
      operation: 'update',
      occurredAt: DateTime(2026, 7, 19),
      beforeJson: 'not-json',
    );
    expect(legacy.changes, isEmpty);
  });
}

final class _History implements CustomerHistoryUseCases {
  const _History();
  @override
  Future<List<CustomerHistoryEntry>> load(String customerId) async => [
    CustomerHistoryEntry(
      operation: 'update',
      occurredAt: DateTime(2026, 7, 19),
      beforeJson: '{"phone":"13800000000"}',
      afterJson: '{"phone":"13900000000"}',
    ),
  ];
}

final class _Cases implements CustomerUseCases {
  const _Cases();
  @override
  Future<List<CustomerSearchResult>> load(String query) async => [
    CustomerSearchResult(
      customer: const CustomerRecord(
        id: 'c1',
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

final class _RefreshFailureCases implements CustomerUseCases {
  final refresh = Completer<List<CustomerSearchResult>>();
  int loadCalls = 0;

  @override
  Future<List<CustomerSearchResult>> load(String query) {
    loadCalls++;
    return loadCalls == 1 ? const _Cases().load(query) : refresh.future;
  }

  @override
  Future<void> save(CustomerDraft draft) async {}
}

final class _FilterCases implements CustomerUseCases {
  const _FilterCases();
  @override
  Future<List<CustomerSearchResult>> load(String query) async => [
    _customerWithDeposit(id: 'c1', name: '张三', bank: '中国银行', product: '成长存款'),
    _customerWithDeposit(id: 'c2', name: '李四', bank: '建设银行', product: '稳健存款'),
  ];
  @override
  Future<void> save(CustomerDraft draft) async {}
}

final class _DepositCases implements CustomerUseCases {
  const _DepositCases();
  @override
  Future<List<CustomerSearchResult>> load(String query) async => [
    _customerWithDeposit(id: 'c1', name: '张三', bank: '中国银行', product: '稳健存款'),
  ];
  @override
  Future<void> save(CustomerDraft draft) async {}
}

final class _DepositHistory implements CustomerDepositHistoryUseCases {
  const _DepositHistory();
  @override
  Future<List<CustomerDepositChain>> load(CustomerSearchResult result) async =>
      [
        CustomerDepositChain(
          versions: [
            CustomerDepositVersion(
              id: 'd1',
              bankName: '中国银行',
              productName: '稳健存款',
              finalExpiryDate: LocalDate(2026, 7, 1),
              lifecycle: DepositLifecycle.renewed,
            ),
            CustomerDepositVersion(
              id: 'd2',
              bankName: '中国银行',
              productName: '稳健存款',
              amountCents: 100000,
              interestRateScaled: 215,
              ratePrecision: 2,
              startDate: LocalDate(2026, 7, 1),
              finalExpiryDate: LocalDate(2027, 7, 1),
              lifecycle: DepositLifecycle.active,
              renewalSourceId: 'd1',
              editableDraft: DepositDraft(
                id: 'd2',
                customerId: 'c1',
                amountCents: 100000,
                bankName: '中国银行',
                productName: '稳健存款',
                interestRateScaled: 215,
                ratePrecision: 2,
                startDate: LocalDate(2026, 7, 1),
                calculatedExpiryDate: LocalDate(2027, 7, 1),
                finalExpiryDate: LocalDate(2027, 7, 1),
              ),
            ),
          ],
        ),
      ];
}

final class _ChangingDepositCases implements CustomerUseCases {
  int loadCalls = 0;

  @override
  Future<List<CustomerSearchResult>> load(String query) async {
    loadCalls++;
    return [
      CustomerSearchResult(
        customer: const CustomerRecord(
          id: 'c1',
          name: '张三',
          phone: '13800000000',
          isActive: true,
        ),
        deposits: [
          CustomerSearchDeposit(
            id: 'd1',
            bankName: '中国银行',
            productName: '稳健存款',
            finalExpiryDate: LocalDate(2027, 7, 1),
            lifecycle: loadCalls == 1
                ? DepositLifecycle.active
                : DepositLifecycle.renewed,
          ),
        ],
      ),
    ];
  }

  @override
  Future<void> save(CustomerDraft draft) async {}
}

final class _ChangingDepositHistory implements CustomerDepositHistoryUseCases {
  int loadCalls = 0;

  @override
  Future<List<CustomerDepositChain>> load(CustomerSearchResult result) async {
    loadCalls++;
    final renewed =
        result.deposits.single.lifecycle == DepositLifecycle.renewed;
    return [
      CustomerDepositChain(
        versions: [
          CustomerDepositVersion(
            id: 'd1',
            bankName: '中国银行',
            productName: '稳健存款',
            finalExpiryDate: LocalDate(2027, 7, 1),
            lifecycle: renewed
                ? DepositLifecycle.renewed
                : DepositLifecycle.active,
          ),
          if (renewed)
            CustomerDepositVersion(
              id: 'd2',
              bankName: '中国银行',
              productName: '稳健存款',
              finalExpiryDate: LocalDate(2027, 7, 1),
              lifecycle: DepositLifecycle.active,
              renewalSourceId: 'd1',
            ),
        ],
      ),
    ];
  }
}

final class _ActionDepositCases implements CustomerUseCases {
  int loadCalls = 0;

  @override
  Future<List<CustomerSearchResult>> load(String query) async {
    loadCalls++;
    return const _DepositCases().load(query);
  }

  @override
  Future<void> save(CustomerDraft draft) async {}
}

final class _ActionDepositHistory implements CustomerDepositHistoryUseCases {
  int loadCalls = 0;

  @override
  Future<List<CustomerDepositChain>> load(CustomerSearchResult result) async {
    loadCalls++;
    return const _DepositHistory().load(result);
  }
}

final class _RecordingDepositWorkflow implements DepositWorkflow {
  _RecordingDepositWorkflow({this.stopError});

  final Object? stopError;
  final stopCalls = <String>[];

  @override
  Future<void> create(DepositDraft draft) async {}

  @override
  Future<void> createWithCustomer(
    DepositDraft draft,
    CustomerDraft customer,
  ) async {}

  @override
  Future<void> renew(String sourceDepositId, DepositDraft draft) async {}

  @override
  Future<void> stop(String depositId) async {
    stopCalls.add(depositId);
    if (stopError case final error?) throw error;
  }

  @override
  Future<void> update(String depositId, DepositDraft draft) async {}
}

CustomerSearchResult _customerWithDeposit({
  required String id,
  required String name,
  required String bank,
  required String product,
}) => CustomerSearchResult(
  customer: CustomerRecord(
    id: id,
    name: name,
    phone: '13800000000',
    isActive: true,
  ),
  deposits: [
    CustomerSearchDeposit(
      id: 'd-$id',
      bankName: bank,
      productName: product,
      finalExpiryDate: LocalDate(2027, 7, 1),
      lifecycle: DepositLifecycle.active,
    ),
  ],
);
