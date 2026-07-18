import 'package:drift/drift.dart';

Expression<bool> isoDateTextCheck(String column) => CustomExpression<bool>(
  "length($column) = 10 AND "
  "$column GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND "
  "CAST(substr($column, 6, 2) AS INTEGER) BETWEEN 1 AND 12 AND "
  "CAST(substr($column, 9, 2) AS INTEGER) BETWEEN 1 AND "
  "CASE "
  "WHEN CAST(substr($column, 6, 2) AS INTEGER) IN (4, 6, 9, 11) THEN 30 "
  "WHEN CAST(substr($column, 6, 2) AS INTEGER) = 2 THEN "
  "CASE WHEN (CAST(substr($column, 1, 4) AS INTEGER) % 4 = 0 AND "
  "CAST(substr($column, 1, 4) AS INTEGER) % 100 != 0) OR "
  "CAST(substr($column, 1, 4) AS INTEGER) % 400 = 0 THEN 29 ELSE 28 END "
  "ELSE 31 END",
);

Expression<bool> utcEpochCheck(String column) =>
    CustomExpression<bool>("typeof($column) = 'integer' AND $column > 0");

@TableIndex(name: 'customers_normalized_name_idx', columns: {#normalizedName})
@TableIndex(name: 'customers_full_pinyin_idx', columns: {#fullPinyin})
@TableIndex(name: 'customers_initials_idx', columns: {#initials})
@TableIndex(name: 'customers_normalized_phone_idx', columns: {#normalizedPhone})
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().check(name.length.isBiggerThanValue(0))();
  TextColumn get phone => text().nullable()();
  TextColumn get normalizedName => text().withDefault(const Constant(''))();
  TextColumn get fullPinyin => text().withDefault(const Constant(''))();
  TextColumn get initials => text().withDefault(const Constant(''))();
  TextColumn get normalizedPhone => text().withDefault(const Constant(''))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAtUtc =>
      integer().check(utcEpochCheck('created_at_utc'))();
  IntColumn get updatedAtUtc =>
      integer().check(utcEpochCheck('updated_at_utc'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE INDEX deposits_bank_name_idx '
  'ON deposits (bank_name COLLATE NOCASE)',
)
@TableIndex(
  name: 'deposits_expiry_lifecycle_customer_idx',
  columns: {#finalExpiryDate, #lifecycle, #customerId},
)
class Deposits extends Table {
  TextColumn get id => text()();
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();
  IntColumn get amountCents =>
      integer().check(const CustomExpression<bool>('amount_cents > 0'))();
  TextColumn get bankName => text().withDefault(const Constant(''))();
  IntColumn get interestRateScaled => integer().check(
    const CustomExpression<bool>('interest_rate_scaled >= 0'),
  )();
  IntColumn get ratePrecision => integer().check(
    const CustomExpression<bool>('rate_precision BETWEEN 0 AND 9'),
  )();
  TextColumn get startDate => text().check(isoDateTextCheck('start_date'))();
  TextColumn get calculatedExpiryDate =>
      text().nullable().check(isoDateTextCheck('calculated_expiry_date'))();
  TextColumn get finalExpiryDate =>
      text().check(isoDateTextCheck('final_expiry_date'))();
  TextColumn get lifecycle => text().check(
    const CustomExpression<bool>(
      "lifecycle IN ('active', 'renewed', 'stopped')",
    ),
  )();
  IntColumn get createdAtUtc =>
      integer().check(utcEpochCheck('created_at_utc'))();
  IntColumn get updatedAtUtc =>
      integer().check(utcEpochCheck('updated_at_utc'))();
  TextColumn get sourceDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Renewals extends Table {
  TextColumn get id => text()();
  @ReferenceName('sourceRenewals')
  TextColumn get sourceDepositId =>
      text().unique().references(Deposits, #id, onDelete: KeyAction.restrict)();
  @ReferenceName('targetRenewal')
  TextColumn get targetDepositId =>
      text().unique().references(Deposits, #id, onDelete: KeyAction.restrict)();
  IntColumn get renewedAtUtc =>
      integer().check(utcEpochCheck('renewed_at_utc'))();
  TextColumn get sourceDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AuditHistory extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
  IntColumn get occurredAtUtc =>
      integer().check(utcEpochCheck('occurred_at_utc'))();
  TextColumn get sourceDeviceId => text()();
  IntColumn get businessRevision =>
      integer().check(const CustomExpression<bool>('business_revision > 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MessageTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get content => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAtUtc =>
      integer().check(utcEpochCheck('created_at_utc'))();
  IntColumn get updatedAtUtc =>
      integer().check(utcEpochCheck('updated_at_utc'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'import_batches_content_hash_idx',
  columns: {#contentHash},
  unique: true,
)
class ImportBatches extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get contentHash => text()();
  IntColumn get importedRows => integer().withDefault(const Constant(0))();
  IntColumn get rejectedRows => integer().withDefault(const Constant(0))();
  IntColumn get importedAtUtc =>
      integer().check(utcEpochCheck('imported_at_utc'))();
  TextColumn get sourceDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BusinessSettings extends Table {
  IntColumn get singletonId =>
      integer().check(const CustomExpression<bool>('singleton_id = 1'))();
  IntColumn get businessRevision => integer()
      .withDefault(const Constant(0))
      .check(const CustomExpression<bool>('business_revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};
}

class NotificationIdMappings extends Table {
  TextColumn get entityId => text()();
  IntColumn get notificationId => integer().unique()();
  IntColumn get createdAtUtc =>
      integer().check(utcEpochCheck('created_at_utc'))();

  @override
  Set<Column<Object>> get primaryKey => {entityId};
}
