import 'package:deposit_renewal_manager/features/deposits/presentation/editable_catalog_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('可编辑下拉支持手工输入和带副标题选项', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    EditableCatalogOption? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableCatalogField(
            controller: controller,
            label: '产品名称',
            options: const [
              EditableCatalogOption(
                '稳健存款',
                id: 'product-p1',
                subtitle: '适用年利率 2.30%',
                emphasized: true,
              ),
            ],
            onChanged: (_) {},
            onSelected: (option) => selected = option,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '自定义产品');
    expect(controller.text, '自定义产品');

    await tester.tap(find.byTooltip('展开产品名称选项'));
    await tester.pumpAndSettle();
    expect(find.text('适用年利率 2.30%'), findsOneWidget);
    final optionFinder = find.byKey(const Key('catalog-option-product-p1'));
    final optionText = tester.widget<Text>(optionFinder);
    expect(
      optionText.style?.color,
      Theme.of(tester.element(optionFinder)).colorScheme.primary,
    );

    await tester.tap(find.text('稳健存款'));
    await tester.pumpAndSettle();
    expect(controller.text, '稳健存款');
    expect(selected?.id, 'product-p1');
  });
}
