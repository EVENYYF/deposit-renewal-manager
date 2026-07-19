import 'package:deposit_renewal_manager/app/app.dart';
import 'package:deposit_renewal_manager/app/app_dependencies.dart';
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/core/database/daos/deposit_dao.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formal bindings persist, search and group SQLite data', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final customers = SqliteCustomerUseCases(
      CustomerDao(database, sourceDeviceId: localSourceDeviceId),
    );
    final workflow = DaoDepositWorkflow(
      DepositDao(database, sourceDeviceId: localSourceDeviceId),
    );
    final dashboardUseCases = SqliteDashboardUseCases(database);

    await customers.save(
      const CustomerDraft(id: 'customer-1', name: '张三', phone: '13800000000'),
    );
    final now = DateTime.now();
    final today = LocalDate(now.year, now.month, now.day);
    await workflow.create(
      DepositDraft(
        id: 'deposit-1',
        customerId: 'customer-1',
        amountCents: 100000,
        bankName: '本地银行',
        interestRateScaled: 15000,
        ratePrecision: 4,
        startDate: today,
        calculatedExpiryDate: today,
        finalExpiryDate: today,
      ),
    );

    final search = await customers.load('zhangsan');
    expect(search.single.customer.name, '张三');
    expect(search.single.deposits.single.id, 'deposit-1');

    final dashboard = await dashboardUseCases.load();
    expect(dashboard.today.single.depositId, 'deposit-1');
    expect(dashboard.nextThreeDays, isEmpty);
    expect(dashboard.thisWeek, isEmpty);
    expect(dashboard.overdue, isEmpty);
  });

  testWidgets('app owns and closes its shared database', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      DepositRenewalApp(
        database: database,
        notificationScheduler: const UnsupportedNotificationScheduler(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await expectLater(
      database.customSelect('SELECT 1').get(),
      throwsStateError,
    );
  });
}
