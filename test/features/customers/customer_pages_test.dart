import 'package:deposit_renewal_manager/features/customers/application/customer_controller.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/customers/presentation/customer_pages.dart';
import 'package:deposit_renewal_manager/features/customers/application/customer_history_service.dart';
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
    await tester.enterText(find.byType(SearchBar), 'zhangsan');
    await tester.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);

    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增存款'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'c1'), findsOneWidget);
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
  });
}

final class _History implements CustomerHistoryUseCases {
  const _History();
  @override
  Future<List<CustomerHistoryEntry>> load(String customerId) async => [
    CustomerHistoryEntry(
      operation: 'update',
      occurredAt: DateTime(2026, 7, 19),
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
