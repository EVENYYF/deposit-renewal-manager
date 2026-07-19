import 'package:deposit_renewal_manager/features/excel_import/domain/import_models.dart';
import 'package:deposit_renewal_manager/features/excel_import/presentation/import_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows all five stages and treats picker cancellation normally', (
    tester,
  ) async {
    final bindings = ExcelImportBindings(
      preview: (_) async => const ImportPreview(rows: [], mapping: {}),
      resolve: (preview) async => preview.copyWith(duplicatesResolved: true),
      commit: (preview, resolutions, contentHash) async => const ImportResult(
        batchId: 'b',
        importedRows: 0,
        skippedRows: 0,
        failedRows: 0,
        affectedCustomerIds: [],
        completedBusinessRevision: 0,
        preSnapshotId: null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ExcelImportWizard(bindings: bindings, pickFile: () async => null),
      ),
    );

    expect(find.text('选择文件'), findsWidgets);
    expect(find.text('映射字段'), findsOneWidget);
    expect(find.text('校验预览'), findsOneWidget);
    expect(find.text('处理重复'), findsOneWidget);
    expect(find.text('确认导入'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, '选择文件'));
    await tester.pumpAndSettle();
    expect(find.textContaining('失败'), findsNothing);
  });
}
