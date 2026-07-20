# 真机回归问题修复实施计划

**目标：** 修复通知健康状态误报、客户页续期状态滞后、存款详情缺少续期管理，以及提示语复制触发 Flutter 框架断言的问题。

**架构：** 保留现有 Riverpod 控制器、客户存款链 Future、DepositWorkflow 和 Dialog 导航结构。通知问题修正展示条件；客户同步在卡片接收新结果时重载已展开链；详情操作复用现有续期/停止/编辑流程；提示语控制器下沉到 Stateful Dialog 生命周期。

**技术栈：** Flutter、Riverpod 3、Drift、flutter_test。

## 全局约束

- 每个任务先补失败测试，再实现最小修复。
- 不引入全局缓存失效框架或 Drift Stream 重构。
- 只有 active 且存在 `editableDraft` 的存款可续期、停止或编辑。
- 操作完成后同时刷新客户目录和当前已展开的存款链。
- 通用错误不向用户暴露内部异常；`DepositNotActiveException` 使用既定可读文案。
- 真机连接失败时不重复无差别尝试，最终提供新 APK 和手动验收清单。

---

### Task 1：修复通知健康状态 Banner

**文件：**
- 修改：`lib/features/dashboard/presentation/dashboard_page.dart`
- 测试：`test/features/dashboard/dashboard_page_test.dart`
- 测试：`test/core/notifications/notification_capability_test.dart`

- [ ] **步骤 1：写失败测试**

增加以下场景：

1. capability 为 supported、通知允许、精确提醒允许、message 为空、busy 为 false 时，不显示 `NotificationStatusBanner`。
2. 通知权限缺失时显示明确文案和“开启通知”。
3. 精确提醒缺失时显示明确文案和“开启精确提醒”。
4. 重排成功且无降级原因后清除旧错误消息。

- [ ] **步骤 2：运行聚焦测试确认失败**

```powershell
flutter test test/features/dashboard/dashboard_page_test.dart test/core/notifications/notification_capability_test.dart
```

- [ ] **步骤 3：实现最小修复**

为 Banner 增加健康状态判断：能力受支持、通知允许、精确提醒允许、无消息且不忙时返回 `SizedBox.shrink()`。缺少权限时由能力状态生成明确文案，不再使用“通知提醒需要处理”作为健康状态默认值。

确认 `_record` 成功后以 `result.degradedReason` 覆盖旧消息；无降级原因时消息为 null。

- [ ] **步骤 4：验证并提交**

```powershell
flutter analyze lib/core/notifications lib/features/dashboard
flutter test test/features/dashboard/dashboard_page_test.dart test/core/notifications/notification_capability_test.dart
git add lib/features/dashboard/presentation/dashboard_page.dart test/features/dashboard/dashboard_page_test.dart test/core/notifications/notification_capability_test.dart
git commit -m "fix: hide healthy notification status"
```

---

### Task 2：刷新已展开的客户存款链

**文件：**
- 修改：`lib/features/customers/presentation/customer_pages.dart`
- 测试：`test/features/customers/customer_pages_test.dart`

- [ ] **步骤 1：写失败测试**

使用可控 `CustomerDepositHistoryUseCases`：首次展开返回 active 源记录；父级客户查询结果更新后，第二次加载返回 renewed 源记录和 active 目标记录。断言卡片无需折叠或重启即可显示“已续期”和“生效中”，并且未展开卡片不提前加载详情。

- [ ] **步骤 2：运行测试确认失败**

```powershell
flutter test test/features/customers/customer_pages_test.dart
```

- [ ] **步骤 3：实现最小修复**

在 `_CustomerCardState.didUpdateWidget` 中检测新的 `CustomerSearchResult`。当 `_chains` 已存在时，立即用 `widget.result` 重新调用 `customerDepositHistoryUseCasesProvider.load()`；从未展开的卡片继续保持 `_chains == null`。

把新增、编辑、续期和停止后的链刷新收敛到一个私有方法，避免不同操作遗漏当前卡片刷新。

- [ ] **步骤 4：验证并提交**

