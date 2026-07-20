import 'dart:convert';

import '../application/customer_history_service.dart';

final class FormattedHistoryChange {
  const FormattedHistoryChange({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;
}

abstract final class CustomerHistoryFormatter {
  static List<FormattedHistoryChange> formatEntry(CustomerHistoryEntry entry) {
    final before = _decode(entry.beforeJson);
    final after = _decode(entry.afterJson);
    final keys = {...before.keys, ...after.keys}.toList()..sort();
    return [
      for (final key in keys)
        if (jsonEncode(before[key]) != jsonEncode(after[key]))
          FormattedHistoryChange(
            label: _label(key),
            before: _value(key, before[key], before, after),
            after: _value(key, after[key], after, before),
          ),
    ];
  }

  static Map<String, dynamic> _decode(String? value) {
    if (value == null || value.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(_canonical(key.toString()), value),
      );
    } on FormatException {
      return const {};
    }
  }

  static String _canonical(String value) => value
      .replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)!.toLowerCase()}',
      )
      .replaceAll('-', '_');

  static String _label(String key) => switch (_canonical(key)) {
    'name' => '姓名',
    'phone' => '手机号',
    'bank_name' => '银行',
    'product_name' => '产品',
    'amount_cents' => '金额',
    'interest_rate_scaled' => '年利率',
    'rate_precision' => '利率精度',
    'term_value' => '期限',
    'term_unit' => '期限单位',
    'start_date' => '存入日期',
    'calculated_expiry_date' => '计算到期日',
    'final_expiry_date' => '到期日',
    'lifecycle' => '状态',
    _ => '其他字段',
  };

  static String _value(
    String rawKey,
    Object? value,
    Map<String, dynamic> side,
    Map<String, dynamic> otherSide,
  ) {
    final key = _canonical(rawKey);
    if (value == null || value == '') return '未填写';
    if (key == 'amount_cents' && value is num) {
      return '¥${(value / 100).toStringAsFixed(2)}';
    }
    if (key == 'interest_rate_scaled' && value is num) {
      final precision = (side['rate_precision'] ?? otherSide['rate_precision']);
      final digits = precision is num ? precision.toInt() : 2;
      var scale = 1;
      for (var index = 0; index < digits; index++) {
        scale *= 10;
      }
      return '${(value / scale).toStringAsFixed(digits)}%';
    }
    if (key == 'term_unit') {
      return switch (value.toString()) {
        'day' => '天',
        'month' => '个月',
        'year' => '年',
        _ => value.toString(),
      };
    }
    if (key == 'lifecycle') {
      return switch (value.toString()) {
        'active' => '生效中',
        'renewed' => '已续期',
        'stopped' => '已停止',
        _ => value.toString(),
      };
    }
    if (value is bool) return value ? '是' : '否';
    return value.toString();
  }
}
