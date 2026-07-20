# 发布验收清单

## 已验证（自动化或本地构建）

- [x] `dart format --output=none --set-exit-if-changed lib test integration_test`
- [x] `flutter analyze`
- [x] `flutter test --no-pub`（当前版本 265 项通过）
- [x] `flutter test integration_test/backup_transfer_test.dart` (Windows Debug)
- [x] `flutter test integration_test/core_workflow_test.dart -d windows` (串行单独运行)
- [x] `flutter build apk --release`
- [x] `flutter build windows --release`
- [x] Windows Release 输出：`build/windows/x64/runner/Release/deposit_renewal_manager.exe`，83,968 bytes。
- [x] Android Debug 输出：`build/app/outputs/flutter-apk/app-debug.apk`，197,959,158 bytes。
- [x] Android Release 输出：`build/app/outputs/flutter-apk/app-release.apk`，66,548,270 bytes；Release 构建成功。
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
- Android Release 构建重试成功：`build/app/outputs/flutter-apk/app-release.apk`，65,679,110
  bytes。
- Android 10/13+ 真机、通知权限、重启/升级/时区、厂商省电、真实 Excel 和一万
  客户 P95：仍待验证。

## vNext 执行记录（2026-07-20）

- 数据库 schema v6：v3/v4/v5 备份兼容、产品/存期字段和设备本地预设迁移通过。
- `flutter analyze`：通过；`flutter test`：210 项通过。
- Windows 备份交接与核心业务集成测试：串行运行通过。
- Windows Release：`build/windows/x64/runner/Release/deposit_renewal_manager.exe`，
  83,968 bytes。
- Android Debug：`build/app/outputs/flutter-apk/app-debug.apk`，197,959,158 bytes。
- Android Release：`build/app/outputs/flutter-apk/app-release.apk`，66,548,270 bytes。
- Kotlin 插件迁移警告仍存在但不阻塞本轮构建；后续 Flutter 版本升级前需更新相关插件。
- Android 真机通知授权、系统设置跳转、SAF 备份导出、重启/时区和省电策略仍待验证。

## 产品目录联动版本执行记录（2026-07-20）

- 银行和产品已改为可编辑下拉框，支持目录选择和自由文本输入。
- 产品候选按银行和存入日期匹配适用利率，手工修改利率后不会被日期变化覆盖。
- 日期选择器完成简体中文本地化。
- `flutter analyze --no-pub`：通过，零问题。
- `flutter test --no-pub`：265 项全部通过。
- Android Debug APK 构建成功；用户反馈当前版本手机 App 验证无问题。
- Windows Release 重新构建成功；主程序 `deposit_renewal_manager.exe` 为 83,968 bytes，需与同目录 DLL 和 `data` 目录一起分发。
- 自动快照列表直接恢复、安装包体积优化、正式签名和首个正式版 APK 暂未实现。
