# 首个正式版发布与开发环境整理流程

更新时间：2026-07-20

## 目标

完成存款续期管理 App 的首个可追溯正式版本，降低 Android 安装包体积，建立
Release 签名与发布记录，并在发布后整理本地项目，使下一轮开发可以直接开始，
无需重新下载大量依赖或重建基础环境。

本轮不进行界面美化，也不实现自动快照列表直接恢复。两项需求进入后续迭代。

## 当前基线

- GitHub `main` 已包含当前功能版本和开发日志。
- 当前应用版本配置为 `1.0.0+1`，正式版本号需在发布流程中最终确认。
- `flutter analyze --no-pub` 已通过。
- `flutter test --no-pub` 已有 265 项测试通过。
- Android Debug APK 已构建，并由用户完成当前版本手机主要流程验收。
- Windows Release 已构建，分发时必须保留完整 `Release` 目录。
- 正式 Android Release 签名、安装包体积优化和 GitHub Release 尚未完成。

上述状态必须在新会话中重新核对；不能只依据本文断言当前环境仍然有效。

## 工作顺序

### 阶段 1：冻结正式版范围

1. 从当前代码建立发布基线，不混入界面美化和新业务功能。
2. 只处理以下内容：
   - APK 体积分析与低风险优化；
   - 正式版本号；
   - Android Release 签名；
   - 发布构建配置；
   - 正式版阻塞缺陷；
   - 发布文档与校验记录。
3. 快照直接恢复、界面美化和非阻塞重构进入待办，不在本轮实现。

### 阶段 2：建立安装包体积基线

分别构建并记录：

```powershell
flutter build apk --debug --no-pub
flutter build apk --release
flutter build apk --release --no-pub
flutter build apk --release --split-per-abi --no-pub
```

当前 Flutter 版本在 `--no-pub` 时不会重新生成平台插件注册器。Debug 构建或集成
测试可能留下包含 `integration_test` 的 Android 注册器，因此先执行一次正常
Release 构建刷新 Release 插件集合，再使用 `--no-pub` 命令取得可审计基线。

必要时使用 Flutter 的 `--analyze-size` 生成体积分析数据。记录以下内容：

- 通用 Debug APK 大小；
- 通用 Release APK 大小；
- `arm64-v8a`、`armeabi-v7a`、`x86_64` 分 ABI APK 大小；
- Dart AOT、原生库、资源和插件的主要占用；
- 每项优化前后的差值；
- 兼容性和维护风险。

先提出 2-3 套优化方案并取得用户确认，再修改依赖、构建参数或插件。优先进行
低风险优化，不以破坏通知、SQLite、备份恢复、Excel 导入、文件选择或 Windows
支持为代价换取体积下降。

### 阶段 3：配置正式版本

1. 确认正式版本号，首个正式版建议使用 `1.0.0+1`；若已有相同版本安装或发布记录，
   必须递增 build number。
2. 配置 Android Release 签名。
3. 签名文件、密码和本地属性文件不得提交 GitHub。
4. 不读取、展示或要求用户在聊天中粘贴密码、Token、私钥或签名文件内容。
5. 检查 `.gitignore` 是否覆盖签名材料和本地配置。
6. 配置混淆、资源压缩或符号处理前，验证使用的 Flutter/Android Gradle 版本确实支持。

### 阶段 4：生成正式版候选包

