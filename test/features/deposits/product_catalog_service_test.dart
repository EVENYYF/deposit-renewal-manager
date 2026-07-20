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
}

final class _FakeCatalog implements ProductCatalogRepository {
  _FakeCatalog(this.products);

  final List<ProductRecord> products;

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
  ) async => null;

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
