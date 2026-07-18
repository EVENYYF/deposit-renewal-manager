final class MessageTemplate {
  const MessageTemplate({
    required this.name,
    required this.body,
    this.isEnabled = true,
    this.isDefault = false,
  });

  final String name;
  final String body;
  final bool isEnabled;
  final bool isDefault;
}

final class TemplateValues {
  const TemplateValues({
    this.customerName,
    this.amount,
    this.bank,
    this.product,
    this.interestRate,
    this.depositDate,
    this.expiryDate,
  });

  final String? customerName;
  final String? amount;
  final String? bank;
  final String? product;
  final String? interestRate;
  final String? depositDate;
  final String? expiryDate;

  String? valueFor(String variable) => switch (variable) {
    'customerName' => customerName,
    'amount' => amount,
    'bank' => bank,
    'product' => product,
    'interestRate' => interestRate,
    'depositDate' => depositDate,
    'expiryDate' => expiryDate,
    _ => null,
  };
}

final class TemplateRenderException implements Exception {
  const TemplateRenderException(this.message);

  final String message;

  @override
  String toString() => 'TemplateRenderException: $message';
}
