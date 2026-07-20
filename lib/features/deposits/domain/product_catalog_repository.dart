import 'local_date.dart';

final class ProductRecord {
  const ProductRecord({
    required this.id,
    required this.bankName,
    required this.productName,
    required this.isActive,
  });

  final String id;
  final String bankName;
  final String productName;
  final bool isActive;
}

final class ProductRateVersion {
  const ProductRateVersion({
    required this.id,
    required this.productId,
    required this.interestRateScaled,
    required this.ratePrecision,
    required this.effectiveDate,
  });

  final String id;
  final String productId;
  final int interestRateScaled;
  final int ratePrecision;
  final LocalDate effectiveDate;
}

final class ProductDraft {
  const ProductDraft({
    required this.id,
    required this.bankName,
    required this.productName,
    this.isActive = true,
  });

  final String id;
  final String bankName;
  final String productName;
  final bool isActive;
}

final class ProductRateDraft {
  const ProductRateDraft({
    required this.id,
    required this.productId,
    required this.interestRateScaled,
    required this.ratePrecision,
    required this.effectiveDate,
  });

  final String id;
  final String productId;
  final int interestRateScaled;
  final int ratePrecision;
  final LocalDate effectiveDate;
}

abstract interface class ProductCatalogRepository {
  Future<List<ProductRecord>> listProducts({bool includeInactive = false});

  Future<ProductRecord> saveProduct(ProductDraft draft);

  Future<void> setProductActive(String productId, bool active);

  Future<List<ProductRateVersion>> listRates(String productId);

  Future<ProductRateVersion> saveRate(ProductRateDraft draft);

  Future<ProductRateVersion?> matchRate(String productId, LocalDate startDate);
}
