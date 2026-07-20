# 客户、产品与统计体验优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增加客户详情与手机号操作、结构化产品利率管理、四状态统计钻取，并把模板迁入设置、修复审计字段展示。

**Architecture:** 数据库升级到 schema v7，新增产品与利率版本表，并通过 Repository/Service 向产品管理页和存款表单提供结构化查询。客户列表改为进入独立详情页，客户详情与统计详情复用存款详情展示模型；统计查询统一为状态或银行/产品过滤。

**Tech Stack:** Flutter、Riverpod 3、Drift、SQLite、GoRouter、flutter_test。

## Global Constraints

- Android 最低 API 29，JDK 17，Dart SDK `^3.12.2`。
- 数据保持离线，本轮不增加云同步、账号或网络依赖。
- 产品修改不得改写历史存款快照。
- 产品删除使用停用/启用，不执行物理删除。
- 同一银行和产品名称唯一；同一产品同一生效日期只有一个利率版本。
- 自动匹配利率后仍允许用户手动覆盖。
- 继续兼容 schema v3-v6 备份，v7 备份必须完整往返产品配置。
- 每个任务先写失败测试，再实现最小代码并独立提交。
- 手动编辑使用 `apply_patch`；Drift 生成文件使用 `dart run build_runner build --delete-conflicting-outputs`。
- 真机连接最多尝试三次；不顺畅时交由用户手动验证。

---

## 文件结构锁定

### 新建文件

- `lib/features/deposits/domain/product_catalog_repository.dart`：产品、利率版本领域类型及 Repository 接口。
- `lib/features/deposits/application/product_catalog_service.dart`：产品查询、保存、停用和按日期匹配利率。
- `lib/features/deposits/application/deposit_details_service.dart`：按存款 ID 加载统一详情和可编辑草稿。
- `lib/core/database/daos/product_catalog_dao.dart`：Drift 持久化实现。
- `lib/features/settings/presentation/product_management_page.dart`：产品管理页面。
- `lib/features/deposits/presentation/deposit_details_view.dart`：客户和统计共用的存款详情展示模型与 Dialog。
- `lib/features/customers/presentation/customer_detail_page.dart`：客户个人资料、存款链和操作页面。
- `lib/features/customers/presentation/customer_edit_dialog.dart`：新增/编辑客户表单。
- `lib/features/customers/presentation/customer_history_formatter.dart`：审计字段和值的中文格式化。
- 对应测试文件放入现有 `test/features/...` 和 `test/core/...` 目录。

### 主要修改文件

- `lib/core/database/tables/business_tables.dart`
- `lib/core/database/app_database.dart`
- `lib/core/database/app_database.g.dart`（生成）
- `lib/core/backup/backup_manifest.dart`
- `lib/core/backup/backup_service.dart`
- `lib/app/app_dependencies.dart`
- `lib/app/router.dart`
- `lib/app/shell.dart`
- `lib/features/deposits/presentation/deposit_form_page.dart`
- `lib/features/customers/presentation/customer_pages.dart`
- `lib/features/statistics/application/deposit_statistics.dart`
- `lib/features/statistics/presentation/deposit_statistics_page.dart`
- `lib/features/statistics/presentation/deposit_statistics_detail_page.dart`

---

### Task 1: schema v7 产品与利率持久化

**Files:**
- Create: `lib/features/deposits/domain/product_catalog_repository.dart`
- Create: `lib/core/database/daos/product_catalog_dao.dart`
- Modify: `lib/core/database/tables/business_tables.dart`
- Modify: `lib/core/database/app_database.dart`
- Generate: `lib/core/database/app_database.g.dart`
- Test: `test/core/database/product_catalog_dao_test.dart`
- Test: `test/core/database/app_database_migration_test.dart`
- Test: `test/core/database/app_database_test.dart`

**Interfaces:**
- Produces: `ProductCatalogRepository`, `ProductRecord`, `ProductRateVersion`, `ProductDraft`, `ProductRateDraft`。
- Produces: `ProductCatalogDao(AppDatabase database, {DateTime Function()? nowUtc, Uuid? uuid})`。

- [ ] **Step 1: 写领域接口失败测试所需类型**

在领域文件中定义并在 DAO 测试中使用以下签名：

