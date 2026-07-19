import 'package:deposit_renewal_manager/core/notifications/notification_plan.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = LocalDate(2026, 7, 20);

  test('plans default 7, 3 and 0 day reminders and skips past dates', () {
    final plan = NotificationPlan.build(
      deposits: [
        _stored('future', 'customer-1', today.addDays(7)),
        _stored('soon', 'customer-2', today.addDays(1)),
      ],
      today: today,
    );

    expect(plan.depositOffsets, const [
      Duration(days: 7),
      Duration(days: 3),
      Duration.zero,
    ]);
    expect(
      plan.depositReminders
          .where((item) => item.depositId == 'future')
          .map((item) => item.date),
      [today, today.addDays(4), today.addDays(7)],
    );
    expect(
      plan.depositReminders
          .where((item) => item.depositId == 'soon')
          .map((item) => item.date),
      [today.addDays(1)],
    );
  });

  test(
    'summary has mutually exclusive today next3 thisWeek overdue counts',
    () {
      final plan = NotificationPlan.build(
        deposits: [
          _stored('overdue', 'c1', today.addDays(-1)),
          _stored('today', 'c2', today),
          _stored('next3', 'c3', today.addDays(2)),
          _stored('week', 'c4', today.addDays(6)),
          _stored('inactive', 'c5', today, lifecycle: DepositLifecycle.stopped),
        ],
        today: today,
      );

      expect(plan.summary.counts.overdue, 1);
      expect(plan.summary.counts.today, 1);
      expect(plan.summary.counts.nextThreeDays, 1);
      expect(plan.summary.counts.thisWeek, 1);
      expect(
        plan.depositReminders,
        isNot(
          contains(
            predicate<DepositReminderPlan>(
              (item) => item.depositId == 'inactive',
            ),
          ),
        ),
      );
    },
  );

  test(
    'summary plans are dated one-shots with content recalculated per date',
    () {
      final plan = NotificationPlan.build(
        deposits: [_stored('d1', 'c1', today.addDays(2))],
        today: today,
        settings: const NotificationPlanSettings(summaryHorizonDays: 3),
      );

      expect(plan.summaries.map((item) => item.date), [
        today,
        today.addDays(1),
        today.addDays(2),
      ]);
      expect(plan.summaries[0].counts.nextThreeDays, 1);
      expect(plan.summaries[2].counts.today, 1);
    },
  );

  test(
    'local date plans stay on calendar dates across timezone/DST changes',
    () {
      final plan = NotificationPlan.build(
        deposits: [_stored('d1', 'c1', LocalDate(2026, 3, 8))],
        today: LocalDate(2026, 3, 1),
      );

      expect(plan.depositReminders.first.date, LocalDate(2026, 3, 1));
      expect(plan.depositReminders.last.date, LocalDate(2026, 3, 8));
    },
  );
}

StoredDeposit _stored(
  String id,
  String customerId,
  LocalDate expiry, {
  DepositLifecycle lifecycle = DepositLifecycle.active,
}) => StoredDeposit(
  deposit: Deposit.direct(id: id, expiryDate: expiry, lifecycle: lifecycle),
  customerId: customerId,
  amountCents: 1,
  bankName: '',
  interestRateScaled: 0,
  ratePrecision: 0,
  startDate: expiry,
);
