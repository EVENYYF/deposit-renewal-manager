import 'dart:io';
import 'dart:isolate';

import 'package:decimal/decimal.dart';
import 'package:excel/excel.dart';

import '../domain/import_models.dart';
import 'duplicate_resolver.dart';

class XlsxPreviewService {
  const XlsxPreviewService();

  static const maxFileBytes = 50 * 1024 * 1024;
  static const maxRows = 10000;
  static const maxColumns = 50;
  static const maxSheets = 20;

  Future<ImportPreview> preview(
    String path, {
    Map<String, ImportField>? mapping,
    ExcelDateSystem dateSystem = ExcelDateSystem.excel1900,
  }) async {
    if (!path.toLowerCase().endsWith('.xlsx')) {
      throw const UnsupportedSpreadsheetException(
        'Only .xlsx spreadsheets are supported',
      );
    }
    final file = File(path);
    late final int size;
    try {
      size = await file.length();
    } catch (_) {
      throw const UnsupportedSpreadsheetException(
        'Unable to read the spreadsheet file',
      );
    }
    if (size > maxFileBytes) {
      throw const UnsupportedSpreadsheetException(
        'Spreadsheet exceeds the 50 MiB import limit',
      );
    }
    late final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const UnsupportedSpreadsheetException(
        'Unable to read the spreadsheet file',
      );
    }
    return previewBytes(bytes, mapping: mapping, dateSystem: dateSystem);
  }

  /// Parses and runs duplicate resolution, making candidates part of the preview.
  Future<ImportPreview> previewAndResolve(
    String path, {
    required DuplicateResolver resolver,
    Map<String, ImportField>? mapping,
    ExcelDateSystem dateSystem = ExcelDateSystem.excel1900,
  }) async {
    final parsed = await preview(
      path,
      mapping: mapping,
      dateSystem: dateSystem,
    );
    return resolver.resolvePreview(parsed);
  }

  Future<ImportPreview> previewBytes(
    List<int> bytes, {
    Map<String, ImportField>? mapping,
    ExcelDateSystem dateSystem = ExcelDateSystem.excel1900,
  }) {
    if (bytes.length > maxFileBytes) {
      throw const UnsupportedSpreadsheetException(
        'Spreadsheet exceeds the 50 MiB import limit',
      );
    }
    final copiedMapping = mapping == null
        ? null
        : Map<String, ImportField>.from(mapping);
    return Isolate.run(() => _parse(bytes, copiedMapping, dateSystem));
  }

  Future<ImportPreview> previewBytesAndResolve(
    List<int> bytes, {
    required DuplicateResolver resolver,
    Map<String, ImportField>? mapping,
    ExcelDateSystem dateSystem = ExcelDateSystem.excel1900,
  }) async {
    final parsed = await previewBytes(
      bytes,
      mapping: mapping,
      dateSystem: dateSystem,
    );
    return resolver.resolvePreview(parsed);
  }

  static ImportPreview _parse(
    List<int> bytes,
    Map<String, ImportField>? supplied,
    ExcelDateSystem dateSystem,
  ) {
    late final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const UnsupportedSpreadsheetException(
        'The spreadsheet is damaged or is not a valid .xlsx file',
      );
    }
    if (excel.tables.isEmpty) {
      throw const UnsupportedSpreadsheetException(
        'The spreadsheet does not contain a worksheet',
      );
    }
    if (excel.tables.length > maxSheets) {
      throw const UnsupportedSpreadsheetException(
        'The spreadsheet exceeds the 20 worksheet import limit',
      );
    }
    if (excel.tables.length != 1) {
      throw const UnsupportedSpreadsheetException(
        'Exactly one worksheet is required for import',
      );
    }
    final sheetEntry = excel.tables.entries.first;
    if (excel.getMergedCells(sheetEntry.key).isNotEmpty) {
      throw const UnsupportedSpreadsheetException(
        'Merged cells are not supported in import sheets',
      );
    }
    final rows = sheetEntry.value.rows;
    if (rows.length > maxRows) {
      throw const UnsupportedSpreadsheetException(
        'The worksheet exceeds the 10000 row import limit',
      );
    }
    if (rows.any((row) => row.length > maxColumns)) {
      throw const UnsupportedSpreadsheetException(
        'The worksheet exceeds the 50 column import limit',
      );
    }
    if (rows.isEmpty) {
      return ImportPreview(
        rows: const [],
        mapping: supplied ?? const {},
        dateSystem: dateSystem,
      );
    }

    final headers = <String>[];
    for (final cell in rows.first) {
      try {
        headers.add((_value(cell?.value) ?? '').toString().trim());
      } catch (_) {
        throw const UnsupportedSpreadsheetException(
          'Header cells must contain plain text values',
        );
      }
    }
    _validateHeaders(headers);
    final mapping = supplied ?? _infer(headers);
    _validateMapping(mapping, headers);

    final parsed = <ImportRow>[];
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i];
      final raw = <String, Object?>{};
      final errors = <String>[];
      for (var j = 0; j < headers.length; j++) {
        try {
          raw[headers[j]] = j < cells.length ? _value(cells[j]?.value) : null;
        } catch (_) {
          raw[headers[j]] = null;
          errors.add('invalid value in ${headers[j]}');
        }
      }
      final normalized = <String, Object?>{};
      final warnings = <String>[];
      for (final entry in mapping.entries) {
        normalized[entry.value.name] = raw[entry.key];
      }

      final name = (normalized['name']?.toString() ?? '').trim();
      if (name.isEmpty) {
        errors.add('name is required');
      } else {
        normalized['name'] = name;
      }

      final phone = _normalizePhone(normalized['phone']);
      if (phone == null) {
        errors.add(
          normalized['phone'] == null ||
                  normalized['phone'].toString().trim().isEmpty
              ? 'phone is required'
              : 'invalid phone',
        );
      } else {
        normalized['phone'] = phone;
      }

      final amount = num.tryParse(
        (normalized['amount'] ?? '').toString().replaceAll(',', ''),
      );
      if (amount == null || !amount.toDouble().isFinite || amount <= 0) {
        errors.add('invalid amount');
      } else {
        normalized['amountCents'] = (amount * 100).round();
      }

      final date = parseImportDate(
        normalized['startDate'],
        dateSystem: dateSystem,
      );
      if (date == null) {
        errors.add('invalid start date');
      } else {
        normalized['startDate'] = date.toString();
      }

      final term = int.tryParse((normalized['term'] ?? '').toString());
      if (term == null || term <= 0) {
        errors.add('invalid term');
      } else {
        normalized['term'] = term;
      }

      final rate = _parseRate(normalized['interestRate']);
      if (rate == null) {
        errors.add('invalid interest rate');
      } else {
        normalized['interestRateScaled'] = rate;
        normalized['ratePrecision'] = 2;
      }
      if (normalized['expiryMode'] == null) {
        warnings.add('expiry mode defaults to term');
      }
      parsed.add(
        ImportRow(
          rowNumber: i + 1,
          raw: raw,
          normalized: normalized,
          errors: errors,
          warnings: warnings,
          availableDecisions: errors.isEmpty
              ? {DuplicateDecision.createSeparate}
              : const {},
        ),
      );
    }
    return ImportPreview(
      rows: parsed,
      mapping: mapping,
      headers: headers,
      dateSystem: dateSystem,
    );
  }

  static void _validateHeaders(List<String> headers) {
    if (headers.isEmpty || headers.any((header) => header.isEmpty)) {
      throw const UnsupportedSpreadsheetException(
        'Header names must not be empty',
      );
    }
    if (headers.toSet().length != headers.length) {
      throw const UnsupportedSpreadsheetException(
        'Header names must be unique',
      );
    }
  }

  static void _validateMapping(
    Map<String, ImportField> mapping,
    List<String> headers,
  ) {
    if (mapping.keys.any(
      (header) => header.isEmpty || !headers.contains(header),
    )) {
      throw const UnsupportedSpreadsheetException(
        'Field mapping contains an unknown or empty header',
      );
    }
    if (mapping.values.toSet().length != mapping.length) {
      throw const UnsupportedSpreadsheetException(
        'Each import field can only be mapped once',
      );
    }
    const required = {
      ImportField.name,
      ImportField.phone,
      ImportField.amount,
      ImportField.startDate,
      ImportField.term,
    };
    if (!mapping.values.toSet().containsAll(required)) {
      throw const UnsupportedSpreadsheetException(
        'Mapping must include name, phone, amount, startDate, and term',
      );
    }
  }

  static Map<String, ImportField> _infer(List<String> headers) {
    final output = <String, ImportField>{};
    for (final header in headers) {
      final normalized = header.toLowerCase().replaceAll(RegExp(r'[ _-]'), '');
      for (final field in ImportField.values) {
        if (normalized == field.name.toLowerCase() ||
            (field == ImportField.name && normalized.contains('姓名')) ||
            (field == ImportField.phone && normalized.contains('手机')) ||
            (field == ImportField.amount && normalized.contains('金额')) ||
            (field == ImportField.startDate && normalized.contains('起息')) ||
            (field == ImportField.term && normalized.contains('期限'))) {
          output[header] = field;
        }
      }
    }
    return output;
  }

  static String? _normalizePhone(Object? value) {
    final input = value?.toString().trim() ?? '';
    if (input.isEmpty) return null;
    final compact = RegExp(r'^1[3-9]\d{9}$');
    if (compact.hasMatch(input)) return input;
    final grouped = RegExp(r'^1[3-9]\d([ -])\d{4}\1\d{4}$');
    if (!grouped.hasMatch(input)) return null;
    final normalized = input.replaceAll(RegExp(r'[ -]'), '');
    return compact.hasMatch(normalized) ? normalized : null;
  }

  static int? _parseRate(Object? value) {
    if (value == null) return null;
    final input = value.toString().trim();
    if (input.isEmpty) return null;
    final rate = Decimal.tryParse(input);
    if (rate == null ||
        rate < Decimal.zero ||
        rate > Decimal.fromInt(100) ||
        rate.scale > 2) {
      return null;
    }
    return rate.shift(2).toBigInt().toInt();
  }

  static Object? _value(CellValue? value) {
    return switch (value) {
      null => null,
      FormulaCellValue() => throw const UnsupportedSpreadsheetException(
        'Formula cells must be replaced by values before import',
      ),
      IntCellValue(:final value) => value,
      DoubleCellValue(:final value) => value,
      BoolCellValue(:final value) => value,
      DateCellValue() => value.asDateTimeUtc(),
      DateTimeCellValue() => value.asDateTimeUtc(),
      _ => value.toString(),
    };
  }
}
