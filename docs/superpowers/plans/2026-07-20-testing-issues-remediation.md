# 测试问题修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 修复交接文档中的问题 1-7，补齐回归测试并构建 Android APK，随后按最多三次重试规则准备问题 8 的真机验证。

**架构：** 保留现有 Flutter、Riverpod、UseCase、Repository、Drift 和 MethodChannel 分层。通知、续期/停止、页面刷新、统计详情分别实现并测试，业务状态提交与通知同步保持解耦。

**技术栈：** Flutter 3.x、Dart 3.12、Riverpod 3、Drift 2.31、GoRouter 17、Kotlin Android Activity、flutter_test、integration_test。

## 全局约束

- 先补失败测试，再实现最小改动；不引入全局页面状态框架或无关重构。
- 统计详情维度只能是固定的 `bank` 或 `product`，不得把用户输入作为 SQL 列名。
- 停止续期先提交 `stopped`，通知取消失败不得回滚业务状态。
- 手动刷新保留旧数据；首次加载才显示整屏 loading。
- 真机 Debug 安装/启动失败最多针对明确错误重试三次，第三次失败立即交由用户手动验证。
- Dart 命令优先使用 `F:\DevTools\flutter-stable-final\flutter\bin\cache\dart-sdk\bin\dart.exe`，Flutter 命令先用 `Get-Command flutter` 验证。

---

### 任务 1：Android 通知图标、权限与设置跳转

**文件：**
- 修改：`lib/core/notifications/android_notification_scheduler.dart`
- 修改：`android/app/src/main/kotlin/com/localtools/deposit_renewal_manager/MainActivity.kt`
- 修改：`lib/core/notifications/notification_scheduler.dart`
- 测试：`test/core/notifications/notification_capability_test.dart`
- 测试：新增 `test/core/notifications/android_notification_gateway_test.dart`

**接口：**
- `AndroidNotificationGateway.openApplicationSettings()` 返回 `Future<bool>`；成功启动任一设置页返回 `true`，异常返回 `false`。
- Dart 端仍通过 `NotificationScheduler.openSettings()` 暴露能力，控制器把 `false` 转换为“打开系统通知设置失败”。
- Kotlin MethodChannel `deposit_renewal_manager/settings` 的 `openAppSettings` 返回布尔值。

- [ ] **步骤 1：写失败测试**

在 `android_notification_gateway_test.dart` 中使用 `TestDefaultBinaryMessengerBinding` 拦截 MethodChannel，覆盖成功返回 `true`、平台异常抛错和错误结果；在 `notification_capability_test.dart` 验证控制器收到 `false` 后写入失败提示。测试必须断言没有读取或输出任何凭据。

- [ ] **步骤 2：运行聚焦测试确认失败**

运行：

```powershell
flutter test test/core/notifications/notification_capability_test.dart test/core/notifications/android_notification_gateway_test.dart
```

预期：新增测试因当前方法返回 `void` 或未注入可观测结果而失败。

- [ ] **步骤 3：实现最小修复**

将所有 Android 初始化、通知详情和每日汇总的图标值统一为 `ic_notification`，并将设置跳转改为以下行为：

```dart
static Future<bool> openApplicationSettings() async {
  final result = await _settingsChannel.invokeMethod<bool>('openAppSettings');
  return result ?? false;
}
```

Kotlin 端先尝试 `Settings.ACTION_APP_NOTIFICATION_SETTINGS` 并设置 `Settings.EXTRA_APP_PACKAGE`；`ActivityNotFoundException` 或启动异常时回退到 `ACTION_APPLICATION_DETAILS_SETTINGS`，两者成功返回 `true`，最终失败返回 `false`。

- [ ] **步骤 4：运行聚焦测试确认通过**

运行同一步骤 2 命令，预期全部 PASS；再运行 `flutter analyze lib/core/notifications android`，预期无新增诊断。

- [ ] **步骤 5：提交**

```powershell
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager add lib/core/notifications android/app/src/main/kotlin test/core/notifications
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager commit -m "fix: repair Android notification permission settings"
```

