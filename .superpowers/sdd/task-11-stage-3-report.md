# Task 11 Stage 3 Report

## Scope

Completed the remaining interactive import workflows on baseline `e2ad9d9`:

- Excel custom header-to-field mapping, using `XlsxPreviewService` mapping input.
- Invalid row correction and explicit row skipping before duplicate resolution.
- Batch application of duplicate decisions while preserving per-row overrides.
- Editable offline text-recognition fields with explicit conflict confirmation.
- Existing picker cancellation and human-confirmation save guards remain intact.

Database schema, transaction handling, notification scheduling, backup, and
import hashing were not changed.

## Implementation Notes

- `ExcelImportBindings.preview` now accepts an optional named mapping and the
  application binding forwards it to `XlsxPreviewService.previewBytes`.
- `ImportPreview.copyWith` can replace presentation-owned row and mapping
  collections without mutating the original preview.
- Skipped invalid rows are removed from the effective preview before duplicate
  resolution and are included in the displayed skipped-row total.
- Corrected rows are rebuilt as valid normalized rows; the existing resolver
  and commit service remain the only duplicate and persistence paths.
- Text edits rebuild a confirmed `ParseResult`. Any edit clears prior user
  confirmation, and unresolved/dirty drafts cannot be saved.

## Verification

- `flutter analyze`: PASS, no issues.
- Focused widget tests: PASS, 8 tests.
- Full `flutter test`: PASS, 187 tests.
- `git diff --check`: PASS (only repository line-ending notices).

The full suite still emits the pre-existing Drift multiple-database warning in
backup tests; all tests pass and this task did not modify database ownership.
