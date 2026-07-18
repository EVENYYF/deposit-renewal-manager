import 'package:deposit_renewal_manager/features/templates/application/render_message.dart';
import 'package:deposit_renewal_manager/features/templates/domain/message_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renders all supported contact message variables', () {
    const template = MessageTemplate(
      name: '到期提醒',
      body:
          '{{customerName}}您好，您在{{bank}}的{{product}}{{amount}}，'
          '利率{{interestRate}}，存入日{{depositDate}}，到期日{{expiryDate}}。',
    );
    const values = TemplateValues(
      customerName: '张三',
      amount: '10万元',
      bank: '工商银行',
      product: '定期',
      interestRate: '1.5%',
      depositDate: '2026-07-18',
      expiryDate: '2027-07-18',
    );

    expect(
      renderMessage(template, values),
      '张三您好，您在工商银行的定期10万元，利率1.5%，'
      '存入日2026-07-18，到期日2027-07-18。',
    );
  });

  test('reports unknown variables with a readable error', () {
    const template = MessageTemplate(name: '错误模板', body: '您好{{nickname}}');

    expect(
      () => renderMessage(template, const TemplateValues()),
      throwsA(
        isA<TemplateRenderException>().having(
          (error) => error.message,
          'message',
          contains('未知模板变量 nickname'),
        ),
      ),
    );
  });

  test('reports missing required values with a readable error', () {
    const template = MessageTemplate(
      name: '到期提醒',
      body: '{{customerName}}的存款将于{{expiryDate}}到期',
    );

    expect(
      () => renderMessage(template, const TemplateValues(customerName: '张三')),
      throwsA(
        isA<TemplateRenderException>().having(
          (error) => error.message,
          'message',
          contains('缺少模板变量值 expiryDate'),
        ),
      ),
    );
  });

  test('supports escaped placeholders and backslashes', () {
    const template = MessageTemplate(
      name: '转义',
      body: r'格式：\{{customerName}}，路径 C:\\deposit，客户 {{customerName}}',
    );

    expect(
      renderMessage(template, const TemplateValues(customerName: '张三')),
      r'格式：{{customerName}}，路径 C:\deposit，客户 张三',
    );
  });

  test('rendering does not modify the saved template', () {
    const template = MessageTemplate(
      name: '可临时编辑',
      body: '{{customerName}}您好',
      isEnabled: true,
      isDefault: true,
    );

    final rendered = renderMessage(
      template,
      const TemplateValues(customerName: '李四'),
    );
    final temporaryEdit = '$rendered，稍后联系';

    expect(temporaryEdit, '李四您好，稍后联系');
    expect(template.body, '{{customerName}}您好');
    expect(template.isDefault, isTrue);
  });
}