### 任务 2：续期表单与停止续期状态时序

**文件：**
- 修改：`lib/features/deposits/presentation/deposit_form_page.dart`
- 修改：`lib/features/dashboard/presentation/dashboard_page.dart`
- 修改：`lib/core/database/daos/deposit_dao.dart`
- 测试：`test/features/deposits/deposit_form_page_test.dart`
- 测试：`test/features/dashboard/dashboard_page_test.dart`
- 测试：`test/core/database/renewal_transaction_test.dart`

**接口：**
- 续期表单继续接收 `DepositFormMode.renew`、`sourceDepositId` 和 `initial`，新增只读原记录区的稳定 Keys：`renewal-original-product`、`renewal-original-rate`、`renewal-original-expiry`。
- `DepositDao.stopRenewal` 在数据库事务提交后触发通知取消；通知异常通过既有 `notificationWarning` 报告，不改变返回结果。
- 用户可见的非活动错误固定为“该存款已被处理，请刷新后重试”。

- [ ] **步骤 1：写失败测试**

在表单测试中打开 `DepositFormMode.renew`，断言原银行、产品、金额、利率和到期日可见，原区域内字段不可编辑，新产品和新利率字段可编辑。Dashboard 测试模拟停止后再次点击续期，断言只出现可读错误。事务测试增加通知取消 Future 延迟和抛错场景，断言 `lifecycle == stopped` 已提交。

- [ ] **步骤 2：运行聚焦测试确认失败**

```powershell
flutter test test/features/deposits/deposit_form_page_test.dart test/features/dashboard/dashboard_page_test.dart test/core/database/renewal_transaction_test.dart
```

预期：原信息 Keys 不存在，停止通知失败场景的时序断言失败。

- [ ] **步骤 3：实现最小修复**

在 `DepositFormPage` 的 renew 分支增加只读信息区；只对原客户和源身份保持 `readOnly`，解除产品、利率等本次续期字段的错误只读限制。保存错误分支捕获 `DepositNotActiveException` 并调用 `_showError('该存款已被处理，请刷新后重试')`。

在 `DepositDao.stopRenewal` 保持事务只负责写 `stopped`、审计和 revision；事务返回后调用通知协调器并由 `_notify` 吞掉通知错误并触发 `notificationWarning`，不得把取消完成作为页面刷新前置条件。Dashboard 停止按钮在确认后禁用重复点击，刷新时移除已停止记录。

- [ ] **步骤 4：运行聚焦测试确认通过**

重复步骤 2 命令，预期全部 PASS；额外运行 `flutter test test/core/database/renewal_transaction_test.dart -r expanded`，确认事务失败注入仍能完整回滚。

- [ ] **步骤 5：提交**

```powershell
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager add lib/features/deposits lib/features/dashboard lib/core/database/daos/deposit_dao.dart test/features/deposits test/features/dashboard test/core/database/renewal_transaction_test.dart
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager commit -m "fix: clarify renewal and stop lifecycle"
```

### 任务 3：首页与客户管理下拉刷新

**文件：**
- 修改：`lib/features/dashboard/application/dashboard_controller.dart`
- 修改：`lib/features/dashboard/presentation/dashboard_page.dart`
- 修改：`lib/features/customers/application/customer_controller.dart`
- 修改：`lib/features/customers/presentation/customer_pages.dart`
- 测试：`test/features/dashboard/dashboard_controller_test.dart`
- 测试：`test/features/dashboard/dashboard_page_test.dart`
- 测试：`test/features/customers/customer_controller_test.dart`
- 测试：`test/features/customers/customer_pages_test.dart`

**接口：**
- `DashboardController.retry()` 和 `CustomerController.retry()` 保持现有签名。
- 刷新期间状态使用带旧值的 loading 状态，失败时恢复旧值并暴露错误反馈；首次 `build()` 的 loading/error 语义不变。
- 客户页继续以 `_query`、`_selectedBank`、`_selectedProduct` 保存筛选上下文。

