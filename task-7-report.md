# Task 7 Excel 导入报告

已实现 `.xlsx` 预览解析、表头映射、字段规范化、重复决策模型、事务导入、批次审计和撤销守卫。

验证：

- `flutter test test/features/excel_import/xlsx_preview_test.dart`：通过
- `flutter analyze`：无 error（仅现有 lint info）
- `flutter test`：99 tests passed

实现说明：旧式 `.xls`、公式单元格和合并单元格在解析前/解析时显式拒绝；Excel serial date 转换采用 1899-12-30 基准。导入前调用注入快照函数，客户、存款、批次、审计和 revision 在单个 Drift transaction 中提交；失败由事务回滚。撤销仅允许最新导入且 revision 未变化，并从审计中取得 preSnapshotId。
## Task7 hardening verification (2026-07-19)

- XLSX preview enforces 50 MiB, one worksheet, 10,000 rows, and 50 columns;
  malformed cells become row-level errors.
- Required mappings and unique headers are validated. Phones use strict
  3-4-4 mobile formatting and rates use Decimal fixed-point percentage
  storage (`interestRateScaled` and `ratePrecision`).
- DuplicateResolver reports existing customers and field conflicts. Commit
  rejects incompatible decisions and duplicate content hashes, records audit
  hash/snapshot/revision metadata, and returns hook failures as warnings.
- Undo re-checks audit id and business revision under a write-locked
  transaction before restoring the pre-import snapshot.
- Verification: `flutter analyze` clean; full `flutter test` passed (109
  tests); `git diff --check` clean.
## Task7 idempotency and decision closure (2026-07-19)

- Preview preparation now resolves database duplicates into
  `ImportPreview.candidates`, including field conflicts and per-row decisions.
  Commit rejects previews that did not complete duplicate resolution and
  re-checks candidate identity against the database.
- Import content hashes are protected by a schema v3 unique index. Migration
  detects legacy duplicate hashes and fails without advancing the schema.
  Hash conflicts are reported as `DuplicateImportException`.
- Duplicate rows require an explicit decision. Row numbers, nonduplicate
  decisions, and field choices are validated before snapshot or database work.
- Excel numeric dates carry an explicit 1900/1904 date-system setting through
  preview metadata. Missing interest rates remain row errors rather than
  becoming zero silently.
- Verification: targeted migration/import tests passed (35 tests),
  `flutter analyze` is clean, and the full suite passed (118 tests).