```powershell
flutter analyze lib/features/customers
flutter test test/features/customers/customer_pages_test.dart test/features/customers/customer_controller_test.dart
git add lib/features/customers/presentation/customer_pages.dart test/features/customers/customer_pages_test.dart
git commit -m "fix: refresh expanded customer deposits"
```

---

### Task 3：在存款详情中增加续期管理

**文件：**
- 修改：`lib/features/customers/presentation/customer_pages.dart`
- 测试：`test/features/customers/customer_pages_test.dart`

- [ ] **步骤 1：写失败测试**

覆盖以下行为：

1. active 详情显示“续期”“停止续期”“编辑”。
2. renewed 和 stopped 详情只显示“关闭”。
3. 点击续期打开预填的 `DepositFormPage(mode: renew)`。
4. 点击停止续期需要确认，只调用一次 `DepositWorkflow.stop()`。
5. 操作成功后刷新客户控制器并重新加载当前存款链。
6. 非活动异常显示“该存款已被处理，请刷新后重试”。

- [ ] **步骤 2：运行测试确认失败**

```powershell
flutter test test/features/customers/customer_pages_test.dart
```

- [ ] **步骤 3：实现最小修复**

在存款详情 actions 中，仅为 active 且有 `editableDraft` 的记录加入续期、停止续期和编辑按钮。续期与编辑复用 `DepositFormPage`；停止续期复用 `DepositWorkflow.stop()` 和确认对话框。操作期间禁用重复点击，成功后调用统一刷新方法。

- [ ] **步骤 4：验证并提交**

```powershell
flutter analyze lib/features/customers lib/features/deposits
flutter test test/features/customers/customer_pages_test.dart test/core/database/renewal_transaction_test.dart
git add lib/features/customers/presentation/customer_pages.dart test/features/customers/customer_pages_test.dart
git commit -m "feat: manage renewal from deposit details"
```

---

### Task 4：修复提示语复制生命周期

**文件：**
- 修改：`lib/features/dashboard/presentation/dashboard_page.dart`
- 测试：`test/features/dashboard/dashboard_page_test.dart`

- [ ] **步骤 1：写失败测试**

打开提示语 Dialog，修改文本并点击复制。断言剪贴板收到编辑后的内容、Dialog 关闭、显示“已复制”，并且 `tester.takeException()` 为 null。重复打开和关闭一次，验证控制器生命周期稳定。

- [ ] **步骤 2：运行测试确认失败**

```powershell
flutter test test/features/dashboard/dashboard_page_test.dart
```

- [ ] **步骤 3：实现最小修复**

新增私有 Stateful Dialog 组件，由其 State 创建和释放 `TextEditingController`。复制按钮写入剪贴板后通过 `Navigator.pop(dialogContext, true)` 返回结果；外层 `_showPrompt` 只负责渲染初始文本和在结果为 true 时显示 SnackBar。

- [ ] **步骤 4：验证并提交**

```powershell
flutter analyze lib/features/dashboard
flutter test test/features/dashboard/dashboard_page_test.dart
git add lib/features/dashboard/presentation/dashboard_page.dart test/features/dashboard/dashboard_page_test.dart
git commit -m "fix: stabilize prompt copy dialog"
```

---

### Task 5：统一验证与 APK

- [ ] 格式化：

```powershell
F:\DevTools\flutter-stable-final\flutter\bin\cache\dart-sdk\bin\dart.exe format lib test
git diff --check
```

- [ ] 静态分析与全量测试：

```powershell
flutter analyze
flutter test
```

- [ ] 构建 Debug APK：

```powershell
flutter build apk --debug
```

- [ ] 确认 `build/app/outputs/flutter-apk/app-debug.apk` 实际存在。

- [ ] 手动验收：通知授权后 Banner 消失；首页续期后客户页立即更新；详情续期管理可用；提示语复制无红屏。

## 计划自检

- 四个真机问题均映射到独立测试和实现任务。
- 没有引入新的数据库结构、全局状态框架或动态 SQL。
- 客户存款链只在已经加载过时自动刷新，避免未展开卡片产生额外查询。
- 续期管理操作只对 active 记录开放，历史记录保持只读。
- Dialog 控制器由组件自身拥有，释放时机与 Flutter 元素卸载一致。
