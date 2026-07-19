# Task 9 修复报告：Android 通知可靠性

日期：2026-07-19  
基线：`c5aec0a`

## 已完成

- Android 13+ 通知权限改为首页/设置页显式用户触发；精确闹钟权限可选，拒绝后使用非精确调度。
- 新增持久可见的通知 capability/status controller，记录 denied、degraded、partial、error 与初始化异常；授权后执行 `reconcileAll`。
- 新增 `NotificationMutationCoordinator` 及新增/更新、续期、停止/删除的明确后置用例；Customer、Dashboard 和 Excel 导入生产 provider 已接入，通知失败仅产生 warning。
- 单笔提醒按到期日排序并限制 400 条，返回截断数量；调度采用先覆盖期望 ID、全部成功后取消陈旧 ID，中途失败保留旧有效计划。
- 映射前缀查询改为 SQL `LIKE`，成功取消陈旧通知后删除映射。
- 每日汇总改为 `android_alarm_manager_plus` 单个 one-shot 后台任务；回调使用 `@pragma('vm:entry-point')`，独立初始化 binding、plugin registrant、Drift 数据库、时区和通知插件，实时查询汇总并安排下一本地汇总时刻，支持重启恢复。
- Manifest 移除无效 `TIMEZONE_CHANGED` action，加入插件官方 service/receiver、`WAKE_LOCK`，通知 small icon 改为单色 drawable。
- 应用启动/恢复前台执行重排以覆盖时区变化；初始化异常不再静默吞掉。强行停止限制仅在设置页说明。
- Windows 跨盘插件源码触发 Kotlin 增量缓存问题，项目关闭 Kotlin incremental 后 APK 构建通过。

## 验证

- `flutter test test/core/notifications`：14 项通过。
- Customer/Dashboard 控制器定向测试：11 项通过。
- Widget/响应式 UI 定向测试：10 项通过。
- `flutter test`：161 项通过。
- `flutter analyze`：无问题。
- `flutter build apk --debug`：通过，产物 `build/app/outputs/flutter-apk/app-debug.apk`。

## 未在本机自动化的验证

- Android 10 与 Android 13+ 真机权限拒绝/授权、重启、厂商省电策略和通知点击流程仍需人工验证。
