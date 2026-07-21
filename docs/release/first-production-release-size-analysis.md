# 首个正式版 APK 体积基线与分析

日期：2026-07-21

## 结论

正式版体积目标为单个 APK 不超过 100 MB。未优化通用 Release APK 为
`68,778,502` bytes，已经满足目标。

首个正式版采用通用 APK，保留 Flutter 标准 Release 代码压缩，不额外启用 Dart
混淆、`split-debug-info` 或资源压缩，也不删除或替换通知、SQLite、备份恢复、
Excel 导入、文件选择和 Windows 所需依赖。split-per-ABI APK 仅作为体积基线
保留，不作为本次主要正式包。

## 构建环境

- Flutter `3.44.6` stable；
- Dart `3.12.2`；
- Android SDK `36.1.0`；
- Android Gradle Plugin `9.0.1`；
- Gradle `9.1.0`；
- JDK `21.0.10`；
- 数据库 schema `v7`。

## 未优化基线

以下 APK 均为正式签名配置前生成的体积基线，不得作为正式候选包分发。

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `app-debug.apk` | 178,185,407 | `1B10F3D81791145960698A9C7FEC93AF1D2D3844ED19163E1AAF7AF1C22846A1` |
| `app-release.apk` | 68,778,502 | `6CDBC442FA1EC9B0B7779BC7461F22D5A09F66F1034CF6B299BB2E733DEDE672` |
| `app-armeabi-v7a-release.apk` | 22,205,802 | `2B23838CBB4294741F44DAF741B342B066B3FAEEE2018D4671CC6898394986F8` |
| `app-arm64-v8a-release.apk` | 24,124,418 | `0D4A9961FE3F27866F22C26CA270494E527AE3B167B6CE15AADEF6475C4BCFAA` |
| `app-x86_64-release.apk` | 25,671,622 | `6659D2BAAFF471417608AF7646D53F060547FBFCBA222E3B2B9DA1AEB91E2819` |

相对通用 Release，三个 ABI 包分别减少约 67.7%、64.9% 和 62.7%。如果未来单包
体积目标收紧，可优先改为按 ABI 分发，不需要改变运行时功能。

## arm64 主要占用

`--analyze-size` 和 APK 文件统计显示：

| 内容 | APK 内原始字节数 | APK 内估算下载字节数 |
| --- | ---: | ---: |
| Flutter 引擎 `libflutter.so` | 11,581,856 | 5,394,136 |
| Dart AOT `libapp.so` | 9,241,488 | 3,798,969 |
| SQLite `libsqlite3.so` | 1,526,536 | 779,977 |
| Android `classes.dex` | 1,310,192 | 582,585 |
| JNI `libdartjni.so` | 124,744 | 23,382 |
| Flutter `NOTICES.Z` | 120,798 | 120,816 |

Dart AOT 的主要包占用包括：

- Flutter 框架约 3 MB；
- 应用业务代码约 677 KB；
- `timezone` 约 264 KB；
- `drift` 约 164 KB；
- `riverpod` 约 103 KB；
- `sqlite3` 和 `archive` 各约 98 KB；
- `intl` 约 92 KB；
- `excel` 约 90 KB。

字体已由 Flutter tree shaking 裁剪 99% 以上，Flutter assets 总体不是主要占用。

## 插件与资源结论

- `sqlite3_flutter_libs` 提供必要的 SQLite 原生库，是最大的业务相关原生占用；
- `file_picker` 引入 Apache Tika，约占 305 KB DEX，并包含约 51 KB MIME 等资源；
- 通知和闹钟插件的 Android 代码体积较小；
- 通用 APK 的主要额外体积来自多个 ABI 的 Flutter 引擎、Dart AOT 和原生库重复；
- 删除 Tika、SQLite 或文件插件的收益远小于 ABI 拆分，且会破坏关键功能边界。

## 构建流程发现

Flutter `3.44.6` 在使用 `--no-pub` 时不会重新生成平台插件注册器。Debug 构建后
直接执行 Release `--no-pub`，可能复用包含 `integration_test` 的 Debug Android
注册器，从而因 Release classpath 已过滤测试插件而编译失败。

本轮先执行一次正常 Release 构建，使 Flutter 按 Release 模式刷新注册器，再重跑
Release `--no-pub`，取得成功退出码和可审计基线。该行为需要同步到发布流程。

## 决策记录

首个正式版优先降低发布风险，而不是继续追求体积下降：

- 正式候选使用通用 APK；
- 不启用代码混淆；
- 不启用 `split-debug-info`；
- 保留 Flutter 标准 Release 代码压缩，不增加自定义 R8 或资源压缩配置；
- 不调整当前插件或业务依赖；
- 正式签名后的候选包必须重新记录文件名、字节数和 SHA-256。
