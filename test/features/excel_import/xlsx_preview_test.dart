import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/features/excel_import/application/duplicate_resolver.dart';
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

  test('uses the Excel 1900 serial boundaries including the leap-day gap', () {
    expect(parseImportDate(1)?.toString(), '1900-01-01');
    expect(parseImportDate(59)?.toString(), '1900-02-28');
    expect(parseImportDate(60), isNull);
    expect(parseImportDate(60.5), isNull);
    expect(parseImportDate(61)?.toString(), '1900-03-01');
  });

  test('allows serial zero in the Excel 1904 date system', () {
    expect(
      parseImportDate(0, dateSystem: ExcelDateSystem.excel1904)?.toString(),
      '1904-01-01',
    );
  });

  test('rejects date-formatted cells in the Excel 1904 workbook mode', () async {
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
      TextCellValue('13800138000'),
      IntCellValue(100),
      DoubleCellValue(2.5),
      DateCellValue(year: 2024, month: 1, day: 1),
      IntCellValue(12),
    ]);
    final result = await service.previewBytes(
      excel.encode()!,
      dateSystem: ExcelDateSystem.excel1904,
    );
    expect(
      result.rows.single.errors,
      contains(
        '1904 workbook date-formatted cells unsupported; use numeric serial/text',
      ),
    );
  });

  test('accepts DateTimeCellValue in Excel 1900 mode', () async {
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
      TextCellValue('13800138000'),
      IntCellValue(100),
      DoubleCellValue(2.5),
      DateTimeCellValue(year: 2024, month: 1, day: 1, hour: 9, minute: 0),
      IntCellValue(12),
    ]);
    final result = await service.previewBytes(excel.encode()!);
    expect(result.rows.single.errors, isNot(contains('invalid start date')));
    expect(result.rows.single.normalized['startDate'], '2024-01-01');
  });

  test('supports the Excel 1904 date system', () async {
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
      TextCellValue('13800138000'),
      IntCellValue(100),
      DoubleCellValue(2.5),
      IntCellValue(1),
      IntCellValue(12),
    ]);
    final result = await service.previewBytes(
      excel.encode()!,
      dateSystem: ExcelDateSystem.excel1904,
    );
    expect(result.dateSystem, ExcelDateSystem.excel1904);
    expect(result.rows.single.isValid, isTrue);
    expect(result.rows.single.normalized['startDate'], '1904-01-02');
    expect(
      parseImportDate(1, dateSystem: ExcelDateSystem.excel1904)?.toString(),
      '1904-01-02',
    );
  });

  test(
    'missing interest rate is a row error and date config is strict',
    () async {
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
      sheet.appendRow([
        TextCellValue('Alice'),
        TextCellValue('13800138000'),
        IntCellValue(100),
        IntCellValue(45292),
        IntCellValue(12),
      ]);

      final preview = await service.previewBytes(excel.encode()!);

      expect(preview.rows.single.errors, contains('invalid interest rate'));
      expect(() => ExcelDateSystem.parse('automatic'), throwsArgumentError);
    },
  );

  test(
    'resolver candidates and field conflicts are visible on preview',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      try {
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
          TextCellValue('New Name'),
          TextCellValue('13800138000'),
          IntCellValue(100),
          DoubleCellValue(2.5),
          IntCellValue(45292),
          IntCellValue(12),
        ]);
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await database
            .into(database.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'existing',
                name: 'Old Name',
                phone: const Value('13800138000'),
                normalizedName: const Value('oldname'),
                fullPinyin: const Value('oldname'),
                initials: const Value('on'),
                normalizedPhone: const Value('13800138000'),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
        final preview = await service.previewBytesAndResolve(
          excel.encode()!,
          resolver: DuplicateResolver(database),
        );
        expect(preview.duplicatesResolved, isTrue);
        expect(preview.candidates, hasLength(1));
        expect(
          preview.candidates.single.fieldConflicts['name']?.oldValue,
          'Old Name',
        );
        expect(
          preview.rows.single.availableDecisions,
          DuplicateDecision.values.toSet(),
        );
      } finally {
        await database.close();
      }
    },
  );
}
