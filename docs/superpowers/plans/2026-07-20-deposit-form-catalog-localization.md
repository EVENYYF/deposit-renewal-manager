# Deposit Form Catalog Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将存款表单的银行和产品改为可手工输入的下拉选择，并按银行与存入日期展示产品适用利率，同时把日期选择器本地化为中文。

**Architecture:** 新增一个独立的可编辑目录下拉组件，负责文本输入、菜单开关和自定义候选项展示；存款表单继续持有业务控制器和目录状态。`ProductCatalogService` 新增批量按日期匹配接口，表单使用 generation 防止旧请求覆盖新银行或新日期结果。应用入口统一注册中文 Material 本地化。

**Tech Stack:** Flutter 3.38、Material 3、Riverpod 3、`flutter_localizations` SDK、Flutter Widget Test。

## Global Constraints

- 银行和产品必须同时支持下拉选择与自由文本输入。
- 产品候选只显示当前银行的活跃目录产品；目录产品按当前存入日期显示适用利率。
- 目录产品候选使用主题强调色，普通历史候选保持默认色。
- 用户手工修改利率后，日期变化不得覆盖该值；重新选择目录产品可重新匹配。
- 日期文本继续保存为 `YYYY-MM-DD`，并保留键盘录入。
- 目录不可用时不得阻止存款录入。
- 不修改数据库 schema、备份格式和产品管理数据结构。

---

