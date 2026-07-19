import 'package:deposit_renewal_manager/features/templates/domain/message_template.dart';
import 'package:deposit_renewal_manager/features/templates/presentation/templates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads and saves enabled/default template state', (tester) async {
    var stored = const MessageTemplate(
      id: 't1',
      name: '已有模板',
      body: '提醒 {{customerName}}',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TemplatesPage(
          bindings: TemplateBindings(
            load: () async => [stored],
            save: (value) async {
              stored = value;
              return value;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, '设为默认模板'));
    await tester.tap(find.widgetWithText(OutlinedButton, '保存模板'));
    await tester.pumpAndSettle();

    expect(stored.isDefault, isTrue);
    expect(stored.isEnabled, isTrue);
    expect(find.text('模板已保存'), findsOneWidget);
  });
}
