import 'package:drift/drift.dart';

Expression<bool> isoDateTextCheck(String column) => CustomExpression<bool>(
  "length($column) = 10 AND "
  "$column GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'",
);

Expression<bool> utcIsoTextCheck(String column) => CustomExpression<bool>(
  "length($column) >= 20 AND substr($column, -1, 1) = 'Z'",
);

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().check(name.length.isBiggerThanValue(0))();
  TextColumn get phone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAtUtc =>
      text().check(utcIsoTextCheck('created_at_utc'))();
  TextColumn get updatedAtUtc =>
      text().check(utcIsoTextCheck('updated_at_utc'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Deposits extends Table {
  TextColumn get id => text()();
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();
  IntColumn get amountCents =>
      integer().check(const CustomExpression<bool>('amount_cents > 0'))();
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
  TextColumn get createdAtUtc =>
      text().check(utcIsoTextCheck('created_at_utc'))();
  TextColumn get updatedAtUtc =>
      text().check(utcIsoTextCheck('updated_at_utc'))();
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
  TextColumn get renewedAtUtc =>
      text().check(utcIsoTextCheck('renewed_at_utc'))();
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
  TextColumn get occurredAtUtc =>
      text().check(utcIsoTextCheck('occurred_at_utc'))();
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
  TextColumn get createdAtUtc =>
      text().check(utcIsoTextCheck('created_at_utc'))();
  TextColumn get updatedAtUtc =>
      text().check(utcIsoTextCheck('updated_at_utc'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ImportBatches extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get contentHash => text()();
  IntColumn get importedRows => integer().withDefault(const Constant(0))();
  IntColumn get rejectedRows => integer().withDefault(const Constant(0))();
  TextColumn get importedAtUtc =>
      text().check(utcIsoTextCheck('imported_at_utc'))();
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
  TextColumn get createdAtUtc =>
      text().check(utcIsoTextCheck('created_at_utc'))();

  @override
  Set<Column<Object>> get primaryKey => {entityId};
}
