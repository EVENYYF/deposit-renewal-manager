import '../domain/customer_repository.dart';
import '../domain/name_search_index.dart';

final class CustomerSearchService {
  const CustomerSearchService(this._repository);

  final CustomerRepository _repository;

  Future<List<CustomerSearchResult>> search(CustomerQuery query) {
    if (query.overdueOnly && query.today == null) {
      throw ArgumentError('today is required for overdue filtering');
    }
    if (query.expiryFrom != null &&
        query.expiryTo != null &&
        query.expiryFrom!.isAfter(query.expiryTo!)) {
      throw ArgumentError('expiryFrom must not be after expiryTo');
    }
    return _repository.search(query);
  }
}
