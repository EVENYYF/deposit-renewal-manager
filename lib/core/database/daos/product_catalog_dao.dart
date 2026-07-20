import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/deposits/domain/local_date.dart';
import '../../../features/deposits/domain/product_catalog_repository.dart';
import '../app_database.dart' as db;

typedef ProductCatalogUtcNow = DateTime Function();

final class ProductCatalogDao implements ProductCatalogRepository {
  ProductCatalogDao(this._database, {ProductCatalogUtcNow? nowUtc, Uuid? uuid})
    : _nowUtc = nowUtc ?? clock.now,
      _uuid = uuid ?? const Uuid();

  final db.AppDatabase _database;
  final ProductCatalogUtcNow _nowUtc;
  final Uuid _uuid;

  @override
  Future<List<ProductRecord>> listProducts({
    bool includeInactive = false,
  }) async {
    final query = _database.select(_database.products);
    if (!includeInactive) {
      query.where((row) => row.isActive.equals(true));
    }
    query.orderBy([
      (row) => OrderingTerm.asc(row.bankName),
      (row) => OrderingTerm.asc(row.productName),
      (row) => OrderingTerm.asc(row.id),
    ]);
    return (await query.get()).map(_product).toList(growable: false);
  }

  @override
  Future<ProductRecord> saveProduct(ProductDraft draft) async {
    final bankName = draft.bankName.trim();
    final productName = draft.productName.trim();
    if (bankName.isEmpty || productName.isEmpty) {
      throw ArgumentError('Bank and product names must not be empty');
    }
    final id = draft.id.trim().isEmpty ? _uuid.v4() : draft.id;
    final timestamp = _timestamp;
    final existing = await (_database.select(
      _database.products,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    await _database
        .into(_database.products)
        .insertOnConflictUpdate(
          db.ProductsCompanion.insert(
            id: id,
            bankName: bankName,
            productName: productName,
            isActive: Value(draft.isActive),
            createdAtUtc: existing?.createdAtUtc ?? timestamp,
            updatedAtUtc: timestamp,
          ),
        );
    return _product(
      await (_database.select(
        _database.products,
      )..where((row) => row.id.equals(id))).getSingle(),
    );
  }

  @override
  Future<void> setProductActive(String productId, bool active) async {
    final changed =
        await (_database.update(
          _database.products,
        )..where((row) => row.id.equals(productId))).write(
          db.ProductsCompanion(
            isActive: Value(active),
            updatedAtUtc: Value(_timestamp),
          ),
        );
    if (changed == 0) throw StateError('Product not found');
  }

  @override
  Future<List<ProductRateVersion>> listRates(String productId) async {
    final rows =
        await (_database.select(_database.productRateVersions)
              ..where((row) => row.productId.equals(productId))
              ..orderBy([
                (row) => OrderingTerm.desc(row.effectiveDate),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    return rows.map(_rate).toList(growable: false);
  }

  @override
  Future<ProductRateVersion> saveRate(ProductRateDraft draft) async {
    if (draft.interestRateScaled < 0) {
      throw ArgumentError.value(
        draft.interestRateScaled,
        'interestRateScaled',
        'Must not be negative',
      );
    }
    if (draft.ratePrecision < 0 || draft.ratePrecision > 9) {
      throw ArgumentError.value(
        draft.ratePrecision,
        'ratePrecision',
        'Must be between 0 and 9',
      );
    }
    final date = draft.effectiveDate.toString();
    final existing =
        await (_database.select(_database.productRateVersions)..where(
              (row) =>
                  row.productId.equals(draft.productId) &
                  row.effectiveDate.equals(date),
            ))
            .getSingleOrNull();
    final id =
        existing?.id ?? (draft.id.trim().isEmpty ? _uuid.v4() : draft.id);
    final timestamp = _timestamp;
    await _database
        .into(_database.productRateVersions)
        .insertOnConflictUpdate(
          db.ProductRateVersionsCompanion.insert(
            id: id,
            productId: draft.productId,
            interestRateScaled: draft.interestRateScaled,
            ratePrecision: draft.ratePrecision,
            effectiveDate: date,
            createdAtUtc: existing?.createdAtUtc ?? timestamp,
            updatedAtUtc: timestamp,
          ),
        );
    return _rate(
      await (_database.select(
        _database.productRateVersions,
      )..where((row) => row.id.equals(id))).getSingle(),
    );
  }

  @override
  Future<ProductRateVersion?> matchRate(
    String productId,
    LocalDate startDate,
  ) async {
    final row =
        await (_database.select(_database.productRateVersions)
              ..where(
                (row) =>
                    row.productId.equals(productId) &
                    row.effectiveDate.isSmallerOrEqualValue(
                      startDate.toString(),
                    ),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.effectiveDate),
                (row) => OrderingTerm.asc(row.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _rate(row);
  }

  int get _timestamp => _nowUtc().toUtc().microsecondsSinceEpoch;

  ProductRecord _product(db.Product row) => ProductRecord(
    id: row.id,
    bankName: row.bankName,
    productName: row.productName,
    isActive: row.isActive,
  );

  ProductRateVersion _rate(db.ProductRateVersion row) => ProductRateVersion(
    id: row.id,
    productId: row.productId,
    interestRateScaled: row.interestRateScaled,
    ratePrecision: row.ratePrecision,
    effectiveDate: _date(row.effectiveDate),
  );

  LocalDate _date(String value) {
    final parts = value.split('-');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
