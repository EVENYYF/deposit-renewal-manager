import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deposit_renewal_manager/features/excel_import/application/xlsx_preview_service.dart';
import 'package:deposit_renewal_manager/features/excel_import/domain/import_models.dart';

void main() {
  const service = XlsxPreviewService();
  test('rejects legacy xls before reading', () async {
    await expectLater(
      service.preview('missing.xls'),
      throwsA(isA<UnsupportedSpreadsheetException>()),
    );
  });
  test('previews a standard xlsx with normalized values', () async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow(
      [
        'name',
        'phone',
        'amount',
        'bankName',
        'interestRate',
        'startDate',
        'term',
      ].map(TextCellValue.new).toList(),
    );
    sheet.appendRow([
      TextCellValue('Alice'),
      TextCellValue('138 0013 8000'),
      DoubleCellValue(100.25),
      TextCellValue('Bank'),
      DoubleCellValue(2.5),
      IntCellValue(45292),
      IntCellValue(12),
    ]);
    final file = File(
      '${Directory.systemTemp.path}/import-${DateTime.now().microsecondsSinceEpoch}.xlsx',
    );
    try {
      await file.writeAsBytes(excel.encode()!);
      final result = await service.preview(file.path);
      expect(result.rows.single.isValid, isTrue);
      expect(result.rows.single.normalized['amountCents'], 10025);
      expect(result.rows.single.normalized['startDate'], '2024-01-01');
      expect(result.rows.single.normalized['phone'], '13800138000');
      expect(result.rows.single.normalized['interestRateScaled'], 250);
      expect(result.rows.single.normalized['ratePrecision'], 2);
      expect(result.rows.single.availableDecisions, {
        DuplicateDecision.createSeparate,
      });
    } finally {
      if (await file.exists()) await file.delete();
    }
  });

  test('preserves two decimal places for percentage interest rates', () async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow(
      [
        'name',
        'phone',
        'amount',
        'interestRate',
        'startDate',
        'term',
      ].map(TextCellValue.new).toList(),
    );
    sheet.appendRow([
      TextCellValue('Alice'),
      TextCellValue('138-0013-8000'),
      IntCellValue(100),
      DoubleCellValue(1.25),
      IntCellValue(45292),
      IntCellValue(12),
    ]);

    final result = await service.previewBytes(excel.encode()!);

    expect(result.rows.single.isValid, isTrue);
    expect(result.rows.single.normalized['phone'], '13800138000');
    expect(result.rows.single.normalized['interestRateScaled'], 125);
    expect(result.rows.single.normalized['ratePrecision'], 2);
  });

  test(
    'rejects invalid phone separators and out of range rates per row',
    () async {
      final excel = Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet()!];
      sheet.appendRow(
        [
          'name',
          'phone',
          'amount',
          'interestRate',
          'startDate',
          'term',
        ].map(TextCellValue.new).toList(),
      );
      sheet.appendRow([
        TextCellValue('Alice'),
        TextCellValue('138  0013 8000'),
        IntCellValue(100),
        DoubleCellValue(100.01),
        IntCellValue(45292),
        IntCellValue(12),
      ]);

      final result = await service.previewBytes(excel.encode()!);

      expect(
        result.rows.single.errors,
        containsAll(['invalid phone', 'invalid interest rate']),
      );
    },
  );

  test('rejects incomplete and duplicate field mappings', () async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow(
      [
        'name',
        'phone',
        'amount',
        'startDate',
        'term',
      ].map(TextCellValue.new).toList(),
    );
    final bytes = excel.encode()!;

    await expectLater(
      service.previewBytes(bytes, mapping: const {'name': ImportField.name}),
      throwsA(isA<UnsupportedSpreadsheetException>()),
    );
    await expectLater(
      service.previewBytes(
        bytes,
        mapping: const {
          'name': ImportField.name,
          'phone': ImportField.name,
          'amount': ImportField.amount,
          'startDate': ImportField.startDate,
          'term': ImportField.term,
        },
      ),
      throwsA(isA<UnsupportedSpreadsheetException>()),
    );
  });

  test('numeric date parser rejects non-finite and out of range values', () {
    expect(parseImportDate(double.nan), isNull);
    expect(parseImportDate(double.infinity), isNull);
    expect(parseImportDate(0), isNull);
    expect(parseImportDate(2958466), isNull);
  });
}
