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
    } finally {
      if (await file.exists()) await file.delete();
    }
  });
}
