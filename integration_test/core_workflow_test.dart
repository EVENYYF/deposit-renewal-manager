import 'package:clock/clock.dart';
import 'package:deposit_renewal_manager/app/app.dart';
import 'package:deposit_renewal_manager/app/app_dependencies.dart';
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:deposit_renewal_manager/features/deposits/presentation/deposit_form_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates, renews, stops and searches a deposit', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final today = DateTime(2026, 7, 19, 9);

    await withClock(Clock.fixed(today), () async {
      await tester.pumpWidget(
        DepositRenewalApp(
          database: database,
          notificationScheduler: const UnsupportedNotificationScheduler(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('客户'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新增客户'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '姓名'), '张三');
      await tester.enterText(
        find.widgetWithText(TextFormField, '手机号（选填）'),
        '13800138000',
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('张三'), findsOneWidget);

      await tester.tap(find.text('张三'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增存款'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '金额（元）'),
        '10000',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '银行'), '测试银行');
      await tester.enterText(
        find.widgetWithText(TextFormField, '存入日期'),
        '2025-07-19',
      );
      final termField = find.widgetWithText(TextFormField, '存期');
      await tester.scrollUntilVisible(
        termField,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(termField, '12');
      await tester.enterText(
        find.widgetWithText(TextFormField, '最终到期日'),
        '2026-07-19',
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect((await database.select(database.deposits).get()).length, 1);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('首页'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('今日到期'), findsOneWidget);
      expect(
        (await SqliteDashboardUseCases(database).load()).today,
        hasLength(1),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('张三'), findsOneWidget);

      await tester.tap(find.text('续期'));
      await tester.pumpAndSettle();
      expect(find.text('续期'), findsWidgets);
      final confirmRenewal = find.widgetWithText(FilledButton, '确认续期');
      final renewalFormScroll = find
          .descendant(
            of: find.byType(DepositFormPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        confirmRenewal,
        240,
        scrollable: renewalFormScroll,
      );
      await tester.tap(confirmRenewal);
      await tester.pumpAndSettle();
      expect((await database.select(database.deposits).get()).length, 2);

      await tester.tap(find.text('停止续期').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认停止'));
      await tester.pumpAndSettle();
      expect(
        (await database.select(database.deposits).get())
            .where((row) => row.lifecycle == 'stopped')
            .length,
        1,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('客户'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'zs');
      await tester.pumpAndSettle();
      expect(find.text('张三'), findsOneWidget);
    });
  });
}
