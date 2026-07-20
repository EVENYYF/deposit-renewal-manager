import 'package:deposit_renewal_manager/features/deposits/application/product_catalog_service.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/product_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deduplicates and sorts active banks case-insensitively', () async {
    final service = ProductCatalogService(
      _FakeCatalog([
        const ProductRecord(
          id: '1',
          bankName: 'Z Bank',
          productName: 'One',
          isActive: true,
        ),
        const ProductRecord(
          id: '2',
          bankName: 'a bank',
          productName: 'Two',
          isActive: true,
        ),
        const ProductRecord(
          id: '3',
          bankName: 'A Bank',
          productName: 'Three',
          isActive: true,
        ),
        const ProductRecord(
          id: '4',
          bankName: 'Hidden',
          productName: 'Four',
          isActive: false,
        ),
      ]),
    );

    expect(await service.activeBanks(), ['a bank', 'Z Bank']);
  });

  test('filters active products by normalized bank name', () async {
    final service = ProductCatalogService(
      _FakeCatalog([
        const ProductRecord(
          id: '1',
          bankName: 'Bank',
          productName: 'One',
          isActive: true,
        ),
        const ProductRecord(
          id: '2',
          bankName: 'Other',
          productName: 'Two',
          isActive: true,
        ),
        const ProductRecord(
          id: '3',
          bankName: 'BANK',
          productName: 'Disabled',
          isActive: false,
        ),
      ]),
    );

    final products = await service.activeProductsForBank(' bank ');

    expect(products.map((product) => product.productName), ['One']);
  });

  test('matches a dated rate for every product id', () async {
    final date = LocalDate(2026, 7, 1);
    final products = const [
      ProductRecord(
        id: 'p1',
        bankName: '甲银行',
        productName: '稳健存款',
        isActive: true,
      ),
      ProductRecord(
        id: 'p2',
        bankName: '甲银行',
        productName: '通知存款',
        isActive: true,
      ),
    ];
    final service = ProductCatalogService(
      _FakeCatalog(
        products,
        rates: {
          'p1': ProductRateVersion(
            id: 'r1',
            productId: 'p1',
            interestRateScaled: 230,
            ratePrecision: 2,
            effectiveDate: date,
          ),
        },
      ),
    );

    final rates = await service.matchRates(products, date);

    expect(rates.keys.toSet(), {'p1', 'p2'});
    expect(rates['p1']?.interestRateScaled, 230);
    expect(rates['p2'], isNull);
  });
}

final class _FakeCatalog implements ProductCatalogRepository {
  _FakeCatalog(this.products, {this.rates = const {}});

  final List<ProductRecord> products;
  final Map<String, ProductRateVersion> rates;

  @override
  Future<List<ProductRecord>> listProducts({
    bool includeInactive = false,
  }) async => products
      .where((product) => includeInactive || product.isActive)
      .toList(growable: false);

  @override
  Future<List<ProductRateVersion>> listRates(String productId) async =>
      const [];

  @override
  Future<ProductRateVersion?> matchRate(
    String productId,
    LocalDate startDate,
  ) async => rates[productId];

  @override
  Future<ProductRecord> saveProduct(ProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<ProductRateVersion> saveRate(ProductRateDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> setProductActive(String productId, bool active) =>
      throw UnimplementedError();
}
