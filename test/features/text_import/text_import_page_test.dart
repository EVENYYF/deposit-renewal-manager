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

  testWidgets('consumes a confirmed parse only once after save', (
    tester,
  ) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(home: TextImportPage(onConfirmedSave: (_) async => saves++)),
    );

    await tester.enterText(find.byType(TextField), '姓名：张三 手机：13800138000');
    await tester.tap(find.text('识别字段'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    final save = find.widgetWithText(FilledButton, '保存');
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(save);
    await tester.pump();
    expect(saves, 1);
  });

  testWidgets('saves the edited field values only after applying them', (
    tester,
  ) async {
    Object? savedName;
    await tester.binding.setSurfaceSize(const Size(600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TextImportPage(
          onConfirmedSave: (result) async => savedName = result.name,
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField).first,
      '姓名：张三 手机：13800138000 金额：10万元 '
      '存入日：2026-07-19 到期日：2027-07-19',
    );
    await tester.tap(find.text('识别字段'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('parsed-name')), '李四');
    await tester.ensureVisible(find.text('应用字段修改'));
    await tester.tap(find.text('应用字段修改'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '保存'));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(savedName, '李四');
  });

  testWidgets('requires an explicit field confirmation to resolve conflicts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TextImportPage(onConfirmedSave: (_) async {})),
    );

    await tester.enterText(
      find.byType(TextField).first,
      '姓名：张三 手机：13800138000 手机：13900139000 '
      '金额：10万元 存入日：2026-07-19 到期日：2027-07-19',
    );
    await tester.tap(find.text('识别字段'));
    await tester.pumpAndSettle();

    expect(find.text('检测到多个候选，请确认此值'), findsWidgets);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    await tester.ensureVisible(find.text('确认字段并消除冲突'));
    await tester.tap(find.text('确认字段并消除冲突'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNotNull,
    );
  });
}
