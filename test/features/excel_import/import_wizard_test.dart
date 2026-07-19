import 'dart:typed_data';

import 'package:deposit_renewal_manager/features/excel_import/domain/import_models.dart';
import 'package:deposit_renewal_manager/features/excel_import/presentation/import_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows all five stages and treats picker cancellation normally', (
    tester,
  ) async {
    final bindings = _bindings(preview: _emptyPreview);
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

  testWidgets('passes the confirmed custom mapping back to preview service', (
    tester,
  ) async {
    Map<String, ImportField>? captured;
    final preview = _validPreview();
    final bindings = ExcelImportBindings(
      preview: (_, {mapping}) async {
        captured = mapping;
        return preview;
      },
      resolve: (value) async => value.copyWith(duplicatesResolved: true),
      commit: (_, _, _) async => _result,
    );
    await _pumpWizard(tester, bindings);

    await tester.tap(find.widgetWithText(FilledButton, '选择文件'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '确认映射'));
    await tester.tap(find.widgetWithText(FilledButton, '确认映射'));
    await tester.pumpAndSettle();

    expect(captured, preview.mapping);
    expect(find.textContaining('有效 1 行'), findsOneWidget);
  });

  testWidgets('an invalid row can be corrected before duplicate resolution', (
    tester,
  ) async {
    ImportPreview? resolvedInput;
    final invalid = _validPreview(
      rows: [
        ImportRow(
          rowNumber: 2,
          raw: const {},
          normalized: const {
            'name': '张三',
            'phone': '错误号码',
            'amount': '10000',
            'startDate': '2026-07-19',
            'term': 12,
            'interestRate': '2.1',
          },
          errors: const ['invalid phone'],
        ),
      ],
    );
    final bindings = ExcelImportBindings(
      preview: (_, {mapping}) async => invalid,
      resolve: (value) async {
        resolvedInput = value;
        return value.copyWith(duplicatesResolved: true);
      },
      commit: (_, _, _) async => _result,
    );
    await _pumpWizard(tester, bindings);
    await _reachValidation(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, '修正此行'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('correct-phone')),
      '13800138000',
    );
    await tester.tap(find.widgetWithText(FilledButton, '应用修正'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '检查重复客户'));
    await tester.tap(find.widgetWithText(FilledButton, '检查重复客户'));
    await tester.pumpAndSettle();

    expect(resolvedInput!.rows.single.isValid, isTrue);
    expect(resolvedInput!.rows.single.normalized['phone'], '13800138000');
  });

  testWidgets(
    'invalid rows may be skipped and duplicate decisions batch applied',
    (tester) async {
      Map<int, DuplicateDecision>? committed;
      final invalidRow = ImportRow(
        rowNumber: 4,
        raw: const {},
        normalized: const {},
        errors: const ['name is required'],
      );
      final rows = [_row(2), _row(3), invalidRow];
      final preview = _validPreview(rows: rows);
      final bindings = ExcelImportBindings(
        preview: (_, {mapping}) async => preview,
        resolve: (value) async => value.copyWith(
          candidates: [
            for (final row in value.rows)
              DuplicateCandidate(
                row: row,
                existingCustomerId: 'customer-${row.rowNumber}',
                fieldConflicts: const {},
              ),
          ],
          duplicatesResolved: true,
        ),
        commit: (_, _, decisions) async {
          committed = Map.of(decisions);
          return _result;
        },
      );
      await _pumpWizard(tester, bindings);
      await _reachValidation(tester);

      await tester.tap(find.widgetWithText(FilterChip, '跳过此行'));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(FilledButton, '检查重复客户'));
      await tester.tap(find.widgetWithText(FilledButton, '检查重复客户'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('批量应用处理方式'));
      await tester.tap(find.text('批量应用处理方式'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部新增独立客户'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, '确认重复处理'));
      await tester.tap(find.widgetWithText(FilledButton, '确认重复处理'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, '确认导入'));
      await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
      await tester.pumpAndSettle();

      expect(committed, {
        2: DuplicateDecision.createSeparate,
        3: DuplicateDecision.createSeparate,
      });
    },
  );
}

Future<void> _pumpWizard(
  WidgetTester tester,
  ExcelImportBindings bindings,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: ExcelImportWizard(
        bindings: bindings,
        pickFile: () async => PickedSpreadsheet(
          name: 'customers.xlsx',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ),
    ),
  );
}

Future<void> _reachValidation(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '选择文件'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.widgetWithText(FilledButton, '确认映射'));
  await tester.tap(find.widgetWithText(FilledButton, '确认映射'));
  await tester.pumpAndSettle();
}

ExcelImportBindings _bindings({required ImportPreview preview}) =>
    ExcelImportBindings(
      preview: (_, {mapping}) async => preview,
      resolve: (value) async => value.copyWith(duplicatesResolved: true),
      commit: (_, _, _) async => _result,
    );

const _emptyPreview = ImportPreview(rows: [], mapping: {});

ImportPreview _validPreview({List<ImportRow>? rows}) => ImportPreview(
  rows: rows ?? [_row(2)],
  headers: const ['姓名', '手机号', '金额', '起息日', '期限', '利率'],
  mapping: const {
    '姓名': ImportField.name,
    '手机号': ImportField.phone,
    '金额': ImportField.amount,
    '起息日': ImportField.startDate,
    '期限': ImportField.term,
    '利率': ImportField.interestRate,
  },
);

ImportRow _row(int number) => ImportRow(
  rowNumber: number,
  raw: const {},
  normalized: {
    'name': '客户$number',
    'phone': '1380013800$number',
    'amountCents': 1000000,
    'startDate': '2026-07-19',
    'term': 12,
    'interestRateScaled': 210,
    'ratePrecision': 2,
  },
);

const _result = ImportResult(
  batchId: 'batch',
  importedRows: 2,
  skippedRows: 0,
  failedRows: 0,
  affectedCustomerIds: [],
  completedBusinessRevision: 1,
  preSnapshotId: null,
);
