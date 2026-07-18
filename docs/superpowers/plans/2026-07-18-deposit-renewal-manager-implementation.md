# 存款续期管理工具实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一套 Android 手机为主、Windows 电脑为辅，可完全离线管理客户存款、到期提醒、Excel 导入和整库备份交接的 Flutter 应用。

**Architecture:** Flutter 共享展示与业务代码，Drift/SQLite 保存本地业务数据。领域规则保持纯 Dart，平台能力通过接口隔离；Android 实现系统通知，Windows 提供完整编辑能力，两端通过带校验的逻辑数据备份手动交接。

**Tech Stack:** Flutter stable、Dart、Riverpod、go_router、Drift/SQLite、flutter_local_notifications、timezone、lpinyin、excel、file_picker、file_selector、share_plus、archive、crypto、Flutter test/integration_test。

## Global Constraints

- 支持 Android 10 及以上和 Windows 10/11。
- Android 与 Windows 均可断网完成全部核心业务操作。
- 金额按“分”保存为整数；利率用定点整数和精度保存，不使用 `double`。
- 业务日期保存为 ISO `yyyy-MM-dd`；审计时间以 UTC 保存，显示时转本地时间。
- “已到期”由生效状态和本地今日派生，不作为生命周期状态落库。
- 首页分组为今日、`today+1` 至 `today+3`、本周其余日期、到期待处理。
- 文字解析完全离线，未经用户确认不得写入正式数据。
- 备份与本地数据库首版均不加密，导出和恢复界面必须提示敏感信息风险。
- 首版不实现服务器、账号、自动同步、在线 AI、自动发消息、`.xls`、批量修改或错别字纠正。
- 所有数据库迁移、续期、Excel 导入和恢复操作必须使用事务。
- 后台测试命令单次超时 60 秒；平台构建可单独设置更长超时。

## 文件结构

```text
lib/
├── main.dart                         # 启动与平台初始化
├── app/                              # 路由、主题、响应式应用壳
├── core/
│   ├── database/                     # Drift 表、DAO、迁移、事务
│   ├── backup/                       # 备份容器、校验、快照恢复
│   ├── notifications/                # 通知计划与 Android 适配
│   ├── files/                         # 跨平台文件入口
│   └── time/                          # 可测试的本地日期与时区
├── features/
│   ├── customers/                    # 客户、搜索、拼音索引
│   ├── deposits/                     # 存款、到期、续期、提醒分组
│   ├── dashboard/                    # 首页用例与界面
│   ├── text_import/                  # 离线文字解析与确认
│   ├── excel_import/                 # XLSX 映射、预览、冲突、导入
│   ├── templates/                    # 提示语模板与生成
│   └── settings/                     # 通知、备份、设备本地设置
└── shared/                           # 格式化与通用控件
test/                                 # 与 lib 目录职责对应的单元/组件测试
integration_test/                     # Android/Windows 端到端流程
tool/                                 # 生成性能数据与固定测试样本
```

---

### Task 1: 工具链门禁与双端工程骨架

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `lib/main.dart`
- Create: `lib/app/app.dart`
- Create: `test/app_smoke_test.dart`
- Create: `android/`（由 `flutter create` 生成）
- Create: `windows/`（由 `flutter create` 生成）

**Interfaces:**
- Produces: 可构建的 Android/Windows Flutter 工程和统一测试入口。

- [ ] **Step 1: 验证工具链门禁**

Run:

```powershell
flutter --version
dart --version
flutter doctor -v
```

Expected: 三条命令退出码均为 0；`flutter doctor -v` 中 Android toolchain、Visual Studio 和 Windows toolchain 无阻塞错误。当前环境已验证此步骤失败，必须先经用户确认安装 Flutter、Android SDK/JDK 和完整 Windows SDK。

- [ ] **Step 2: 创建双端工程并锁定依赖**

Run:

```powershell
flutter create --platforms=android,windows --org com.localtools .
flutter pub add flutter_riverpod go_router drift drift_flutter path_provider path uuid intl clock lpinyin decimal flutter_local_notifications timezone flutter_timezone file_picker file_selector share_plus cross_file excel archive crypto
flutter pub add --dev build_runner drift_dev custom_lint riverpod_lint mocktail
```

Expected: 生成 `pubspec.lock`，`flutter pub get` 成功；随后以锁文件版本作为本项目可复现依赖版本。

- [ ] **Step 3: 先写应用壳冒烟测试**

```dart
testWidgets('shows deposit renewal app shell', (tester) async {
  await tester.pumpWidget(const DepositRenewalApp());
  expect(find.text('存款续期'), findsOneWidget);
});
```

- [ ] **Step 4: 运行测试确认失败**

Run: `flutter test test/app_smoke_test.dart`

Expected: FAIL，提示 `DepositRenewalApp` 未定义。

- [ ] **Step 5: 实现最小应用壳**

```dart
class DepositRenewalApp extends StatelessWidget {
  const DepositRenewalApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: Text('存款续期'))),
      );
}
```

- [ ] **Step 6: 验证测试与双端构建**

Run:

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build windows --debug
```

Expected: analyze 无错误，测试全通过，Android APK 与 Windows 可执行文件生成成功。

- [ ] **Step 7: 提交工程骨架**

```powershell
git add pubspec.yaml pubspec.lock analysis_options.yaml lib test android windows
git commit -m "chore: scaffold Flutter desktop and Android app"
```

### Task 2: 到期日、派生状态与提醒分组

**Files:**
- Create: `lib/features/deposits/domain/local_date.dart`
- Create: `lib/features/deposits/domain/deposit.dart`
- Create: `lib/features/deposits/domain/expiry_calculator.dart`
- Create: `lib/features/deposits/domain/reminder_buckets.dart`
- Test: `test/features/deposits/domain/expiry_calculator_test.dart`
- Test: `test/features/deposits/domain/reminder_buckets_test.dart`

**Interfaces:**
- Produces: `ExpiryCalculator.calculate(LocalDate start, DepositTerm term)`、`Deposit.effectiveExpiryDate`、`ReminderBuckets.build(List<Deposit>, LocalDate today)`。

- [ ] **Step 1: 写月末和人工修正失败测试**

```dart
test('clamps month term to the target month end', () {
  final result = ExpiryCalculator().calculate(
    LocalDate(2025, 1, 31),
    const DepositTerm.months(1),
  );
  expect(result, LocalDate(2025, 2, 28));
});