- [ ] **步骤 1：写失败测试**

为两个控制器增加 Future 可控的 UseCase：调用 `retry()` 后在 Future 未完成时断言旧结果仍可读，完成后断言调用次数为 1；失败时断言旧结果保留并出现错误状态。页面测试断言首页和客户页都有 `RefreshIndicator`，空状态也包裹在可滚动容器中，刷新后搜索/筛选值不变。

- [ ] **步骤 2：运行聚焦测试确认失败**

```powershell
flutter test test/features/dashboard/dashboard_controller_test.dart test/features/dashboard/dashboard_page_test.dart test/features/customers/customer_controller_test.dart test/features/customers/customer_pages_test.dart
```

预期：页面当前无 `RefreshIndicator`，刷新期间旧数据保留断言失败。

- [ ] **步骤 3：实现最小修复**

控制器刷新时使用 `AsyncLoading<Snapshot>().copyWithPrevious(state)`（或等价的 Riverpod 3 `AsyncValue` API）保留旧值，捕获失败后对已有值调用 `copyWithPrevious` 并记录错误；不要把首次加载改成带旧值模式。

页面结构统一为 `RefreshIndicator(child: AlwaysScrollableScrollView(...))`：首页包裹现有 `CustomScrollView`，客户页将 loading/error/empty/list 分支统一放进可滚动容器。`onRefresh` 直接返回对应 controller 的 `retry()` Future；刷新错误使用 SnackBar，不清空现有数据。

- [ ] **步骤 4：运行聚焦测试确认通过**

重复步骤 2 命令，预期全部 PASS；使用 `flutter test test/performance/customer_search_benchmark_test.dart` 确认搜索性能基线没有回退。

- [ ] **步骤 5：提交**

```powershell
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager add lib/features/dashboard lib/features/customers test/features/dashboard test/features/customers
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager commit -m "feat: add pull to refresh"
```

### 任务 4：银行/产品统计独立详情页

**文件：**
- 修改：`lib/features/statistics/application/deposit_statistics.dart`
- 修改：`lib/features/statistics/presentation/deposit_statistics_page.dart`
- 新增：`lib/features/statistics/presentation/deposit_statistics_detail_page.dart`
- 修改：`lib/app/router.dart`（仅在现有 MaterialPageRoute 结构中接入详情页；不改导航壳）
- 测试：`test/features/statistics/deposit_statistics_test.dart`
- 测试：`test/features/statistics/deposit_statistics_page_test.dart`
- 新增：`test/features/statistics/deposit_statistics_detail_page_test.dart`

**接口：**
- 新增 `enum DepositStatisticsDimension { bank, product }`。
- 新增不可变模型 `DepositStatisticsDetail`，字段为 `depositId`、`customerName`、`customerPhone`、`bankName`、`productName`、`amountCents`、`interestRateScaled`、`ratePrecision`、`expiryDate`。
- `DepositStatisticsUseCases.loadDetails(DepositStatisticsDimension dimension, String value)` 返回 `Future<List<DepositStatisticsDetail>>`。
- `SqliteDepositStatisticsUseCases` 只允许通过固定映射将 `bank` 映射到 `bank_name`、`product` 映射到 `product_name`。

- [ ] **步骤 1：写失败测试**

在数据测试中插入 active、renewed、stopped、非活动客户和空银行/产品记录，断言详情只返回 active 且客户有效的数据，空值分类可查询，排序为到期日、客户姓名、存款 ID。页面测试断言统计行可点击并进入独立详情页，显示客户、手机号、金额、利率和到期日。

- [ ] **步骤 2：运行聚焦测试确认失败**

```powershell
flutter test test/features/statistics/deposit_statistics_test.dart test/features/statistics/deposit_statistics_page_test.dart test/features/statistics/deposit_statistics_detail_page_test.dart
```

预期：`loadDetails`、详情模型、点击导航和详情页面尚不存在。

- [ ] **步骤 3：实现最小修复**

在 UseCase 中使用不可变映射：

