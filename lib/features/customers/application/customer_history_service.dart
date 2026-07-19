import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../deposits/domain/deposit.dart';
import '../../deposits/domain/deposit_repository.dart';
import '../../deposits/domain/local_date.dart';
import '../domain/customer_repository.dart';

final class CustomerHistoryEntry {
  const CustomerHistoryEntry({
    required this.operation,
    required this.occurredAt,
    this.entityType,
    this.entityId,
    this.beforeJson,
    this.afterJson,
  });
  final String operation;
  final DateTime occurredAt;
  final String? entityType;
  final String? entityId;
  final String? beforeJson;
  final String? afterJson;

  List<CustomerHistoryChange> get changes =>
      CustomerHistoryChange.fromJson(beforeJson, afterJson);
}

final class CustomerHistoryChange {
  const CustomerHistoryChange({
    required this.field,
    required this.before,
    required this.after,
  });
  final String field;
  final Object? before;
  final Object? after;

  static List<CustomerHistoryChange> fromJson(
    String? beforeJson,
    String? afterJson,
  ) {
    Map<String, dynamic> decode(String? value) {
      if (value == null || value.trim().isEmpty) return const {};
      try {
        final decoded = jsonDecode(value);
        return decoded is Map
            ? decoded.map((key, value) => MapEntry(key.toString(), value))
            : const {};
      } on FormatException {
        return const {};
      }
    }

    final before = decode(beforeJson);
    final after = decode(afterJson);
    final keys = {...before.keys, ...after.keys}.toList()..sort();
    return [
      for (final key in keys)
        if (!_same(before[key], after[key]))
          CustomerHistoryChange(
            field: key,
            before: before[key],
            after: after[key],
          ),
    ];
  }

  static bool _same(Object? left, Object? right) =>
      jsonEncode(left) == jsonEncode(right);
}

/// A display version of a deposit. It deliberately lives outside the database
/// model so customer pages can render richer history from an injected use case.
final class CustomerDepositVersion {
  const CustomerDepositVersion({
    required this.id,
    required this.bankName,
    required this.finalExpiryDate,
    required this.lifecycle,
    this.productName = '',
    this.amountCents,
    this.interestRateScaled,
    this.ratePrecision = 2,
    this.startDate,
    this.renewalSourceId,
    this.editableDraft,
  });
  final String id;
  final String bankName;
  final String productName;
  final int? amountCents;
  final int? interestRateScaled;
  final int ratePrecision;
  final LocalDate finalExpiryDate;
  final LocalDate? startDate;
  final DepositLifecycle lifecycle;
  final String? renewalSourceId;
  final DepositDraft? editableDraft;
}

final class CustomerDepositChain {
  const CustomerDepositChain({required this.versions});
  final List<CustomerDepositVersion> versions;
  CustomerDepositVersion get root => versions.first;
}

abstract interface class CustomerDepositHistoryUseCases {
  Future<List<CustomerDepositChain>> load(CustomerSearchResult result);
}

final class DefaultCustomerDepositHistoryUseCases
    implements CustomerDepositHistoryUseCases {
  const DefaultCustomerDepositHistoryUseCases();
  @override
  Future<List<CustomerDepositChain>> load(CustomerSearchResult result) async =>
      [
        for (final deposit in result.deposits)
          CustomerDepositChain(
            versions: [
              CustomerDepositVersion(
                id: deposit.id,
                bankName: deposit.bankName,
                productName: deposit.productName,
                finalExpiryDate: deposit.finalExpiryDate,
                lifecycle: deposit.lifecycle,
              ),
            ],
          ),
      ];
}

final customerDepositHistoryUseCasesProvider =
    Provider<CustomerDepositHistoryUseCases>(
      (ref) => const DefaultCustomerDepositHistoryUseCases(),
    );

abstract interface class CustomerHistoryUseCases {
  Future<List<CustomerHistoryEntry>> load(String customerId);
}

final class EmptyCustomerHistoryUseCases implements CustomerHistoryUseCases {
  const EmptyCustomerHistoryUseCases();
  @override
  Future<List<CustomerHistoryEntry>> load(String customerId) async => const [];
}

final customerHistoryUseCasesProvider = Provider<CustomerHistoryUseCases>(
  (ref) => const EmptyCustomerHistoryUseCases(),
);
