# 发布验收清单

## 已验证（自动化或本地构建）

- [ ] `dart format --output=none --set-exit-if-changed lib test integration_test`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter test integration_test/backup_transfer_test.dart`
- [ ] `flutter test integration_test/core_workflow_test.dart -d windows`
- [ ] `flutter build apk --release`
- [ ] `flutter build windows --release`
- [ ] 检查 APK 和 Windows 输出目录确实生成，记录文件大小与时间。
- [ ] 手工打开备份设置，确认备份目标已存在时不会覆盖旧文件。

## 必须由真机/真实文件补验

- [ ] Android 10：离线创建、续期、停止、搜索和通知权限流程。
- [ ] Android 13+：通知权限、精确闹钟降级、通知点击跳转。
- [ ] 重启、升级、时区切换和应用恢复后的排程重建。
- [ ] 至少一台主流厂商设备的省电策略延迟记录。
- [ ] 真实 WPS/Excel `.xlsx` 导入，包含手机号重复、归入已有客户和新增客户。
- [ ] 一万客户数据集搜索 P95 小于 200ms（Android 真机）。
- [ ] 大段文字解析在低端手机上的界面响应和人工确认边界。
- [ ] Windows 宽屏和 Android 小屏无溢出，键盘弹出时保存按钮可见。

## 发布前数据与安全确认

- [ ] 首次备份和恢复各执行一次，并核对客户、存款、续期链、模板、审计记录数量。
- [ ] 恢复前确认影响摘要；恢复后确认设备本地通知映射和系统设置未被覆盖。
- [ ] 明确首版备份为未加密明文压缩文件，在产品提示中告知风险。
- [ ] 不将真实客户数据、备份文件、日志或凭据提交到仓库。
- [ ] 记录构建版本、数据库 schema 版本和测试命令退出码。

## 当前结论

自动化测试和本地构建通过后，仍只能标记“开发验收通过”。Android 真机矩阵、真实
Excel 文件和大数据量性能在实际执行前必须保持“待验证”，不能提前宣称发布就绪。

## 本轮执行记录（2026-07-19）

- `flutter analyze`：通过。
- `flutter test integration_test/backup_transfer_test.dart`：Windows Debug 通过。
- `flutter test integration_test/core_workflow_test.dart -d windows`：父代理修复
  客户对话框控制器生命周期和表单滚动后单独通过。
- 两份集成测试连续批量启动：第二个 Windows runner 曾出现 debug connection
  启动失败；需串行重跑，不据此判定业务失败。
- Android 10/13+ 真机、通知权限、重启/升级/时区、厂商省电、真实 Excel 和一万
  客户 P95：仍待验证。
