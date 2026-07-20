# 真机回归问题修复设计

日期：2026-07-20

## 1. 背景与目标

本设计处理首轮真机验证发现的四个问题：通知权限已允许但首页仍显示错误状态、首页续期后客户页存款链不更新、存款详情缺少续期管理，以及复制提示语后触发 Flutter 框架断言。

本轮继续沿用现有 Flutter、Riverpod、Drift、UseCase 和 Repository 分层，只修复状态边界和组件生命周期，不引入全局缓存框架或数据库 Stream 重构。

## 2. 通知状态 Banner

### 根因

`NotificationStatusBanner` 只在能力对象为空时隐藏。能力检查成功后，即使通知权限和精确提醒均正常，只要 `capability` 非空，Banner 仍会显示默认文案，并把操作退化成无明显反馈的“重试”。

### 设计

- 能力完全正常、没有提示消息且不忙时隐藏 Banner。
- 缺少通知权限时显示明确的通知授权文案和“开启通知”。
- 缺少精确提醒能力时显示明确文案和“开启精确提醒”。
- 初始化、重排或设置跳转失败时显示错误消息和可执行的重试入口。
- `reconcileAll()` 成功且没有降级原因时清除旧消息，使 Banner 自动消失。

## 3. 客户页续期状态同步

### 根因

客户控制器刷新后会生成新的 `CustomerSearchResult`，但已经展开的 `_CustomerCardState` 仍持有旧的 `_chains` Future。列表数据虽然刷新，展开区域仍展示旧存款链，直到应用重启或卡片重新创建。

### 设计

- `_CustomerCardState.didUpdateWidget` 检测新的客户查询结果。
- 若该卡片此前已加载存款链，则立即使用新结果重新调用 `CustomerDepositHistoryUseCases.load()`。
- 未展开、未加载过详情的卡片不提前查询，保留惰性加载。
- 续期、停止、编辑和新增存款完成后，继续刷新客户控制器，并主动重载当前卡片存款链。
- 搜索词、银行筛选、产品筛选和展开状态保持不变。

## 4. 存款详情续期管理

### 操作范围

- `active` 且存在 `editableDraft` 的存款详情显示“续期”“停止续期”“编辑”。
- `renewed` 和 `stopped` 记录只读，不显示业务操作按钮。
- 续期使用现有 `DepositFormPage` 的 `DepositFormMode.renew`，传入源存款、客户姓名和手机号。
- 编辑继续使用 `DepositFormMode.update`。
- 停止续期使用现有 `DepositWorkflow.stop()`，操作前显示确认对话框。

### 完成后的刷新

操作成功后关闭对应对话框，刷新 `CustomerController`，并重新加载当前客户的存款链。停止或续期遇到 `DepositNotActiveException` 时显示“该存款已被处理，请刷新后重试”。通知同步失败不回滚已经提交的业务状态。

## 5. 提示语复制生命周期

### 根因

当前 `_showPrompt` 在外层方法创建 `TextEditingController`。复制按钮关闭 Dialog 后，`showDialog` Future 可能先完成，外层立即调用 `dispose()`，而 TextField 依赖关系尚未完全卸载，从而触发 `_dependents.isEmpty` 断言。

### 设计

- 把提示语编辑器提取为独立 Stateful Dialog。
- Dialog State 创建并持有 `TextEditingController`，由 State 的 `dispose()` 统一释放。
- 复制成功后先写入剪贴板，再关闭 Dialog；外层根据返回结果显示“已复制”。
- 外层不再直接管理或提前释放输入控制器。

## 6. 测试与验证

新增或更新以下回归测试：

1. 通知能力完全正常时 Banner 不显示；权限或精确提醒缺失时显示正确操作。
2. 客户卡片已经展开时，新的 `CustomerSearchResult` 会触发存款链重新加载，并显示源记录“已续期”和目标记录“生效中”。
3. active 存款详情显示续期、停止续期和编辑；历史或停止记录只读。
4. 详情页续期和停止成功后刷新客户列表及当前存款链。
5. 点击提示语复制后 Dialog 安全关闭、显示成功反馈且 `tester.takeException()` 为空。
6. 运行相关聚焦测试、`flutter analyze`、全量 `flutter test` 和 Debug APK 构建。

## 7. 完成标准

- 四个真机问题均有对应自动化回归测试。
- 通知健康状态不再显示误导 Banner。
- 首页续期后，客户页无需重启即可看到最新生命周期。
- active 存款详情可直接续期、停止续期或编辑。
- 提示语复制不再触发 Flutter 框架断言。
- 静态分析、全量测试和 Debug APK 构建通过。
