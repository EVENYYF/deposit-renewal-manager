import '../domain/message_template.dart';

const _supportedVariables = <String>{
  'customerName',
  'amount',
  'bank',
  'product',
  'interestRate',
  'depositDate',
  'expiryDate',
};

String renderMessage(MessageTemplate template, TemplateValues values) {
  final output = StringBuffer();
  final body = template.body;
  var index = 0;

  while (index < body.length) {
    if (body.startsWith(r'\\', index)) {
      output.write(r'\');
      index += 2;
      continue;
    }
    if (body.startsWith(r'\{{', index)) {
      output.write('{{');
      index += 3;
      continue;
    }
    if (!body.startsWith('{{', index)) {
      output.write(body[index]);
      index++;
      continue;
    }

    final close = body.indexOf('}}', index + 2);
    if (close < 0) {
      throw const TemplateRenderException('模板变量缺少结束符号 }}');
    }
    final variable = body.substring(index + 2, close).trim();
    if (!_supportedVariables.contains(variable)) {
      throw TemplateRenderException('未知模板变量 $variable');
    }
    final value = values.valueFor(variable);
    if (value == null || value.isEmpty) {
      throw TemplateRenderException('缺少模板变量值 $variable');
    }
    output.write(value);
    index = close + 2;
  }

  return output.toString();
}