```dart
const columns = <DepositStatisticsDimension, String>{
  DepositStatisticsDimension.bank: 'bank_name',
  DepositStatisticsDimension.product: 'product_name',
};
```

SQL 使用参数绑定分类值；空值分类用 `COALESCE(NULLIF(TRIM(column), ''), '')`，显示层再将空字符串显示为“未填写”。详情页用 `FutureProvider.autoDispose.family` 读取维度和值，使用 `ListView.builder` 和 `RefreshIndicator` 展示加载、空、错误、刷新状态。统计行使用 `InkWell` 或 `ListTile.onTap`，以 `MaterialPageRoute` 推入详情页。

- [ ] **步骤 4：运行聚焦测试确认通过**

重复步骤 2 命令，预期全部 PASS；运行 `flutter analyze lib/features/statistics lib/app/router.dart`，预期无新增诊断。

- [ ] **步骤 5：提交**

```powershell
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager add lib/features/statistics lib/app/router.dart test/features/statistics
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager commit -m "feat: add statistics breakdown details"
```

### 任务 5：统一验证、APK 与真机交付

**文件：**
- 可能修改：仅在前述测试暴露问题时修改对应测试或实现文件
- 产物：`build/app/outputs/flutter-apk/app-debug.apk`（具体路径以构建输出为准）
- 记录：在最终回复中报告命令、退出码、APK 路径和待验证项；不写入任何凭据

- [ ] **步骤 1：格式化并检查工作区**

```powershell
flutter format lib test
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager diff --check
```

预期格式化命令退出码为 0，`diff --check` 无输出。

- [ ] **步骤 2：运行静态分析和全量测试**

```powershell
flutter analyze
flutter test
```

预期 `flutter analyze` 无 issue，`flutter test` 全部通过；失败时只修复本轮变更引入的问题并重新执行对应聚焦测试。

- [ ] **步骤 3：构建 Debug APK**

```powershell
flutter build apk --debug
```

预期退出码为 0，并确认 APK 文件实际存在；记录绝对路径但不上传或展示敏感环境信息。

- [ ] **步骤 4：执行一次真机前置检查**

```powershell
adb version
adb devices
```

只有出现已授权设备才继续。未识别、未授权或 `adb` 不可用时立即停止真机动作，交付 APK 和手动清单。

- [ ] **步骤 5：最多三次 Debug 安装/启动尝试**

每次只针对明确错误执行一个修正动作，然后使用 `flutter install --debug` 和 `flutter run --debug` 进行下一次尝试。累计三次失败后立即停止，不再重试；记录失败摘要、尝试动作和退出码。

- [ ] **步骤 6：输出手动验收清单**

用户手动检查：Android 13+ 首次通知授权、系统通知专页、通知触达、首页/客户页下拉刷新、停止续期后卡片和通知、统计分类详情、应用重启后的数据和通知状态。未实际执行的项目统一标记为“待用户验证”。

- [ ] **步骤 7：提交验证记录**

```powershell
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager status --short
git -c safe.directory=F:/MY_CHERRY_WORKSPACE/deposit-renewal-manager log -5 --oneline
```

最终回复只汇报已验证、未验证、待用户验证三类结果，不展示凭据或设备敏感标识。

## 计划自检

- 规范覆盖：任务 1 覆盖通知问题 1-3；任务 2 覆盖续期与停止问题 4-5；任务 3 覆盖刷新问题 6；任务 4 覆盖统计详情问题 7；任务 5 覆盖 APK 与真机问题 8。
- 占位符扫描：未使用 `TBD`、`TODO`、`待定` 或未定义的未来接口；所有新接口均在对应任务的“接口”节给出名称和类型。
- 类型一致性：详情页使用 `DepositStatisticsDimension`、`DepositStatisticsDetail` 和 `loadDetails`；通知设置使用 `Future<bool>`；控制器继续使用现有 `retry()` 签名。
- 风险边界：真机失败最多三次；业务状态不依赖通知取消完成；统计 SQL 不接受动态列名。
