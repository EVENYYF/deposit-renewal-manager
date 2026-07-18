import '../../deposits/domain/local_date.dart';

enum DuplicateDecision { attachToExisting, createSeparate, skip }

enum ImportField {
  name,
  phone,
  amount,
  bankName,
  interestRate,
  startDate,
  term,
  expiryMode,
}

class UnsupportedSpreadsheetException implements Exception {
  const UnsupportedSpreadsheetException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ImportCellError {
  const ImportCellError(this.message);
  final String message;
}

class ImportRow {
  ImportRow({
    required this.rowNumber,
    required this.raw,
    required this.normalized,
    this.errors = const [],
    this.warnings = const [],
    Set<DuplicateDecision> availableDecisions = const {},
  }) : availableDecisions = Set.of(availableDecisions);
  final int rowNumber;
  final Map<String, Object?> raw;
  final Map<String, Object?> normalized;
  final List<String> errors;
  final List<String> warnings;
  final Set<DuplicateDecision> availableDecisions;
  bool get isValid => errors.isEmpty;
}

class ImportPreview {
  const ImportPreview({
    required this.rows,
    required this.mapping,
    this.headers = const [],
  });
  final List<ImportRow> rows;
  final Map<String, ImportField> mapping;
  final List<String> headers;
  Iterable<ImportRow> get validRows => rows.where((r) => r.isValid);
  Iterable<ImportRow> get invalidRows => rows.where((r) => !r.isValid);
}

class DuplicateCandidate {
  const DuplicateCandidate({
    required this.row,
    required this.existingCustomerId,
    required this.fieldConflicts,
  });
  final ImportRow row;
  final String existingCustomerId;
  final Map<String, ({Object? oldValue, Object? newValue})> fieldConflicts;
  Set<DuplicateDecision> get availableDecisions => const {
    DuplicateDecision.attachToExisting,
    DuplicateDecision.createSeparate,
    DuplicateDecision.skip,
  };
}

class ImportResult {
  const ImportResult({
    required this.batchId,
    required this.importedRows,
    required this.skippedRows,
    required this.failedRows,
    required this.affectedCustomerIds,
    required this.completedBusinessRevision,
    required this.preSnapshotId,
    this.warnings = const [],
  });
  final String batchId;
  final int importedRows, skippedRows, failedRows, completedBusinessRevision;
  final List<String> affectedCustomerIds;
  final String? preSnapshotId;
  final List<String> warnings;
}

LocalDate? parseImportDate(Object? value) {
  if (value is DateTime) return LocalDate(value.year, value.month, value.day);
  if (value is num) {
    final serial = value.toDouble();
    if (!serial.isFinite || serial < 1 || serial > 2958465) return null;
    try {
      final d = DateTime.utc(
        1899,
        12,
        30,
      ).add(Duration(milliseconds: (serial * 86400000).round()));
      if (d.year < 1900 || d.year > 9999) return null;
      return LocalDate(d.year, d.month, d.day);
    } catch (_) {
      return null;
    }
  }
  final s = value?.toString().trim() ?? '';
  final m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(s);
  if (m == null) return null;
  try {
    return LocalDate(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  } catch (_) {
    return null;
  }
}
