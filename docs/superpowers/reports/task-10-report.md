# Task 10 报告：客户、存款、首页与续期界面

## 变更

- 新增首页四个到期提醒区块：今日到期、三天内、本周内、到期待处理。
- 首页提醒卡提供提示语、续期、更新和停止续期入口；停止续期使用二次确认。
- 扩展 `DashboardSnapshot`，支持携带提醒记录，同时保留原有汇总字段兼容性。
- 新增可注入的 `DepositWorkflow` 应用接口，统一 create/update/renew/stop 操作。
- 新增手机优先客户列表，支持姓名、手机号或拼音搜索，客户卡可展开查看存款。
- 新增存款表单，支持自动计算/直接填写到期日、人工调整标记及保存状态反馈。
- 路由接入真实首页、客户页和新增存款页；通知深链保留原有“通知”显示。

## 测试

- `flutter analyze`：通过，无问题。
- `flutter test test/features/customers/customer_pages_test.dart test/features/dashboard/dashboard_page_test.dart`：通过。
- `flutter test test/app/responsive_shell_test.dart`：通过（手机底部导航、Windows NavigationRail、通知深链、动态字体）。

## 未验证项

- 当前默认 `EmptyCustomerUseCases`、`EmptyDashboardUseCases` 与 `EmptyDepositWorkflow` 仍需由应用启动层绑定实际 DAO/use case；本任务仅定义注入边界和页面交互。
- Android 真机通知、键盘、厂商省电策略及真实 Drift 数据流待 Task 12 集成验收。