```dart
final class ProductRecord {
  const ProductRecord({
    required this.id,
    required this.bankName,
    required this.productName,
    required this.isActive,
  });
  final String id;
  final String bankName;
  final String productName;
  final bool isActive;
}

final class ProductRateVersion {
  const ProductRateVersion({
    required this.id,
    required this.productId,
    required this.interestRateScaled,
    required this.ratePrecision,
    required this.effectiveDate,
  });
  final String id;
  final String productId;
  final int interestRateScaled;
  final int ratePrecision;
  final LocalDate effectiveDate;
}

final class ProductDraft {
  const ProductDraft({
    required this.id,
    required this.bankName,
    required this.productName,
    this.isActive = true,
  });
  final String id;
  final String bankName;
  final String productName;
  final bool isActive;
}

final class ProductRateDraft {
  const ProductRateDraft({
    required this.id,
    required this.productId,
    required this.interestRateScaled,
    required this.ratePrecision,
    required this.effectiveDate,
  });
  final String id;
  final String productId;
  final int interestRateScaled;
  final int ratePrecision;
  final LocalDate effectiveDate;
}

abstract interface class ProductCatalogRepository {
  Future<List<ProductRecord>> listProducts({bool includeInactive = false});
  Future<ProductRecord> saveProduct(ProductDraft draft);
  Future<void> setProductActive(String productId, bool active);
  Future<List<ProductRateVersion>> listRates(String productId);
  Future<ProductRateVersion> saveRate(ProductRateDraft draft);
  Future<ProductRateVersion?> matchRate(String productId, LocalDate startDate);
}
```

- [ ] **Step 2: 写 DAO 失败测试**

覆盖：不同银行允许同名产品；同银行同名产品拒绝重复；同产品不同日期保存多条利率；同日保存更新原版本；`matchRate` 返回不晚于存入日期的最新版本；停用后默认列表排除、`includeInactive: true` 保留。

- [ ] **Step 3: 运行测试确认失败**

```powershell
flutter test test/core/database/product_catalog_dao_test.dart
```

预期：因数据表和 DAO 尚不存在而编译失败。

- [ ] **Step 4: 新增 Drift 表与索引**

在 `business_tables.dart` 新增 `Products` 和 `ProductRateVersions`。产品使用表达式唯一索引：

```sql
CREATE UNIQUE INDEX products_bank_name_product_name_idx
ON products (lower(trim(bank_name)), lower(trim(product_name)))
```

利率版本使用 `(product_id, effective_date)` 唯一索引，并为 `product_id` 建普通索引。

- [ ] **Step 5: 升级数据库到 schema v7**

把两张表加入 `@DriftDatabase(tables: [...])`，设置 `schemaVersion => 7`，在 `from < 7` 事务中按产品、利率顺序创建表和索引。

- [ ] **Step 6: 生成 Drift 代码**

```powershell
dart run build_runner build --delete-conflicting-outputs
```

预期：`app_database.g.dart` 包含 `$ProductsTable` 和 `$ProductRateVersionsTable`。

- [ ] **Step 7: 实现 DAO**

保存产品前对银行和产品名执行 `trim()`；保存利率时校验 `interestRateScaled >= 0`、`ratePrecision` 在 0 到 9 之间，并使用 `insertOnConflictUpdate` 实现同日更新。匹配查询按 `effective_date DESC` 排序并 `LIMIT 1`。

- [ ] **Step 8: 增加 v6 到 v7 迁移测试**

断言旧客户、存款和预设不变，新表存在、为空且索引可用；将 `app_database_test.dart` 的 schema 期望改为 7。

- [ ] **Step 9: 运行测试与分析**

```powershell
flutter test test/core/database/product_catalog_dao_test.dart test/core/database/app_database_migration_test.dart test/core/database/app_database_test.dart
flutter analyze lib/core/database lib/features/deposits/domain
```

预期：全部通过且无分析问题。

- [ ] **Step 10: 提交**

```powershell
git add lib/core/database lib/features/deposits/domain/product_catalog_repository.dart test/core/database
git commit -m "feat: add product rate catalog storage"
```

---

### Task 2: schema v7 备份与恢复兼容

