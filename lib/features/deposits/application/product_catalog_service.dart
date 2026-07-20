import '../domain/local_date.dart';
import '../domain/product_catalog_repository.dart';

final class ProductCatalogService {
  const ProductCatalogService(this.repository);

  final ProductCatalogRepository repository;

  Future<List<ProductRecord>> list({bool includeInactive = false}) =>
      repository.listProducts(includeInactive: includeInactive);

  Future<List<String>> activeBanks() async {
    final products = await list();
    final names = <String, String>{};
    for (final product in products) {
      names.putIfAbsent(product.bankName.toLowerCase(), () => product.bankName);
    }
    final result = names.values.toList(growable: false);
    result.sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
    return result;
  }

  Future<List<ProductRecord>> activeProductsForBank(String bankName) async {
    final normalized = bankName.trim().toLowerCase();
    return (await list())
        .where((product) => product.bankName.toLowerCase() == normalized)
        .toList(growable: false);
  }

  Future<ProductRecord> saveProduct(ProductDraft draft) =>
      repository.saveProduct(draft);

  Future<void> setProductActive(String productId, bool active) =>
      repository.setProductActive(productId, active);

  Future<List<ProductRateVersion>> listRates(String productId) =>
      repository.listRates(productId);

  Future<ProductRateVersion> saveRate(ProductRateDraft draft) =>
      repository.saveRate(draft);

  Future<ProductRateVersion?> matchRate(
    String productId,
    LocalDate startDate,
  ) => repository.matchRate(productId, startDate);

  Future<Map<String, ProductRateVersion?>> matchRates(
    Iterable<ProductRecord> products,
    LocalDate startDate,
  ) async {
    final entries = await Future.wait(
      products.map(
        (product) async =>
            MapEntry(product.id, await matchRate(product.id, startDate)),
      ),
    );
    return Map.unmodifiable(Map.fromEntries(entries));
  }
}
