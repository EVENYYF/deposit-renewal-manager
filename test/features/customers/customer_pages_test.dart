import 'package:deposit_renewal_manager/features/customers/application/customer_controller.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/customers/presentation/customer_pages.dart';
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
  });
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