**Files:**
- Modify: `lib/core/database/app_database.dart`
- Modify: `lib/core/backup/backup_manifest.dart`
- Modify: `lib/core/backup/backup_service.dart`
- Test: `test/core/backup/backup_round_trip_test.dart`
- Test: `test/core/backup/snapshot_restore_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `products` 和 `product_rate_versions` 表。
- Produces: v7 业务备份结构，继续接受 v3-v6。

- [ ] **Step 1: 写 v7 往返失败测试**

创建一个产品和两条利率版本，导出备份、检查清单计数、恢复到空数据库，断言产品、利率和停用状态一致。

- [ ] **Step 2: 写旧备份兼容失败测试**

基于现有备份夹具生成 schema v6 清单，不包含两张新表；检查后应补为：

```dart
expect(backup.data['products'], isEmpty);
expect(backup.data['product_rate_versions'], isEmpty);
```

- [ ] **Step 3: 运行测试确认失败**

```powershell
flutter test test/core/backup/backup_round_trip_test.dart
```

- [ ] **Step 4: 扩展业务表导出与替换顺序**

`exportBusinessData()`、`replaceBusinessData()` 和恢复影响主键映射加入：

```dart
'products': 'id',
'product_rate_versions': 'id',
```

替换顺序必须先删除利率再删除产品，写入时先产品后利率。

- [ ] **Step 5: 扩展备份清单与校验**

v7 要求固定包含两张新表；v3-v6 读取时在结构校验前补空列表。允许版本集合更新为：

```dart
{3, 4, 5, 6, database.schemaVersion}
```

- [ ] **Step 6: 增加恢复影响测试**

当前数据库存在、备份中缺失的产品或利率版本应计入 `RestoreImpact`，并在并发修改保护下拒绝过期预览。

- [ ] **Step 7: 运行备份测试**

```powershell
flutter test test/core/backup/backup_round_trip_test.dart test/core/backup/snapshot_restore_test.dart
```

- [ ] **Step 8: 提交**

```powershell
git add lib/core/database/app_database.dart lib/core/backup test/core/backup
git commit -m "feat: back up product rate catalog"
```

---

### Task 3: 产品服务、依赖绑定与管理页面

**Files:**
- Create: `lib/features/deposits/application/product_catalog_service.dart`
- Create: `lib/features/settings/presentation/product_management_page.dart`
- Modify: `lib/app/app_dependencies.dart`
- Modify: `lib/app/router.dart`
- Test: `test/features/settings/product_management_page_test.dart`
- Test: `test/features/deposits/product_catalog_service_test.dart`

**Interfaces:**
- Consumes: `ProductCatalogRepository`。
- Produces: `productCatalogServiceProvider` 和 `ProductCatalogService`。

- [ ] **Step 1: 定义服务接口并写失败测试**

```dart
final class ProductCatalogService {
  const ProductCatalogService(this.repository);
  final ProductCatalogRepository repository;

  Future<List<ProductRecord>> list({bool includeInactive = false}) =>
      repository.listProducts(includeInactive: includeInactive);