正式候选包必须经过：

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release
flutter build apk --release --no-pub
```

如果候选包构建前执行过集成测试或 Debug 构建，上述正常 Release 构建不得省略；
它用于移除 Release classpath 不包含的测试插件注册项。正式记录仍以随后成功的
`--no-pub` 构建为准。

如果决定发布分 ABI APK，同时执行：

```powershell
flutter build apk --release --split-per-abi --no-pub
```

生成后记录文件名、字节数和 SHA-256。正式包不得使用 Debug 签名。

### 阶段 5：真机验收

真机连接和自动安装最多尝试三次。连接、授权或调试不顺时停止自动尝试，交由用户
手动安装和验证。

至少验证：

- 新安装和覆盖安装；
- 首次通知权限和系统通知设置；
- 客户新增、编辑、手机号复制和修改记录；
- 产品管理、多个利率版本和存款表单联动；
- 日期选择器中文界面；
- 新增存款、编辑、续期和停止续期；
- 首页与客户页面刷新同步；
- Excel/文字导入的关键路径；
- 备份导出、影响预览和恢复；
- 应用重启后的数据与提醒状态。

用户明确确认候选包通过后，才能固定正式版源码提交。

### 阶段 6：固定正式版提交和 Tag

1. 确认构建输入已提交，工作区没有混入客户数据、备份文件或签名材料。
2. 创建正式版源码提交。
3. 正式 APK 必须能对应到唯一 Git commit。
4. 建议创建 `v1.0.0` Tag，但必须先取得用户确认。
5. 在 `CHANGELOG.md`、README 和发布验收清单中记录：
   - 版本号与数据库 schema；
   - Git commit 和 Tag；
   - 构建命令；
   - 测试结果；
   - APK 文件名、大小和 SHA-256；
   - 真机验收范围；
   - 已知限制。

Tag 应指向正式 APK 实际使用的源码提交，不能指向后续清理提交。

### 阶段 7：整理本地开发环境

整理工作使用正式版之后的独立提交，不改写正式 Tag。

#### 必须保留

- 完整项目源码、测试、平台目录和 `pubspec.lock`；
- Flutter SDK；
- Android SDK、必要 NDK 和 JDK；
- Pub 缓存；
- Gradle 缓存；
- 本地签名文件和不入库的签名配置；
- 数据库生成代码和项目构建脚本；
- 最近正式 APK、SHA-256 和发布记录；
- 下一轮开发需要的本地环境说明。

这些内容可以避免下次重新下载大量依赖。不得为了清理空间删除全局 Pub、Gradle、
Flutter 或 Android SDK 缓存。

#### 可清理或归档

- 过期 APK 和重复构建产物；
- 临时日志、截图和调试输出；
- 已失效的测试数据；
- 已完成且无继续价值的 worktree；
- 重复或过期的交接文档；
- 明确无用的临时脚本和报告；
- 在确认可重新生成后，必要时清理项目 `build` 目录。

删除文件、目录、worktree 或构建缓存前必须按工作区危险操作规则取得明确确认。
清理后至少执行 `flutter analyze --no-pub` 和相关快速测试，确认项目仍可直接开发。

### 阶段 8：推送 GitHub

完成正式版和本地整理后，再执行 GitHub 推送：

1. 推送正式版源码提交；
2. 推送整理提交；
3. 经用户确认后推送正式 Tag；
4. 经用户确认后创建 GitHub Release 并上传正式 APK；
5. 不上传签名材料、密码、真实客户数据、备份文件和敏感日志。

推送后核对远程 `main`、Tag 和发布附件确实对应本地记录。

### 阶段 9：开始后续界面美化

界面美化从整理后的 `main` 新建独立功能分支。新一轮先走 brainstorming，明确视觉
方向、信息密度、手机与 Windows 响应式布局、无障碍和回归范围，再开始修改 UI。

## 完成标准

只有全部满足以下条件，首个正式版发布工作才算完成：

- 正式签名 APK 构建成功；
- 静态分析和全量测试通过；
- 用户完成真机验收；
- APK 大小和 SHA-256 已记录；
- APK 可追溯到唯一 Git commit 和经确认的 Tag；
- README、开发日志和发布验收清单已更新；
- 本地开发环境保留必要缓存与工具，可直接进入下一轮开发；
- GitHub `main`、Tag 和正式附件经核对一致；
- 没有提交签名材料、凭据或真实业务数据。
