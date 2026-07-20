# 首个正式版发布设计

日期：2026-07-21

## 1. 目标与范围

本轮完成 `deposit-renewal-manager` 首个可追溯正式版本，建立 Android APK
体积基线、正式签名、候选包验证记录和发布后开发环境整理流程。

正式候选版本固定为 `1.0.0+2`，计划 Tag 为 `v1.0.0`。Tag、GitHub Release、
正式附件上传和推送必须在候选包验收后再次取得用户确认。

本轮只处理：

- APK 体积分析与经确认的低风险优化；
- 正式版本号、Android Release 签名和发布构建配置；
- 正式版阻塞缺陷；
- 自动化验证、候选包和发布记录；
- 正式版固定后的本地开发环境整理。

界面美化、自动快照列表直接恢复、非阻塞重构和新业务功能不进入本轮。

## 2. 工作区隔离

发布工作在 `release/v1.0.0` 分支的独立 worktree 中执行，起点为 `fa78df4`。
原工作树、其中的未提交修改、未跟踪文件以及已有测试修复 worktree 均保持原状。

创建 Release worktree 已获用户确认。删除任何文件、目录、worktree 或缓存仍需
再次取得明确确认。

## 3. 不可破坏边界

任何体积优化不得破坏以下能力：

- Android 通知、权限检查、精确提醒和提醒重排；
- Drift/SQLite 数据库与 schema v7 迁移；
- 备份导出、影响预览、恢复和旧版本备份兼容；
- Excel 和文字导入；
- 文件选择、文件导出和分享；
- Windows x64 构建与运行。

## 4. 体积基线与分析

在不改变代码、依赖和构建参数的前提下，依次构建：

```powershell
flutter build apk --debug --no-pub
flutter build apk --release --no-pub
flutter build apk --release --split-per-abi --no-pub
```

记录通用 Debug、通用 Release、`arm64-v8a`、`armeabi-v7a` 和 `x86_64` APK 的
精确字节数，同时记录命令退出码及 Flutter、Dart、Gradle、Android SDK 和 JDK
版本。

体积分析使用当前 Flutter 版本实际支持的 `--analyze-size` 参数分析单一 ABI，
并结合 Android SDK APK 工具和 ZIP 条目统计，分别识别：

- Dart AOT `libapp.so`；
- Flutter 引擎及其他原生库；
- 插件引入的原生库；
- `flutter_assets`、字体、图片和 Android 资源；
- 多 ABI 重复内容与压缩效果。

完成分析后先提交 2-3 套低风险方案。未经用户确认，不修改依赖、插件或构建参数。

## 5. 版本与签名

`pubspec.yaml` 使用 `1.0.0+2`。Android 继续使用 Flutter 注入的
`versionName` 和 `versionCode`。

`build.gradle.kts` 配置独立 Release signing config。缺少本地签名配置时 Release
构建必须失败，不得回退 Debug 签名。

签名文件、密码和本地属性文件不得提交 Git。`android/key.properties`、`*.jks`
和 `*.keystore` 必须保持忽略。用户在本机终端或 Android Studio 中录入敏感值；
代理只检查配置存在状态、Git 忽略状态和签名验证结果，不读取或输出密码、私钥、
证书内容或指纹。

## 6. 验证与候选包

候选包生成前执行：

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
flutter test integration_test/backup_transfer_test.dart
flutter test integration_test/core_workflow_test.dart -d windows
flutter build apk --release --no-pub
flutter build windows --release
```

两项 Windows 集成测试串行运行。是否正式提供 split-per-ABI APK 根据体积分析结论
决定；若决定提供，则额外执行对应 Release 构建。

候选文件名包含应用版本和 ABI。每个候选 APK 记录精确字节数和 SHA-256，并只
交由用户手动安装验证，不执行自动安装。

## 7. 源码追溯与确认门

候选版本的全部源码变更先暂存但不提交，确认没有未暂存源码差异，并记录候选源码
树。用户明确确认候选 APK 通过后，才将同一源码树固定为正式版提交。

计划 Tag `v1.0.0` 必须指向正式版源码提交，不得指向后续环境整理提交。创建或
推送 Tag、创建 GitHub Release、上传附件和推送源码前均需按发布流程再次确认。

## 8. 手动验收范围

用户手动验证至少覆盖：

- 新安装和覆盖安装；
- 通知权限、系统通知设置和提醒状态；
- 客户新增、编辑、手机号复制和修改记录；
- 产品管理、多利率版本和存款表单联动；
- 新增存款、编辑、续期和停止续期；
- 首页与客户页面刷新同步；
- Excel/文字导入关键路径；
- 备份导出、影响预览和恢复；
- 应用重启后的数据与提醒状态。

## 9. 环境整理与发布

正式版固定后只先盘点可清理内容。未取得明确确认前，不删除文件、目录、worktree
或缓存。

必须保留 Flutter SDK、Android SDK、必要 NDK、JDK、Pub 缓存、Gradle 缓存、
本地签名材料与配置、完整源码和测试、`pubspec.lock`、最近正式 APK、SHA-256 和
发布记录。

整理变更使用正式版之后的独立提交。整理后重新执行静态分析、测试和必要构建。
最终经用户确认后，依次推送正式版提交、整理提交、正式 Tag，并创建 GitHub
Release、上传正式附件和核对远程一致性。

## 10. 完成标准

- 正式签名 APK 构建成功；
- 格式检查、静态分析、全量测试和必要平台构建通过；
- 用户完成候选包手动验收；
- APK 文件名、字节数和 SHA-256 已记录；
- APK 对应唯一正式版源码提交和经确认的 Tag；
- README、CHANGELOG 和发布验收清单已更新；
- 本地必要工具、缓存和签名配置均保留；
- GitHub `main`、Tag 和正式附件核对一致；
- 仓库不包含签名材料、凭据、真实客户数据或备份文件。
