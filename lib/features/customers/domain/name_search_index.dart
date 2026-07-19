import 'package:lpinyin/lpinyin.dart';

import '../../deposits/domain/deposit.dart';
import '../../deposits/domain/local_date.dart';

final RegExp _ignoredSearchSeparators = RegExp(
  r'[\s+\-_./\\()（）·•]+',
  unicode: true,
);

String normalizeSearchText(String value) =>
    value.toLowerCase().replaceAll(_ignoredSearchSeparators, '');

String normalizePhone(String value) => normalizeSearchText(value);

final class CustomerSearchIndex {
  const CustomerSearchIndex({
    required this.normalizedName,
    required this.fullPinyin,
    required this.initials,
  });

  final String normalizedName;
  final String fullPinyin;
  final String initials;
}

CustomerSearchIndex buildNameIndex(String name) => CustomerSearchIndex(
  normalizedName: normalizeSearchText(name),
  fullPinyin: normalizeSearchText(PinyinHelper.getPinyinE(name, separator: '')),
  initials: normalizeSearchText(PinyinHelper.getShortPinyin(name)),
);

final class CustomerQuery {
  const CustomerQuery({
    this.text = '',
    this.bank,
    this.expiryFrom,
    this.expiryTo,
    this.lifecycle,
    this.overdueOnly = false,
    this.today,
  });

  final String text;
  final String? bank;
  final LocalDate? expiryFrom;
  final LocalDate? expiryTo;
  final DepositLifecycle? lifecycle;
  final bool overdueOnly;
  final LocalDate? today;

  bool get hasDepositFilters =>
      bank != null ||
      expiryFrom != null ||
      expiryTo != null ||
      lifecycle != null ||
      overdueOnly;
}

final class CustomerSearchDeposit {
  const CustomerSearchDeposit({
    required this.id,
    required this.bankName,
    this.productName = '',
    required this.finalExpiryDate,
    required this.lifecycle,
  });

  final String id;
  final String bankName;
  final String productName;
  final LocalDate finalExpiryDate;
  final DepositLifecycle lifecycle;
}
