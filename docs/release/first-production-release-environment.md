# 首个正式版本地环境记录

日期：2026-07-21

## 已验证工具

- Flutter `3.44.6`，Dart `3.12.2`
- Android SDK `36.1.0`
- Android Gradle Plugin `9.0.1`，Gradle `9.1.0`
- JDK `21.0.10`
- Windows Release 工具链可构建并通过集成测试

## 必须保留

- Flutter SDK、Android SDK、必要 NDK 和 JDK
- Pub、Gradle 依赖缓存
- `android/key.properties` 和 `android/upload-keystore.jks`（仅本机，已被 Git 忽略）
- `build/release-candidate/deposit-renewal-manager-v1.0.0+2-universal-rc2.apk`
- 正式 APK 的 SHA-256 与发布验收记录

## 正式版记录

- 源码提交：`ec757ac`
- Tag：`v1.0.0`
- GitHub Release：`https://github.com/EVENYYF/deposit-renewal-manager/releases/tag/v1.0.0`
- 候选包：`deposit-renewal-manager-v1.0.0+2-universal-rc2.apk`
- SHA-256：`FEF32297EE60B1D4EE0EE63C50312B63E84F7CF8D89D21B0756FE7575E6198F3`

## 整理结果

- 已经用户明确确认，删除真机验收失败的 `universal-final.apk` 和更早的重复 `universal.apk`。
- 原工作树和 `testing-issues-remediation` worktree 均存在未提交修改，本轮不删除。
- 未删除 Flutter、Android SDK、JDK、Pub、Gradle、签名配置或项目构建缓存。

不得删除上述工具、缓存或签名材料来缩减本地空间；删除旧构建产物或 worktree 前必须取得明确确认。