  Future<List<String>> activeBanks();
  Future<List<ProductRecord>> activeProductsForBank(String bankName);
  Future<ProductRateVersion?> matchRate(
    String productId,
    LocalDate startDate,
  ) => repository.matchRate(productId, startDate);
}
```

测试银行去重排序、产品按银行过滤和停用排除。

- [ ] **Step 2: 运行服务测试确认失败**

```powershell
flutter test test/features/deposits/product_catalog_service_test.dart
```

- [ ] **Step 3: 实现服务与 Provider 绑定**

在 `app_dependencies.dart` 用 `ProductCatalogDao(database)` 覆盖 Provider；测试环境允许注入 fake repository。

- [ ] **Step 4: 写产品管理页面失败测试**

覆盖：展示银行/产品、展开利率版本、新增产品、编辑名称、停用、启用、新增不同日期利率、同日编辑覆盖、非法利率提示。

- [ ] **Step 5: 实现产品管理页面**

页面使用搜索框和列表，不使用嵌套卡片。每个产品行显示银行、产品名、启用状态和当前最新利率；编辑使用 Dialog，利率版本使用独立 Dialog，日期使用 `showDatePicker`。

- [ ] **Step 6: 加入设置入口**

在 `_SettingsPage` 增加“产品管理”ListTile，打开 `ProductManagementPage`。本任务只增加入口，不移除模板底部导航。

- [ ] **Step 7: 运行测试与分析**

```powershell
flutter test test/features/deposits/product_catalog_service_test.dart test/features/settings/product_management_page_test.dart
flutter analyze lib/features/settings lib/features/deposits/application lib/app
```

- [ ] **Step 8: 提交**

```powershell
git add lib/features/deposits/application lib/features/settings/presentation/product_management_page.dart lib/app test/features/settings test/features/deposits/product_catalog_service_test.dart
git commit -m "feat: manage products and rate versions"
```

---

### Task 4: 存款表单按日期匹配产品利率

**Files:**
- Modify: `lib/features/deposits/presentation/deposit_form_page.dart`
- Test: `test/features/deposits/deposit_form_page_test.dart`

**Interfaces:**
- Consumes: `productCatalogServiceProvider`、`activeBanks()`、`activeProductsForBank()`、`matchRate()`。

- [ ] **Step 1: 写失败测试**

覆盖：选择银行后只显示该银行产品；选择产品和存入日期后填入适用利率；日期早于所有版本时显示提示；日期改变重新匹配；用户手动编辑利率后，不因无关字段变化覆盖；编辑模式保持存款快照；续期模式按新日期匹配。

- [ ] **Step 2: 运行测试确认失败**

```powershell
flutter test test/features/deposits/deposit_form_page_test.dart
```

- [ ] **Step 3: 增加表单状态**

```dart
List<String> _catalogBanks = const [];
List<ProductRecord> _catalogProducts = const [];
String? _selectedProductId;
bool _rateManuallyEdited = false;
String? _rateMatchMessage;
```

初始化时加载启用银行；已有存款按银行和产品名尝试关联产品 ID，但不覆盖已有利率。

- [ ] **Step 4: 实现联动方法**

```dart
Future<void> _loadProductsForBank(String bankName);
Future<void> _matchCatalogRate({required bool allowOverwrite});
void _markRateEdited(String value);
```

银行或产品变化时允许覆盖自动值；日期变化时仅在利率尚未手动覆盖或用户重新选择产品时写入匹配值。

- [ ] **Step 5: 调整银行和产品输入控件**

保留手工输入能力；存在目录候选时使用 Autocomplete/MenuAnchor 展示选项。选择产品写入产品名和 `_selectedProductId`，但 `DepositDraft` 仍保存字符串快照。

- [ ] **Step 6: 运行表单与工作流测试**

```powershell
flutter test test/features/deposits/deposit_form_page_test.dart test/core/database/renewal_transaction_test.dart
flutter analyze lib/features/deposits
```

- [ ] **Step 7: 提交**

```powershell
git add lib/features/deposits/presentation/deposit_form_page.dart test/features/deposits/deposit_form_page_test.dart
git commit -m "feat: match product rates by deposit date"
```

---

### Task 5: 提取共享存款详情组件

**Files:**
- Create: `lib/features/deposits/application/deposit_details_service.dart`
- Create: `lib/features/deposits/presentation/deposit_details_view.dart`
- Modify: `lib/app/app_dependencies.dart`
- Modify: `lib/features/customers/presentation/customer_pages.dart`
- Test: `test/features/deposits/deposit_details_view_test.dart`
- Test: `test/features/customers/customer_pages_test.dart`

**Interfaces:**
- Produces: `DepositDetailsRecord`、`DepositDetailsUseCases`、`depositDetailsUseCasesProvider`。
- Produces: `DepositDetailsViewData` 和 `showDepositDetailsDialog()`。

- [ ] **Step 1: 定义共享模型并写失败测试**

```dart
final class DepositDetailsViewData {
  const DepositDetailsViewData({
    required this.depositId,
    required this.customerName,
    required this.customerPhone,
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
});
```

测试 active 显示三操作，renewed/stopped 只读，金额和利率格式正确。

同时在 application 层定义：

```dart
final class DepositDetailsRecord {
  const DepositDetailsRecord({
    required this.data,
    required this.editableDraft,
  });
  final DepositDetailsViewData data;
  final DepositDraft? editableDraft;
}

abstract interface class DepositDetailsUseCases {
  Future<DepositDetailsRecord?> load(String depositId);
}

final depositDetailsUseCasesProvider = Provider<DepositDetailsUseCases>(
  (ref) => const EmptyDepositDetailsUseCases(),
);
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
flutter test test/features/deposits/deposit_details_view_test.dart
```

- [ ] **Step 3: 实现按 ID 加载详情服务**

正式绑定组合 `DepositRepository.get(depositId)` 和 `CustomerRepository.get(customerId)`，生成展示模型；仅 active 存款生成 `editableDraft`，renewed/stopped 返回 null。找不到存款或客户时返回 null。

- [ ] **Step 4: 实现共享 Dialog**

Dialog 只负责展示和返回 action，不直接读取 Repository 或 Controller。调用方继续负责续期、停止、编辑和刷新。

- [ ] **Step 5: 客户页面切换到共享组件**

删除 `customer_pages.dart` 内重复 `_detailRow` 和 action Dialog，映射 `CustomerDepositVersion` 到 `DepositDetailsViewData`，保持现有行为和异常文案。

- [ ] **Step 6: 运行回归测试**

```powershell
flutter test test/features/deposits/deposit_details_view_test.dart test/features/deposits/deposit_details_service_test.dart test/features/customers/customer_pages_test.dart
flutter analyze lib/features/deposits/presentation lib/features/customers
```

- [ ] **Step 7: 提交**

```powershell
git add lib/features/deposits/application/deposit_details_service.dart lib/features/deposits/presentation/deposit_details_view.dart lib/app/app_dependencies.dart lib/features/customers/presentation/customer_pages.dart test/features/deposits test/features/customers/customer_pages_test.dart
git commit -m "refactor: share deposit details presentation"
```

---

### Task 6: 客户详情页、资料编辑与手机号复制

**Files:**
- Create: `lib/features/customers/presentation/customer_detail_page.dart`
- Create: `lib/features/customers/presentation/customer_edit_dialog.dart`
- Modify: `lib/features/customers/presentation/customer_pages.dart`
- Test: `test/features/customers/customer_detail_page_test.dart`
- Test: `test/features/customers/customer_pages_test.dart`

**Interfaces:**
- Consumes: Task 5 的共享存款详情组件。
- Produces: `CustomerDetailPage({required String customerId, CustomerSearchResult? initialResult})`。

- [ ] **Step 1: 写客户列表导航失败测试**

点击客户卡片应 push `CustomerDetailPage`，列表页不再出现 ExpansionTile 展开内容；搜索、筛选和刷新仍工作。

- [ ] **Step 2: 写客户详情失败测试**

覆盖：显示姓名、手机号和存款链；无手机号显示“添加手机号”；有手机号显示复制按钮；复制成功写入剪贴板并显示“已复制手机号”；编辑后刷新姓名和手机号；新增存款、修改记录和存款详情入口可用。

- [ ] **Step 3: 运行测试确认失败**

```powershell
flutter test test/features/customers/customer_detail_page_test.dart test/features/customers/customer_pages_test.dart
```

- [ ] **Step 4: 提取客户编辑 Dialog**

提供：

```dart
Future<bool> showCustomerEditDialog(
  BuildContext context, {
  CustomerRecord? customer,
  required Future<void> Function(CustomerDraft draft) onSave,
});
```

编辑时预填姓名和手机号，手机号空字符串保存为 null；新增客户继续使用 UUID。Dialog 在 `onSave` 成功前不关闭，保存失败时保留输入、恢复按钮并显示“客户资料保存失败，请重试”。新增客户的重复检查放入调用方传入的 `onSave`，保持原有合并提示。

- [ ] **Step 5: 实现 CustomerDetailPage**

页面 watch `customerControllerProvider`，按 `customerId` 选择最新结果；首次加载可使用 `initialResult`。存款链仅在详情页加载，控制器产生新结果时重新加载。

- [ ] **Step 6: 实现复制和编辑错误处理**

使用 Stateful 子组件持有操作状态。复制异常显示“复制失败，请重试”；保存异常由 Dialog 捕获并显示可读反馈，不提前丢失输入。

- [ ] **Step 7: 运行测试与分析**

```powershell
flutter test test/features/customers/customer_detail_page_test.dart test/features/customers/customer_pages_test.dart test/features/customers/customer_controller_test.dart
flutter analyze lib/features/customers
```

- [ ] **Step 8: 提交**

```powershell
git add lib/features/customers/presentation test/features/customers
git commit -m "feat: add customer profile details"
```

---

### Task 7: 修改记录中文格式与颜色

**Files:**
- Create: `lib/features/customers/presentation/customer_history_formatter.dart`
- Modify: `lib/features/customers/presentation/customer_detail_page.dart`
- Modify: `lib/features/customers/application/customer_history_service.dart`
- Test: `test/features/customers/customer_history_formatter_test.dart`
- Test: `test/features/customers/customer_detail_page_test.dart`

**Interfaces:**
- Produces: `CustomerHistoryFormatter.formatEntry(CustomerHistoryEntry entry)` 和 `FormattedHistoryChange`。

- [ ] **Step 1: 写纯 Dart 失败测试**

```dart
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
  static List<FormattedHistoryChange> formatEntry(
    CustomerHistoryEntry entry,
  );
}
```

覆盖蛇形/驼峰字段、金额元格式、利率精度、期限单位、日期、状态中文和未知字段“其他字段”。

- [ ] **Step 2: 运行测试确认失败**

```powershell
flutter test test/features/customers/customer_history_formatter_test.dart
```

- [ ] **Step 3: 实现格式器**

字段先去除下划线并转小写匹配别名。`formatEntry` 解码完整 before/after JSON，并从同一对象读取 `ratePrecision` 或 `rate_precision` 后格式化利率；`CustomerHistoryChange.fromJson` 继续保留给兼容调用方。

- [ ] **Step 4: 实现颜色化 UI**

每个字段使用独立行：字段名 `colorScheme.primary`，原值 `colorScheme.error` 或 `onSurfaceVariant`，新值固定使用可访问的深绿色 `Color(0xFF2E7D32)`；不得在一个 Text 中拼接整行。

- [ ] **Step 5: 运行测试与分析**

```powershell
flutter test test/features/customers/customer_history_formatter_test.dart test/features/customers/customer_detail_page_test.dart
flutter analyze lib/features/customers
```

- [ ] **Step 6: 提交**

```powershell
git add lib/features/customers test/features/customers
git commit -m "fix: localize customer audit history"
```

---

### Task 8: 底部导航缩减并迁移模板入口

**Files:**
- Modify: `lib/app/shell.dart`
- Modify: `lib/app/router.dart`
- Test: `test/app/responsive_shell_test.dart`
- Test: `test/app/router_test.dart`
- Test: `test/features/templates/templates_page_test.dart`

**Interfaces:**
- Consumes: 现有 `TemplatesPage` 和 `templateBindingsProvider`。

- [ ] **Step 1: 写导航失败测试**

手机 NavigationBar 和桌面 NavigationRail 都只包含“首页、客户、新增、设置”，且 selectedIndex 与四个 StatefulShellBranch 对齐。

- [ ] **Step 2: 写设置模板入口失败测试**

点击设置中的“消息模板”应 push `TemplatesPage`，保存和预览行为保持现有测试通过。

- [ ] **Step 3: 运行测试确认失败**

```powershell
flutter test test/app/responsive_shell_test.dart test/app/router_test.dart test/features/templates/templates_page_test.dart
```

- [ ] **Step 4: 修改 shell 与 router**

移除模板 destination、rail destination、route name 和 StatefulShellBranch；设置保持索引 3。在 `_SettingsPage` 添加“消息模板”入口并注入 `templateBindingsProvider`。

- [ ] **Step 5: 运行导航测试与分析**

```powershell
flutter test test/app/responsive_shell_test.dart test/app/router_test.dart test/features/templates/templates_page_test.dart
flutter analyze lib/app lib/features/templates
```

- [ ] **Step 6: 提交**

```powershell
git add lib/app test/app test/features/templates
git commit -m "refactor: move templates into settings"
```

---

### Task 9: 四种存款状态统计钻取

**Files:**
- Modify: `lib/features/statistics/application/deposit_statistics.dart`
- Modify: `lib/features/statistics/presentation/deposit_statistics_page.dart`
- Modify: `lib/features/statistics/presentation/deposit_statistics_detail_page.dart`
- Test: `test/features/statistics/deposit_statistics_test.dart`
- Test: `test/features/statistics/deposit_statistics_page_test.dart`
- Test: `test/features/statistics/deposit_statistics_detail_page_test.dart`

**Interfaces:**
- Consumes: Task 5 的 `DepositDetailsViewData` 和共享 Dialog。
- Produces: `DepositStatisticsDetailKind`、新版 `DepositStatisticsDetailQuery`。

- [ ] **Step 1: 修改查询类型并写失败测试**

```dart
enum DepositStatisticsDetailKind {
  active,
  overdue,
  renewed,
  stopped,
  bank,
  product,
}

