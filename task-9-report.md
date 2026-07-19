# Task 9 通知续排与 mutation hook 复审报告

## 残余修复

- 每日汇总后台入口将展示与续排拆开；展示、初始化或续排失败均记录错误，`finally` 始终尝试注册下一次本地 9 点闹钟。
- Android `oneShotAt` 统一传入 `allowWhileIdle: true`；精确权限仅控制 `exact`，不可用时使用插件支持的非精确 idle 调度。
- reconcile 首次处理 `summary:` 遗留映射并取消/删除数据库记录，同时清理固定旧汇总通知 ID；新计划不再生成 `summary:` 前缀。
- `DepositDao` 支持可选 `NotificationMutationCoordinator` 注入。create/update、renew、stop 在业务事务提交后调用对应 hook；hook 异常记录 warning，不回滚业务。

## 验证

- 定向通知、DAO 事务与 hook 测试：全部通过（22 tests）。
- `flutter analyze`：无问题。
- `git diff --check`：通过。

APK debug 构建待主代理使用固定 Flutter SDK 执行全量验证。