test('keeps calculated and manually adjusted dates', () {
  final deposit = fixtureDeposit(
    calculatedExpiryDate: LocalDate(2025, 2, 28),
    finalExpiryDate: LocalDate(2025, 3, 1),
  );
  expect(deposit.isExpiryAdjusted, isTrue);
});
```

- [ ] **Step 2: 运行领域测试确认失败**

Run: `flutter test test/features/deposits/domain`

Expected: FAIL，类型与计算器尚未定义。

- [ ] **Step 3: 实现日期和到期计算**

```dart
final class ExpiryCalculator {
  LocalDate calculate(LocalDate start, DepositTerm term) => switch (term) {
        DayTerm(:final value) => start.addDays(value),
        MonthTerm(:final value) => start.addMonthsClamped(value),
        YearTerm(:final value) => start.addYearsClamped(value),
      };
}
```

- [ ] **Step 4: 写四类分组及跨周失败测试**

```dart
test('future three days wins even when it crosses week boundary', () {
  final today = LocalDate(2026, 7, 18);
  final buckets = ReminderBuckets.build([
    fixtureDeposit(expiry: LocalDate(2026, 7, 20)),
  ], today);
  expect(buckets.nextThreeDays, hasLength(1));
  expect(buckets.thisWeek, isEmpty);
});
```

- [ ] **Step 5: 实现互斥分组和派生到期状态**

```dart
if (expiry.isBefore(today)) overdue.add(deposit);
else if (expiry == today) dueToday.add(deposit);
else if (!expiry.isAfter(today.addDays(3))) nextThreeDays.add(deposit);
else if (expiry.isWithinMondayToSundayOf(today)) thisWeek.add(deposit);
```

- [ ] **Step 6: 验证全部边界**

Run: `flutter test test/features/deposits/domain`

Expected: 日/月/年、月末、闰年、跨年、手工日期、跨周分组与互斥测试全部 PASS。

- [ ] **Step 7: 提交领域规则**

```powershell
git add lib/features/deposits/domain test/features/deposits/domain
git commit -m "feat: add expiry and reminder domain rules"
```

### Task 3: Drift 数据库、事务与审计历史

**Files:**
- Create: `lib/core/database/app_database.dart`
- Create: `lib/core/database/tables/*.dart`
- Create: `lib/core/database/daos/customer_dao.dart`
- Create: `lib/core/database/daos/deposit_dao.dart`
- Create: `lib/features/customers/domain/customer_repository.dart`
- Create: `lib/features/deposits/domain/deposit_repository.dart`
- Test: `test/core/database/app_database_test.dart`
- Test: `test/core/database/renewal_transaction_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `Deposit` 与 `LocalDate`。
- Produces: `CustomerRepository`、`DepositRepository.renew`、`DepositRepository.stopRenewal`、`businessRevision`。

- [ ] **Step 1: 写 schema 和续期原子性测试**

```dart
test('renewal closes source and creates linked active deposit atomically', () async {
  final result = await repository.renew(source.id, nextDraft);
  expect((await repository.get(source.id))!.lifecycle, DepositLifecycle.renewed);
  expect((await repository.get(result.newDepositId))!.lifecycle, DepositLifecycle.active);
  expect(await repository.renewalSourceOf(result.newDepositId), source.id);
});
```

- [ ] **Step 2: 运行数据库测试确认失败**

Run: `flutter test test/core/database`

Expected: FAIL，数据库与仓储尚未定义。

- [ ] **Step 3: 定义表与约束**

```dart
class Deposits extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  IntColumn get amountCents => integer().check(amountCents.isBiggerThanValue(0))();
  TextColumn get lifecycle => text()();
  TextColumn get finalExpiryDate => text()();
  @override Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 4: 实现事务、修改历史与客户停用约束**

```dart
Future<RenewalResult> renew(String sourceId, DepositDraft next) =>
    db.transaction(() async {
      await markRenewed(sourceId);
      final newId = await insertDeposit(next);
      await insertRenewal(sourceId, newId);
      await appendAuditEntries(sourceId, newId);
      await incrementBusinessRevision();
      return RenewalResult(newDepositId: newId);
    });
```

- [ ] **Step 5: 生成 Drift 代码并验证事务回滚**

Run:

```powershell
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database
```

Expected: schema、CRUD、审计、故障注入回滚、有生效存款禁止停用全部 PASS。

- [ ] **Step 6: 提交数据核心**

```powershell
git add lib/core/database lib/features/customers/domain lib/features/deposits/domain test/core/database
git commit -m "feat: persist customers deposits and renewal history"
```

### Task 4: 拼音搜索、组合筛选与性能基线

**Files:**
- Create: `lib/features/customers/domain/name_search_index.dart`
- Create: `lib/features/customers/application/customer_search_service.dart`
- Create: `tool/seed_search_benchmark.dart`
- Test: `test/features/customers/customer_search_test.dart`
- Test: `test/performance/customer_search_benchmark_test.dart`

**Interfaces:**
- Consumes: `CustomerRepository` 与客户索引列。
- Produces: `CustomerSearchService.search(CustomerQuery query)`。

- [ ] **Step 1: 写汉字、全拼、首字母和手机号测试**

```dart
test('ranks exact, prefix and contains matches', () async {
  await seedCustomers(['张三', '张三丰', '李张三']);
  final result = await service.search(const CustomerQuery(text: 'zhangsan'));
  expect(result.map((e) => e.name), ['张三', '张三丰', '李张三']);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/customers/customer_search_test.dart`

Expected: FAIL，搜索服务未定义。

- [ ] **Step 3: 实现标准化索引与排序查询**

```dart
CustomerSearchIndex buildNameIndex(String name) => CustomerSearchIndex(
  normalizedName: normalizeSearchText(name),
  fullPinyin: PinyinHelper.getPinyinE(name, separator: '').toLowerCase(),
  initials: PinyinHelper.getShortPinyin(name).toLowerCase(),
);
```

- [ ] **Step 4: 增加银行、到期日和状态组合筛选测试并实现**

Run: `flutter test test/features/customers/customer_search_test.dart`

Expected: 组合筛选与排序全部 PASS，不做编辑距离或错别字纠正。

- [ ] **Step 5: 建立 1 万客户性能测试**

```dart
expect(samples.p95.inMilliseconds, lessThan(200));
```

Run: `flutter test test/performance/customer_search_benchmark_test.dart --reporter expanded`

Expected: 目标 Android 真机 P95 小于 200ms；开发机结果记录但不能替代真机验收。

- [ ] **Step 6: 提交搜索能力**

```powershell
git add lib/features/customers tool test/features/customers test/performance
git commit -m "feat: add pinyin and filtered customer search"
```

### Task 5: 离线文字解析与提示语模板

**Files:**
- Create: `lib/features/text_import/domain/text_deposit_parser.dart`
- Create: `lib/features/text_import/application/parse_deposit_text.dart`
- Create: `lib/features/templates/domain/message_template.dart`
- Create: `lib/features/templates/application/render_message.dart`
- Test: `test/features/text_import/text_deposit_parser_test.dart`
- Test: `test/features/templates/render_message_test.dart`

**Interfaces:**
- Produces: `TextDepositParser.parse(String)`、`ParseResult`、`renderMessage(MessageTemplate, TemplateValues)`。

- [ ] **Step 1: 写典型中文记录解析失败测试**

```dart
test('extracts structured fields and preserves remaining text', () {
  final result = parser.parse(
    '张三 13800138000 工行 定期10万元 2026年7月18日存 1年 利率1.5% 到期联系',
  );
  expect(result.phone, '13800138000');
  expect(result.amountCents, 10000000);
  expect(result.term, const DepositTerm.years(1));
  expect(result.remainingText, contains('到期联系'));
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/text_import test/features/templates`

Expected: FAIL，解析器和模板渲染器未定义。

- [ ] **Step 3: 实现清洗、候选、冲突与剩余文本**

```dart
ParseResult parse(String source) {
  final normalized = normalizer.normalize(source);
  return ParseResult(
    original: source,
    candidates: extractors.expand((e) => e.extract(normalized)).toList(),
    conflicts: conflictDetector.detect(normalized),
    remainingText: remainderExtractor.extract(normalized),
  );
}
```

- [ ] **Step 4: 实现模板变量验证和渲染**

```dart
String renderMessage(MessageTemplate template, TemplateValues values) =>
    template.tokens.map((token) => token.resolve(values)).join();
```

- [ ] **Step 5: 验证解析不会直接写库**

Run: `flutter test test/features/text_import test/features/templates`

Expected: 缺失、冲突、日期/金额异常、未知文本保留、模板缺失变量测试全部 PASS；解析用例不依赖 repository。

- [ ] **Step 6: 提交离线输入能力**

```powershell
git add lib/features/text_import lib/features/templates test/features/text_import test/features/templates
git commit -m "feat: parse deposit text and render contact messages"
```

### Task 6: 统一备份、自动快照与原子恢复

**Files:**
- Create: `lib/core/backup/backup_manifest.dart`
- Create: `lib/core/backup/backup_service.dart`
- Create: `lib/core/backup/snapshot_store.dart`
- Create: `lib/core/backup/restore_service.dart`
- Test: `test/core/backup/backup_round_trip_test.dart`
- Test: `test/core/backup/snapshot_restore_test.dart`

**Interfaces:**
- Consumes: Task 3 数据库导出/导入事务接口。
- Produces: `BackupService.exportBackup`、`inspectBackup`、`restore`、`listSnapshots`。

- [ ] **Step 1: 写跨平台逻辑数据往返与设备设置隔离测试**

```dart
test('restores business data without overwriting device settings', () async {
  final backup = await source.exportBackup();
  await target.restore(await target.inspectBackup(backup.path));
  expect(await target.customers.count(), sourceCustomerCount);
  expect(await target.deviceSettings.name(), 'Windows-PC');
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/backup`

Expected: FAIL，备份服务未定义。

- [ ] **Step 3: 实现容器清单和 SHA-256 校验**

```dart
final manifest = BackupManifest(
  formatVersion: 1,
  schemaVersion: db.schemaVersion,
  sourceDevice: deviceName,
  createdAtUtc: clock.now().toUtc(),
  counts: exported.counts,
  payloadSha256: sha256.convert(payloadBytes).toString(),
);
```

- [ ] **Step 4: 写最近 10 份、恢复前再快照和故障回退测试**

```dart
expect(await snapshots.listAutomatic(), hasLength(10));
await expectLater(service.restore(corruptBackup), throwsA(isA<BackupIntegrityException>()));
expect(await database.fingerprint(), originalFingerprint);
```

- [ ] **Step 5: 实现原子逻辑恢复与快照保留策略**

恢复顺序固定为：临时解析、校验、保存当前快照、单事务替换业务数据、重建索引；Android 通知重排由任务 9 接入。

- [ ] **Step 6: 验证损坏、版本不兼容和错误恢复回退**

Run: `flutter test test/core/backup`

Expected: 往返、校验失败、版本拒绝、只清理自动快照、恢复失败不改库、错误恢复可再次回退全部 PASS。

- [ ] **Step 7: 提交备份恢复**

```powershell
git add lib/core/backup test/core/backup
git commit -m "feat: add validated backups and recoverable snapshots"
```

### Task 7: Excel 映射、重复决策、事务导入与撤销守卫

**Files:**
- Create: `lib/features/excel_import/domain/import_models.dart`
- Create: `lib/features/excel_import/application/xlsx_preview_service.dart`
- Create: `lib/features/excel_import/application/import_commit_service.dart`
- Create: `lib/features/excel_import/application/import_undo_service.dart`
- Create: `tool/fixtures/import-standard.xlsx`
- Test: `test/features/excel_import/xlsx_preview_test.dart`
- Test: `test/features/excel_import/import_transaction_test.dart`

**Interfaces:**
- Consumes: Task 3 的事务与 `businessRevision`，Task 6 的快照恢复。
- Produces: `ImportPreview`、`DuplicateDecision`、`ImportCommitService.commit`、`ImportUndoService.canUndoLatest`。

- [ ] **Step 1: 写 `.xlsx` 预览、映射和 `.xls` 拒绝测试**

```dart
test('rejects legacy xls before parsing', () async {
  await expectLater(service.preview('customers.xls'),
      throwsA(isA<UnsupportedSpreadsheetException>()));
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/excel_import`

Expected: FAIL，Excel 服务未定义。

- [ ] **Step 3: 实现后台 isolate 解析、字段映射和错误分类**

```dart
final preview = await Isolate.run(
  () => workbookParser.parse(bytes, mapping),
);
```

- [ ] **Step 4: 写手机号重复三种决策与字段差异测试**

```dart
expect(item.availableDecisions, {
  DuplicateDecision.attachToExisting,
  DuplicateDecision.createSeparate,
  DuplicateDecision.skip,
});
```

- [ ] **Step 5: 实现导入前快照、单事务提交和批次审计**

```dart
final snapshot = await snapshots.create(operation: 'excel-import');
return database.transaction(() async {
  final result = await writer.write(resolvedRows);
  await batches.record(result, snapshot.id, await revision.current());
  return result;
});
```

- [ ] **Step 6: 实现撤销版本守卫**

仅当当前 `businessRevision` 等于导入完成时记录的 revision 时恢复导入前快照；后续编辑、续期或新关联均返回不可直接撤销及原因。

- [ ] **Step 7: 验证五类导入与回滚场景**

Run: `flutter test test/features/excel_import`

Expected: 新建客户、归入已有客户、字段覆盖、整批故障回滚、后续编辑/续期阻止撤销全部 PASS。

- [ ] **Step 8: 提交 Excel 导入**

```powershell
git add lib/features/excel_import test/features/excel_import tool/fixtures
git commit -m "feat: import validated customer deposits from xlsx"
```

### Task 8: Riverpod 用例层与双端响应式应用壳

**Files:**
- Modify: `lib/app/app.dart`
- Create: `lib/app/router.dart`
- Create: `lib/app/shell.dart`
- Create: `lib/app/theme.dart`
- Create: `lib/features/**/application/*_controller.dart`
- Test: `test/app/responsive_shell_test.dart`
- Test: `test/features/dashboard/dashboard_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 2-7 的 repository/service 接口。
- Produces: 页面只依赖的 Riverpod providers/controllers 与命名路由。

- [ ] **Step 1: 写 Android 底栏与 Windows 侧栏测试**

```dart
testWidgets('uses bottom navigation on a phone width', (tester) async {
  tester.view.physicalSize = const Size(390, 844);
  await tester.pumpWidget(testApp());
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/app test/features/dashboard/dashboard_controller_test.dart`

Expected: FAIL，响应式壳和控制器未定义。

- [ ] **Step 3: 实现五导航与响应式壳**

```dart
final compact = MediaQuery.sizeOf(context).width < 720;
return compact
    ? Scaffold(body: child, bottomNavigationBar: buildNavigationBar())
    : Scaffold(body: Row(children: [buildNavigationRail(), Expanded(child: child)]));
```

- [ ] **Step 4: 实现控制器的加载、保存、错误与刷新状态**

控制器只编排用例，不在 Widget 内直接调用 Drift、文件或通知插件。

- [ ] **Step 5: 验证布局和控制器**

Run: `flutter test test/app test/features/dashboard/dashboard_controller_test.dart`

Expected: 手机/宽屏导航、加载、空态、错误重试、保存后刷新全部 PASS。

- [ ] **Step 6: 提交应用壳**

```powershell
git add lib/app lib/features test/app test/features/dashboard
git commit -m "feat: add responsive app shell and application controllers"
```

### Task 9: Android 通知计划与平台适配

**Files:**
- Create: `lib/core/notifications/notification_plan.dart`
- Create: `lib/core/notifications/notification_scheduler.dart`
- Create: `lib/core/notifications/android_notification_scheduler.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/main.dart`
- Test: `test/core/notifications/notification_plan_test.dart`
- Test: `test/core/notifications/notification_reconcile_test.dart`

**Interfaces:**
- Consumes: Task 2 提醒规则、Task 3 数据库、Task 8 路由。
- Produces: `NotificationScheduler.capability`、`reconcileAll`、`reconcileDeposit`、`cancelDeposit`。

- [ ] **Step 1: 写每日汇总与 7/3/0 天计划测试**

```dart
expect(plan.depositOffsets, [const Duration(days: 7), const Duration(days: 3), Duration.zero]);
expect(plan.summary.counts.overdue, 2);
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/notifications`

Expected: FAIL，通知计划未定义。

- [ ] **Step 3: 实现平台无关计划与稳定整数通知 ID**

稳定 ID 持久化到数据库映射表，不直接使用 Dart 字符串 `hashCode`。

- [ ] **Step 4: 实现 Android 精确调度能力检测与降级**

```dart
final mode = capability.canScheduleExact
    ? AndroidScheduleMode.exactAllowWhileIdle
    : AndroidScheduleMode.inexactAllowWhileIdle;
```

- [ ] **Step 5: 接入重启、升级、时区变化和前台恢复重排**

Android Manifest 声明通知、重启与调度所需能力；不得承诺系统“强行停止”后的通知。通知点击使用客户 ID 和存款 ID 打开详情路由。

- [ ] **Step 6: 验证纯 Dart 测试和 Android 构建**

Run:

```powershell
flutter test test/core/notifications
flutter build apk --debug
```

Expected: 计划、取消、权限降级、时区重算测试 PASS，APK 构建成功。

- [ ] **Step 7: 真机验证 Android 10 与 Android 13+**

检查应用关闭、设备重启、通知权限拒绝、精确调度不可用、时区变化和点击跳转；记录厂商省电策略下的实际延迟。

- [ ] **Step 8: 提交通知能力**

```powershell
git add lib/core/notifications lib/main.dart android test/core/notifications
git commit -m "feat: schedule resilient Android deposit reminders"
```

### Task 10: 客户、存款、首页与续期界面

**Files:**
- Create: `lib/features/customers/presentation/*.dart`
- Create: `lib/features/deposits/presentation/*.dart`
- Create: `lib/features/dashboard/presentation/dashboard_page.dart`
- Test: `test/features/customers/customer_pages_test.dart`
- Test: `test/features/dashboard/dashboard_page_test.dart`

**Interfaces:**
- Consumes: Task 8 controllers、Task 9 通知能力状态。

- [ ] **Step 1: 写首页四区块与可见快捷操作测试**

```dart
expect(find.text('今日到期'), findsOneWidget);
expect(find.text('三天内'), findsOneWidget);
expect(find.text('本周内'), findsOneWidget);
expect(find.text('到期待处理'), findsOneWidget);
expect(find.text('续期'), findsWidgets);
expect(find.text('停止续期'), findsWidgets);
```

- [ ] **Step 2: 运行组件测试确认失败**

Run: `flutter test test/features/customers test/features/dashboard`

Expected: FAIL，页面尚未定义。

- [ ] **Step 3: 实现客户列表、搜索、详情与存款编辑表单**

表单同时支持自动到期和直接填写模式；自动模式展示计算日期，人工修改后显示调整标记。

- [ ] **Step 4: 实现首页、续期、更新和停止流程**

续期预填旧存款但创建新记录；停止、停用和覆盖类操作必须二次确认。

- [ ] **Step 5: 加入通知权限与调度失败告警**

告警提供打开系统设置或重试入口，并说明强行停止与厂商省电限制。

- [ ] **Step 6: 验证手机与 Windows 组件布局**

Run: `flutter test test/features/customers test/features/dashboard`

Expected: 空态、长姓名、多个存款、历史、修改记录、四区块和关键操作全部 PASS，无文本溢出。

- [ ] **Step 7: 提交核心业务界面**

```powershell
git add lib/features/customers/presentation lib/features/deposits/presentation lib/features/dashboard/presentation test/features
git commit -m "feat: add customer deposit and renewal workflows"
```

### Task 11: 文字确认、模板、Excel、备份与设置界面

**Files:**
- Create: `lib/features/text_import/presentation/*.dart`
- Create: `lib/features/templates/presentation/*.dart`
- Create: `lib/features/excel_import/presentation/*.dart`
- Create: `lib/features/settings/presentation/*.dart`
- Test: `test/features/text_import/text_import_page_test.dart`
- Test: `test/features/excel_import/import_wizard_test.dart`
- Test: `test/features/settings/backup_pages_test.dart`

**Interfaces:**
- Consumes: Tasks 5-7 服务与 Task 8 controllers。

- [ ] **Step 1: 写“未经确认不可保存”的文字解析界面测试**

```dart
expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '保存')).onPressed, isNull);
```

- [ ] **Step 2: 写 Excel 五步向导和冲突决策测试**

```dart
expect(find.text('选择文件'), findsOneWidget);
expect(find.text('映射字段'), findsOneWidget);
expect(find.text('校验预览'), findsOneWidget);
expect(find.text('处理重复'), findsOneWidget);
expect(find.text('确认导入'), findsOneWidget);
```

- [ ] **Step 3: 运行组件测试确认失败**

Run: `flutter test test/features/text_import test/features/excel_import test/features/settings`

Expected: FAIL，界面尚未定义。

- [ ] **Step 4: 实现解析确认、模板编辑与复制反馈**

低置信度、缺失和冲突字段明确标记；临时编辑生成文本不修改原模板；复制成功显示短反馈。

- [ ] **Step 5: 实现 Excel 导入完整向导**

文件取消作为正常中止；重复项提供归入已有、新增独立、跳过及批量应用；错误行修正或跳过后才能提交。

- [ ] **Step 6: 实现备份、快照与设置页面**

恢复前展示来源、版本、时间、计数和将丢失的记录数量；明文敏感数据警告持续可见；设备名称和系统权限不随恢复覆盖。

- [ ] **Step 7: 验证全部辅助流程**

Run: `flutter test test/features/text_import test/features/templates test/features/excel_import test/features/settings`

Expected: 解析确认、模板复制、Excel 导入/撤销守卫、备份导出、快照恢复和通知设置全部 PASS。

- [ ] **Step 8: 提交辅助界面**

```powershell
git add lib/features/text_import/presentation lib/features/templates/presentation lib/features/excel_import/presentation lib/features/settings/presentation test/features
git commit -m "feat: add import backup template and settings workflows"
```

### Task 12: 双端集成验收与发布产物

**Files:**
- Create: `integration_test/core_workflow_test.dart`
- Create: `integration_test/backup_transfer_test.dart`
- Create: `docs/testing/android-notification-matrix.md`
- Create: `docs/testing/release-checklist.md`

**Interfaces:**
- Consumes: 全部前置任务。
- Produces: 已验证的 Android APK、Windows 应用和可重复验收记录。

- [ ] **Step 1: 写端到端核心流程**

```dart
testWidgets('creates, renews, stops and searches a deposit', (tester) async {
  await flow.createCustomerAndDeposit(tester);
  await flow.verifyDashboardBucket(tester, '今日到期');
  await flow.renewDeposit(tester);
  await flow.stopRenewal(tester);
  await flow.searchByPinyin(tester, 'zs');
});
```

- [ ] **Step 2: 写 Android/Windows 备份交接流程**

导出固定数据集，在另一平台导入，比较客户、存款、续期、历史、模板与业务设置计数和内容摘要，并确认设备设置未覆盖。

- [ ] **Step 3: 运行静态检查、单测和集成测试**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d windows
```

Expected: 格式、静态检查、全部测试退出码为 0。

- [ ] **Step 4: 执行 Android 真机矩阵**

至少覆盖 Android 10 与 Android 13+：断网、应用关闭、重启、升级、时区变化、通知权限关闭、精确调度降级、点击通知路由和强行停止后的限制说明。

- [ ] **Step 5: 执行大数据与真实文件验收**

导入真实 Excel/WPS `.xlsx` 样本；用 1 万客户验证搜索 P95；验证大文件解析在 isolate 中不阻塞界面；确认 Windows 宽屏和主流 Android 屏幕无溢出。

- [ ] **Step 6: 构建发布候选产物**

Run:

```powershell
flutter build apk --release
flutter build windows --release
```

Expected: 生成可安装 Android APK 与 Windows release 目录；签名与安装器封装不在首版开发计划内，除非另行确认发布方式。

- [ ] **Step 7: 提交验收资料**

```powershell
git add integration_test docs/testing
git commit -m "test: verify offline workflows across Android and Windows"
```

## 实施顺序与审查门

```text
工具链与工程骨架
        ↓
领域规则 ── 数据库与事务
        ↓
搜索 / 文字解析 / 模板
        ↓
备份快照 ── Excel 导入撤销
        ↓
用例层与双端应用壳
        ↓
Android 通知 ── 业务界面
        ↓
辅助界面 ── 双端集成验收
```

每个任务完成后执行对应测试与代码审查，再进入下一个任务。Task 4、Task 5 可在 Task 3 后并行；Task 9 的 Android 平台适配与 Task 10 的纯界面部分可在接口稳定后并行，但同一文件不得并发修改。
