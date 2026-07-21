# 发布验收清单

## 已验证（自动化或本地构建）

- [x] `dart format --output=none --set-exit-if-changed lib test integration_test`
- [x] `flutter analyze`
- [x] `flutter test --no-pub`（当前版本 267 项通过）
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

## 首个正式版体积基线（2026-07-21）

- 正式候选版本已确认使用 `1.0.0+2`，数据库 schema 为 v7。
- Flutter `3.44.6`、Dart `3.12.2`、Android SDK `36.1.0`、Gradle `9.1.0`、
  Android Gradle Plugin `9.0.1` 和 JDK `21.0.10` 已实测可用。
- 通用 Debug APK：`178,185,407` bytes。
- 通用 Release APK：`68,778,502` bytes。
- armeabi-v7a Release APK：`22,205,802` bytes。
- arm64-v8a Release APK：`24,124,418` bytes。
- x86_64 Release APK：`25,671,622` bytes。
- `arm64` 主要原始占用为 Flutter 引擎 `11,581,856` bytes、Dart AOT
  `9,241,488` bytes、SQLite `1,526,536` bytes 和 DEX `1,310,192` bytes。
- 正式 APK 体积目标为不超过 100 MB；当前决定使用通用 APK，保留 Flutter 标准
  Release 代码压缩，不额外启用 Dart 混淆、`split-debug-info`、资源压缩或依赖
  裁剪。
- 上述 APK 均为正式签名配置前的基线，不是正式候选包。
- Flutter `--no-pub` 不会刷新插件注册器；Debug 后直接 Release `--no-pub`
  曾因残留 `integration_test` 注册项失败。正常 Release 刷新后，Release
  `--no-pub` 和 split-per-ABI 构建均通过。
- `dart format --output=none --set-exit-if-changed lib test integration_test`：通过，
  112 个文件无变化。
- `flutter analyze --no-pub`：通过，零问题。
- `flutter test --no-pub`：267 项全部通过。
- `flutter test integration_test/backup_transfer_test.dart -d windows`：通过；首次
  Windows Debug 构建约 520 秒。
- `flutter test integration_test/core_workflow_test.dart -d windows`：通过。
- Windows Release 构建通过；主程序 `deposit_renewal_manager.exe` 为 83,968
  bytes，仍需连同同目录 DLL 和 `data` 目录分发。
- Android Release 已验证在缺少本地签名配置时明确失败，不会回退 Debug 签名。
- 首个正式签名候选 `deposit-renewal-manager-v1.0.0+2-universal-final.apk`
  真机验收失败：Release 资源压缩移除 `ic_notification`，并发现客户详情
  新增存款返回问题；该包不得发布。
- 修复后正式签名通用候选 APK：
  `build/release-candidate/deposit-renewal-manager-v1.0.0+2-universal-rc2.apk`。
- `rc2` 大小：`68,779,046` bytes；SHA-256：
  `FEF32297EE60B1D4EE0EE63C50312B63E84F7CF8D89D21B0756FE7575E6198F3`。
- `rc2` 的 `versionName=1.0.0`、`versionCode=2`，APK v2 签名验证通过；
  APK 资源表已验证包含 `ic_notification`。
- `rc2` 已生成，用户手动安装复验仍待执行；正式源码提交和 Tag
  不得提前创建。
