import 'package:deposit_renewal_manager/features/text_import/presentation/text_import_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not save parsed text before explicit confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TextImportPage()));
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存'),
    );
    expect(save.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '姓名：张三 手机：13800138000');
    await tester.tap(find.text('识别字段'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存'))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('允许写入本地数据库'), findsOneWidget);
  });
}
