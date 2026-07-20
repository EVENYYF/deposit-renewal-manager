import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/product_catalog_dao.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/product_catalog_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProductCatalogDao catalog;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    catalog = ProductCatalogDao(
      database,
      nowUtc: () => DateTime.utc(2026, 7, 20, 8),
    );
  });

  tearDown(() => database.close());

  test('allows the same product name at different banks', () async {
    await catalog.saveProduct(
      const ProductDraft(id: 'p1', bankName: '甲银行', productName: '稳健存款'),
    );
    await catalog.saveProduct(
      const ProductDraft(id: 'p2', bankName: '乙银行', productName: '稳健存款'),
    );

    expect(await catalog.listProducts(), hasLength(2));
  });

  test('rejects duplicate normalized bank and product names', () async {
    await catalog.saveProduct(
      const ProductDraft(id: 'p1', bankName: ' 甲银行 ', productName: '稳健存款'),
    );

    await expectLater(
      catalog.saveProduct(
        const ProductDraft(id: 'p2', bankName: '甲银行', productName: ' 稳健存款 '),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('stores multiple rate dates and updates the same date', () async {
    await _saveProduct(catalog);
    await catalog.saveRate(
      ProductRateDraft(
        id: 'r1',
        productId: 'p1',
        interestRateScaled: 210,
        ratePrecision: 4,
        effectiveDate: LocalDate(2026, 1, 1),
      ),
    );
    await catalog.saveRate(
      ProductRateDraft(
        id: 'r2',
        productId: 'p1',
        interestRateScaled: 220,
        ratePrecision: 4,
        effectiveDate: LocalDate(2026, 6, 1),
      ),
    );
    final updated = await catalog.saveRate(
      ProductRateDraft(
        id: 'replacement-id',
        productId: 'p1',
        interestRateScaled: 230,
        ratePrecision: 4,
        effectiveDate: LocalDate(2026, 6, 1),
      ),
    );

    final rates = await catalog.listRates('p1');
    expect(rates, hasLength(2));
    expect(rates.first.effectiveDate, LocalDate(2026, 6, 1));
    expect(rates.first.interestRateScaled, 230);
    expect(updated.id, 'r2');
  });

  test('matches the latest rate not after the deposit date', () async {
    await _saveProduct(catalog);
    for (final entry in [
      (LocalDate(2026, 1, 1), 210),
      (LocalDate(2026, 6, 1), 230),
    ]) {
      await catalog.saveRate(
        ProductRateDraft(
          id: 'r${entry.$2}',
          productId: 'p1',
          interestRateScaled: entry.$2,
          ratePrecision: 4,
          effectiveDate: entry.$1,
        ),
      );
    }

    expect(await catalog.matchRate('p1', LocalDate(2025, 12, 31)), isNull);
    expect(
      (await catalog.matchRate(
        'p1',
        LocalDate(2026, 7, 1),
      ))!.interestRateScaled,
      230,
    );
  });

  test('inactive products are excluded unless explicitly requested', () async {
    await _saveProduct(catalog);
    await catalog.setProductActive('p1', false);

    expect(await catalog.listProducts(), isEmpty);
    expect(await catalog.listProducts(includeInactive: true), hasLength(1));
  });
}

Future<void> _saveProduct(ProductCatalogDao catalog) => catalog.saveProduct(
  const ProductDraft(id: 'p1', bankName: '甲银行', productName: '稳健存款'),
);