final class DepositStatisticsDetailQuery {
  const DepositStatisticsDetailQuery(this.kind, {this.value});
  final DepositStatisticsDetailKind kind;
  final String? value;
}
```

`DepositStatisticsUseCases.loadDetails` 修改为：

```dart
Future<List<DepositStatisticsDetail>> loadDetails(
  DepositStatisticsDetailQuery query, {
  DateTime? now,
});
```

- [ ] **Step 2: 扩展详情 DTO 测试**

`DepositStatisticsDetail` 增加 `startDate` 和 `lifecycle`。构造 active、逾期、renewed、stopped 数据，分别断言查询集合准确且不重叠。

- [ ] **Step 3: 运行应用层测试确认失败**

```powershell
flutter test test/features/statistics/deposit_statistics_test.dart
```

- [ ] **Step 4: 实现参数化 SQL**

状态条件固定从枚举映射生成，不接受任意 SQL 字符串：

```text
active  -> lifecycle = 'active' AND final_expiry_date >= today
overdue -> lifecycle = 'active' AND final_expiry_date < today
renewed -> lifecycle = 'renewed'
stopped -> lifecycle = 'stopped'
bank    -> lifecycle = 'active' AND normalized bank = value
product -> lifecycle = 'active' AND normalized product = value
```

所有查询保留 `c.is_active = 1`，排序为到期日、客户名、存款 ID。

- [ ] **Step 5: 写四状态可点击页面测试**

断言每个 `_StatusRow` 有进入箭头和 `onTap`，点击后传入对应 query；详情页显示客户、手机号、金额、利率、日期、状态，手机号可复制。

- [ ] **Step 6: 接入共享存款详情**

点击详情行时调用 `depositDetailsUseCasesProvider.load(depositId)`，再把返回的 `DepositDetailsRecord.data` 交给共享 Dialog。`editableDraft != null` 时允许续期、停止续期和编辑；操作成功后 invalidate 统计 Provider。返回 null 或加载异常时显示“存款详情加载失败，请重试”。

- [ ] **Step 7: 运行统计测试与分析**

```powershell
flutter test test/features/statistics/deposit_statistics_test.dart test/features/statistics/deposit_statistics_page_test.dart test/features/statistics/deposit_statistics_detail_page_test.dart
flutter analyze lib/features/statistics
```

- [ ] **Step 8: 提交**

```powershell
git add lib/features/statistics test/features/statistics
git commit -m "feat: drill into deposit lifecycle statistics"
```

---

### Task 10: 全量回归、README 与 Android APK

**Files:**
- Modify: `README.md`
- Modify: `docs/testing/session-handoff-2026-07-20.md` only if the user explicitly asks to version the handoff document; otherwise leave it untracked.

**Interfaces:**
- Consumes: Tasks 1-9 全部功能。

- [ ] **Step 1: 更新 README**

增加客户详情、产品利率版本和状态钻取说明；导航描述改为四项；当前版本验证数量以本轮实际 `flutter test` 输出为准。

- [ ] **Step 2: 运行格式检查**

```powershell
dart format lib test
git diff --check
```

预期：无未格式化文件和空白错误。

- [ ] **Step 3: 运行静态分析**

```powershell
flutter analyze
```

预期：`No issues found!`

- [ ] **Step 4: 运行全量测试**

```powershell
flutter test
```

预期：全部测试通过；记录实际测试数量。

- [ ] **Step 5: 构建 Android Debug APK**

```powershell
flutter build apk --debug
```

确认 `build/app/outputs/flutter-apk/app-debug.apk` 存在且更新时间属于本轮构建。

- [ ] **Step 6: 检查工作树边界**

```powershell
git status --short
git diff --check
```

不得提交既存 Windows Flutter 生成文件或未跟踪的交接文档，除非用户另行确认。

- [ ] **Step 7: 提交文档和最终调整**

```powershell
git add README.md
git commit -m "docs: document customer and product optimization"
```

- [ ] **Step 8: 真机手动验收**

验收清单：客户详情编辑和复制手机号；修改记录中文与颜色；底部四项导航；设置进入模板与产品管理；按存入日期匹配利率；四种状态进入详情。设备连接失败最多重试三次，之后提供 APK 交由用户验证。

---

## 计划自检

- 设计中的五项需求分别由 Tasks 3-9 覆盖。
- schema v7、旧备份兼容和恢复影响由 Tasks 1-2 覆盖。
- 产品表单联动明确依赖 Task 3 的服务接口。
- 客户和统计详情明确依赖 Task 5 的共享展示模型。
- 模板迁移不会与产品管理入口发生索引冲突。
- 未引入物理删除产品、历史存款回写、云同步或动态 SQL 条件。
- 每个任务均包含失败测试、聚焦验证和独立提交。
