import 'package:flutter/material.dart';

import '../domain/deposit.dart';
import '../domain/local_date.dart';

final class DepositDetailsViewData {
  const DepositDetailsViewData({
    required this.depositId,
    required this.customerName,
    this.customerPhone,
    required this.bankName,
    required this.productName,
    required this.amountCents,
    required this.interestRateScaled,
    required this.ratePrecision,
    required this.startDate,
    required this.expiryDate,
    required this.lifecycle,
  });
  final String depositId;
  final String customerName;
  final String? customerPhone;
  final String bankName;
  final String productName;
  final int? amountCents;
  final int? interestRateScaled;
  final int ratePrecision;
  final LocalDate? startDate;
  final LocalDate expiryDate;
  final DepositLifecycle lifecycle;
}

enum DepositDetailsAction { renew, stop, edit }

Future<DepositDetailsAction?> showDepositDetailsDialog(
  BuildContext context, {
  required DepositDetailsViewData data,
  required bool allowActions,
}) => showDialog<DepositDetailsAction>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('${data.customerName}的存款'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('银行', data.bankName),
        _row('产品', data.productName),
        if (data.amountCents != null)
          _row('金额', '${(data.amountCents! / 100).toStringAsFixed(2)} 元'),
        if (data.interestRateScaled != null)
          _row('年利率', _rate(data.interestRateScaled!, data.ratePrecision)),
        if (data.startDate != null) _row('存入日期', '${data.startDate}'),
        _row('到期日期', '${data.expiryDate}'),
        _row('状态', _lifecycle(data.lifecycle)),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
      if (allowActions && data.lifecycle == DepositLifecycle.active) ...[
        TextButton(
          onPressed: () => Navigator.pop(context, DepositDetailsAction.stop),
          child: const Text('停止续期'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DepositDetailsAction.edit),
          child: const Text('编辑'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, DepositDetailsAction.renew),
          child: const Text('续期'),
        ),
      ],
    ],
  ),
);

Widget _row(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text('$label：$value'),
);

String _rate(int scaled, int precision) {
  var divisor = 1;
  for (var i = 0; i < precision; i++) {
    divisor *= 10;
  }
  return '${(scaled / divisor).toStringAsFixed(precision)}%';
}

String _lifecycle(DepositLifecycle value) => switch (value) {
  DepositLifecycle.active => '生效中',
  DepositLifecycle.renewed => '已续期',
  DepositLifecycle.stopped => '已停止',
};
