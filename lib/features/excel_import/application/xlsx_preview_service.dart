import 'dart:io';
import 'dart:isolate';
import 'package:excel/excel.dart';
import '../domain/import_models.dart';

class XlsxPreviewService {
  const XlsxPreviewService();
  Future<ImportPreview> preview(
    String path, {
    Map<String, ImportField>? mapping,
  }) async {
    if (!path.toLowerCase().endsWith('.xlsx'))
      throw const UnsupportedSpreadsheetException(
        'Only .xlsx spreadsheets are supported',
      );
    final bytes = await File(path).readAsBytes();
    return previewBytes(bytes, mapping: mapping);
  }

  Future<ImportPreview> previewBytes(
    List<int> bytes, {
    Map<String, ImportField>? mapping,
  }) {
    final m = mapping == null ? null : Map<String, ImportField>.from(mapping);
    return Isolate.run(() => _parse(bytes, m));
  }

  static ImportPreview _parse(
    List<int> bytes,
    Map<String, ImportField>? supplied,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sheetEntry = excel.tables.entries.first;
    if (excel.getMergedCells(sheetEntry.key).isNotEmpty) {
      throw const UnsupportedSpreadsheetException(
        'Merged cells are not supported in import sheets',
      );
    }
    final sheet = sheetEntry.value;
    final rows = sheet.rows;
    if (rows.isEmpty)
      return ImportPreview(rows: const [], mapping: supplied ?? const {});
    final headers = rows.first
        .map((c) => (_value(c?.value) ?? '').toString().trim())
        .toList();
    final mapping = supplied ?? _infer(headers);
    final parsed = <ImportRow>[];
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i];
      final raw = <String, Object?>{};
      for (var j = 0; j < headers.length; j++)
        raw[headers[j]] = j < cells.length ? _value(cells[j]?.value) : null;
      final normalized = <String, Object?>{};
      final errors = <String>[];
      final warnings = <String>[];
      for (final e in mapping.entries) normalized[e.value.name] = raw[e.key];
      final name = (normalized['name']?.toString() ?? '').trim();
      if (name.isEmpty)
        errors.add('name is required');
      else
        normalized['name'] = name;
      final phone = normalized['phone']?.toString().trim();
      if (phone == null || phone.isEmpty)
        errors.add('phone is required');
      else if (RegExp(r'[^0-9+()\- ]').hasMatch(phone))
        errors.add('invalid phone');
      else
        normalized['phone'] = phone;
      final amount = num.tryParse(
        (normalized['amount'] ?? '').toString().replaceAll(',', ''),
      );
      if (amount == null || amount <= 0)
        errors.add('invalid amount');
      else
        normalized['amountCents'] = (amount * 100).round();
      final date = parseImportDate(normalized['startDate']);
      if (date == null)
        errors.add('invalid start date');
      else
        normalized['startDate'] = date.toString();
      final term = int.tryParse((normalized['term'] ?? '').toString());
      if (term == null || term <= 0)
        errors.add('invalid term');
      else
        normalized['term'] = term;
      final rate = num.tryParse((normalized['interestRate'] ?? '0').toString());
      if (rate == null || rate < 0)
        errors.add('invalid interest rate');
      else
        normalized['interestRate'] = rate;
      if (normalized['expiryMode'] == null)
        warnings.add('expiry mode defaults to term');
      parsed.add(
        ImportRow(
          rowNumber: i + 1,
          raw: raw,
          normalized: normalized,
          errors: errors,
          warnings: warnings,
          availableDecisions: errors.isEmpty
              ? DuplicateDecision.values.toSet()
              : const {},
        ),
      );
    }
    return ImportPreview(rows: parsed, mapping: mapping, headers: headers);
  }

  static Map<String, ImportField> _infer(List<String> h) {
    final out = <String, ImportField>{};
    for (final x in h) {
      final n = x.toLowerCase().replaceAll(RegExp(r'[ _-]'), '');
      for (final f in ImportField.values) {
        if (n == f.name.toLowerCase() ||
            (f == ImportField.name && n.contains('姓名')) ||
            (f == ImportField.phone && n.contains('手机')) ||
            (f == ImportField.amount && n.contains('金额')) ||
            (f == ImportField.startDate && n.contains('起息')) ||
            (f == ImportField.term && n.contains('期限')))
          out[x] = f;
      }
    }
    return out;
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
