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
    if (body.startsWith(r'\{{', index)) {
      final close = body.indexOf('}}', index + 3);
      if (close < 0) {
        throw const TemplateRenderException('模板格式错误：转义占位符缺少结束符号 }}');
      }
      output.write(body.substring(index + 1, close + 2));
      index = close + 2;
      continue;
    }
    if (body.startsWith(r'\\', index)) {
      output.write(r'\');
      index += 2;
      continue;
    }
    if (body.startsWith(r'\{', index)) {
      output.write('{');
      index += 2;
      continue;
    }
    if (body.startsWith(r'\}', index)) {
      output.write('}');
      index += 2;
      continue;
    }
    if (body.startsWith('{{', index)) {
      final close = body.indexOf('}}', index + 2);
      if (close < 0) {
        throw const TemplateRenderException('模板格式错误：变量缺少结束符号 }}');
      }
      final variable = body.substring(index + 2, close).trim();
      if (variable.contains('{') || variable.contains('}')) {
        throw const TemplateRenderException('模板格式错误：变量包含多余大括号');
      }
      if (!_supportedVariables.contains(variable)) {
        throw TemplateRenderException('未知模板变量 $variable');
      }
      final value = values.valueFor(variable);
      if (value == null || value.isEmpty) {
        throw TemplateRenderException('缺少模板变量值 $variable');
      }
      output.write(value);
      index = close + 2;
      continue;
    }
    if (body[index] == '{' || body[index] == '}') {
      throw TemplateRenderException('模板格式错误：位置 $index 存在未转义大括号');
    }
    output.write(body[index]);
    index++;
  }

  return output.toString();
}