### Task 1: 中文 Material 日期本地化

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/app/app.dart:1-181`
- Modify: `lib/features/deposits/presentation/deposit_form_page.dart:394-430`
- Test: `test/features/deposits/deposit_form_page_test.dart`

**Interfaces:**
- Consumes: Flutter SDK 的 `GlobalMaterialLocalizations`、`GlobalWidgetsLocalizations`、`GlobalCupertinoLocalizations`。
- Produces: 应用级 `Locale('zh', 'CN')` 支持；`showDatePicker(locale: const Locale('zh', 'CN'))`。

- [ ] **Step 1: 写中文日期选择器失败测试**

在 `deposit_form_page_test.dart` 增加测试，测试宿主也注册中文 delegate，点击存入日期后断言中文按钮：

```dart
testWidgets('日期选择器使用中文', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: [Locale('zh', 'CN')],
        home: Scaffold(body: DepositFormPage()),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('start-date')));
  await tester.pumpAndSettle();
  expect(find.text('取消'), findsOneWidget);
  expect(find.text('确定'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试并确认缺少本地化依赖或中文界面断言失败**

Run: `flutter test --no-pub test/features/deposits/deposit_form_page_test.dart --plain-name "日期选择器使用中文"`

Expected: FAIL，原因是 `flutter_localizations` 尚未声明或日期选择器未使用中文 locale。

- [ ] **Step 3: 注册 SDK 本地化依赖和应用配置**

在 `pubspec.yaml` 的 dependencies 增加：

```yaml
flutter_localizations:
  sdk: flutter
```

在 `app.dart` 导入并配置：

```dart
import 'package:flutter_localizations/flutter_localizations.dart';

MaterialApp.router(
  locale: const Locale('zh', 'CN'),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('zh', 'CN')],
  // 保留现有 theme/router 参数
)
```

在 `_dateField` 的 `showDatePicker` 增加：

```dart
locale: const Locale('zh', 'CN'),
```

- [ ] **Step 4: 获取依赖并验证测试**

Run: `flutter pub get`

Expected: exit 0，`pubspec.lock` 只出现 SDK 本地化相关解析变更。

Run: `flutter test --no-pub test/features/deposits/deposit_form_page_test.dart --plain-name "日期选择器使用中文"`

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add pubspec.yaml pubspec.lock lib/app/app.dart lib/features/deposits/presentation/deposit_form_page.dart test/features/deposits/deposit_form_page_test.dart
git commit -m "feat: localize deposit dates in Chinese"
```

---

### Task 2: 可编辑目录下拉组件

**Files:**
- Create: `lib/features/deposits/presentation/editable_catalog_field.dart`
- Create: `test/features/deposits/editable_catalog_field_test.dart`

**Interfaces:**
- Produces: `EditableCatalogOption(String value, {String? subtitle, bool emphasized = false})`。
- Produces: `EditableCatalogField(controller, label, options, onChanged, onSelected, key, keyboardType, validator)`。
- Consumes: Material `MenuAnchor`、`MenuItemButton` 和外部 `TextEditingController`。

- [ ] **Step 1: 写组件失败测试**

```dart
testWidgets('可编辑下拉支持手工输入和带副标题选项', (tester) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: EditableCatalogField(
      controller: controller,
      label: '产品名称',
      options: const [
        EditableCatalogOption(
          '稳健存款',
          subtitle: '适用年利率 2.30%',
          emphasized: true,
        ),
      ],
      onChanged: (_) {},
      onSelected: (_) {},
    )),
  ));
  await tester.enterText(find.byType(TextFormField), '自定义产品');
  expect(controller.text, '自定义产品');
  await tester.tap(find.byTooltip('展开产品名称选项'));
  await tester.pumpAndSettle();
  expect(find.text('适用年利率 2.30%'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试并确认组件不存在**

Run: `flutter test --no-pub test/features/deposits/editable_catalog_field_test.dart`

Expected: FAIL，`editable_catalog_field.dart` 或类型未定义。

- [ ] **Step 3: 实现最小组件**

实现不可变选项模型和 StatefulWidget。组件内部持有 `MenuController`、`FocusNode`，文本变化时过滤候选；菜单项用两行 `Column` 显示 value/subtitle，`emphasized` 时使用 `colorScheme.primary`：

```dart
final class EditableCatalogOption {
  const EditableCatalogOption(
    this.value, {
    this.subtitle,
    this.emphasized = false,
  });
  final String value;
  final String? subtitle;
  final bool emphasized;
}

class EditableCatalogField extends StatefulWidget {
  const EditableCatalogField({
    required this.controller,
    required this.label,
    required this.options,
    required this.onChanged,
    required this.onSelected,
    this.keyboardType,
    this.validator,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final List<EditableCatalogOption> options;
  final ValueChanged<String> onChanged;
  final ValueChanged<EditableCatalogOption> onSelected;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
}
```

选择菜单项时设置 controller 文本、关闭菜单并调用 `onSelected(option)`；手工输入只调用 `onChanged(value)`，不强制选择。

- [ ] **Step 4: 运行组件测试**

Run: `flutter test --no-pub test/features/deposits/editable_catalog_field_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/deposits/presentation/editable_catalog_field.dart test/features/deposits/editable_catalog_field_test.dart
git commit -m "feat: add editable catalog dropdown field"
```

---

### Task 3: 银行产品与日期利率联动

**Files:**
- Modify: `lib/features/deposits/application/product_catalog_service.dart`
- Modify: `lib/features/deposits/presentation/deposit_form_page.dart`
- Modify: `test/features/deposits/deposit_form_page_test.dart`
- Test: `test/features/deposits/product_catalog_service_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `EditableCatalogField` 和 `EditableCatalogOption`。
- Produces: `ProductCatalogService.matchRates(Iterable<ProductRecord>, LocalDate) -> Future<Map<String, ProductRateVersion?>>`。
- Produces: 表单状态 `_catalogRatesByProductId`，键为产品 ID。

- [ ] **Step 1: 写批量利率匹配失败测试**

```dart
test('matchRates returns a result for every product id', () async {
  final service = ProductCatalogService(_Catalog());
  final products = await service.activeProductsForBank('甲银行');
  final rates = await service.matchRates(products, LocalDate(2026, 7, 1));
  expect(rates.keys, products.map((item) => item.id).toSet());
  expect(rates['p1']?.interestRateScaled, 230);
});
```

- [ ] **Step 2: 运行测试并确认方法不存在**

Run: `flutter test --no-pub test/features/deposits/product_catalog_service_test.dart`

Expected: FAIL，`matchRates` 未定义。

- [ ] **Step 3: 实现批量匹配接口**

```dart
Future<Map<String, ProductRateVersion?>> matchRates(
  Iterable<ProductRecord> products,
  LocalDate startDate,
) async {
  final entries = await Future.wait(
    products.map((product) async => MapEntry(
      product.id,
      await matchRate(product.id, startDate),
    )),
  );
  return Map.unmodifiable(Map.fromEntries(entries));
}
```

- [ ] **Step 4: 写表单联动失败测试**

替换旧 ActionChip 断言，测试流程为：展开银行下拉并选择“甲银行”；展开产品下拉；断言“稳健存款”“适用年利率 2.30%”存在，且产品标题颜色等于主题 `primary`；选择产品后利率输入为 `2.30`。再把存入日期改为 `2025-07-01`，断言候选副标题更新为对应版本。

核心断言：

```dart
expect(find.byTooltip('展开银行选项'), findsOneWidget);
expect(find.text('适用年利率 2.30%'), findsOneWidget);
final optionFinder = find.byKey(const Key('catalog-product-p1'));
final option = tester.widget<Text>(optionFinder);
expect(
  option.style?.color,
  Theme.of(tester.element(optionFinder)).colorScheme.primary,
);
```

- [ ] **Step 5: 将银行和产品字段接入可编辑下拉**

在表单状态新增：

```dart
Map<String, ProductRateVersion?> _catalogRatesByProductId = const {};
```

银行选项合并目录银行和历史候选，产品选项分两组：目录产品先显示并设置 `emphasized: true`，历史候选去除与目录同名项后追加。目录产品副标题格式：

```dart
String _catalogRateLabel(ProductRateVersion? rate) => rate == null
    ? '该日期无利率版本'
    : '适用年利率 ${_formatCatalogRate(rate)}';
```

`_loadProductsForBank` 成功后调用私有 `_loadCatalogRates(products)`；`_onStartDateChanged` 在日期解析成功后重新调用 `_loadCatalogRates(_catalogProducts)`。请求开始前记录 generation 和 startDate，响应写入前同时验证二者仍然匹配。

- [ ] **Step 6: 保留手工利率覆盖规则**

产品菜单的 `onSelected` 必须调用 `_selectProduct(product)`，设置产品 ID、清除 `_rateManuallyEdited` 并允许覆盖；自由文本 `onChanged` 只在名称精确匹配目录产品时关联 ID，并使用 `allowOverwrite: !_rateManuallyEdited`。

- [ ] **Step 7: 运行目录和表单测试**

Run: `flutter test --no-pub test/features/deposits/product_catalog_service_test.dart test/features/deposits/editable_catalog_field_test.dart test/features/deposits/deposit_form_page_test.dart`

Expected: PASS。

- [ ] **Step 8: 提交**

```bash
git add lib/features/deposits/application/product_catalog_service.dart lib/features/deposits/presentation/deposit_form_page.dart test/features/deposits/product_catalog_service_test.dart test/features/deposits/deposit_form_page_test.dart
git commit -m "feat: link deposit fields to dated product rates"
```

---

### Task 4: 全量回归与 APK

**Files:**
- Verify only; no generated Windows files are committed.

**Interfaces:**
- Consumes: Tasks 1-3 的完整实现。
- Produces: 可安装的 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **Step 1: 格式、差异和静态分析**

Run: `dart format lib/app/app.dart lib/features/deposits test/features/deposits`

Run: `git diff --check`

Run: `flutter analyze --no-pub`

Expected: 全部 exit 0，静态分析显示 `No issues found!`。

- [ ] **Step 2: 全量测试**

Run: `flutter test --no-pub`

Expected: exit 0，所有测试通过。

- [ ] **Step 3: 构建 APK**

Run: `flutter build apk --debug --no-pub`

Expected: exit 0，生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **Step 4: 边界检查并提交必要收尾**

确认不暂存 `windows/flutter/generated_*`、`docs/testing/session-handoff-2026-07-20.md` 和既存行尾变更。若格式化产生本任务相关变更：

```bash
git add pubspec.yaml pubspec.lock lib/app/app.dart lib/features/deposits test/features/deposits
git commit -m "test: verify catalog driven deposit form"
```
