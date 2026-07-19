import '../../features/deposits/domain/deposit.dart';
import '../../features/deposits/domain/deposit_repository.dart';
import '../../features/deposits/domain/local_date.dart';
import '../../features/deposits/domain/reminder_buckets.dart';

/// Business settings used by notification planning. Dates are local calendar
/// dates; the platform adapter supplies the timezone and clock time.
final class NotificationPlanSettings {
  const NotificationPlanSettings({
    this.depositOffsets = const [
      Duration(days: 7),
      Duration(days: 3),
      Duration.zero,
    ],
    this.summaryHour = 9,
    this.summaryMinute = 0,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.summaryHorizonDays = 30,
  }) : assert(summaryHour >= 0 && summaryHour < 24),
       assert(summaryMinute >= 0 && summaryMinute < 60),
       assert(reminderHour >= 0 && reminderHour < 24),
       assert(reminderMinute >= 0 && reminderMinute < 60),
       assert(summaryHorizonDays > 0);

  final List<Duration> depositOffsets;
  final int summaryHour;
  final int summaryMinute;
  final int reminderHour;
  final int reminderMinute;
  final int summaryHorizonDays;
}

final class NotificationSummaryCounts {
  const NotificationSummaryCounts({
    required this.today,
    required this.nextThreeDays,
    required this.thisWeek,
    required this.overdue,
  });

  final int today;
  final int nextThreeDays;
  final int thisWeek;
  final int overdue;
}

final class NotificationSummaryPlan {
  const NotificationSummaryPlan({required this.date, required this.counts});

  final LocalDate date;
  final NotificationSummaryCounts counts;
}

final class DepositReminderPlan {
  const DepositReminderPlan({
    required this.depositId,
    required this.customerId,
    required this.date,
    required this.offset,
  });

  final String depositId;
  final String customerId;
  final LocalDate date;
  final Duration offset;
}

final class NotificationPlan {
  NotificationPlan._({
    required this.today,
    required this.depositOffsets,
    required this.depositReminders,
    required this.summaries,
  });

  factory NotificationPlan.build({
    required Iterable<StoredDeposit> deposits,
    required LocalDate today,
    NotificationPlanSettings settings = const NotificationPlanSettings(),
  }) {
    final active = deposits
        .where((stored) => stored.deposit.lifecycle == DepositLifecycle.active)
        .toList(growable: false);
    final reminders = <DepositReminderPlan>[];
    for (final stored in active) {
      for (final offset in settings.depositOffsets) {
        final date = stored.deposit.effectiveExpiryDate.addDays(-offset.inDays);
        if (date.isBefore(today)) continue;
        reminders.add(
          DepositReminderPlan(
            depositId: stored.deposit.id,
            customerId: stored.customerId,
            date: date,
            offset: offset,
          ),
        );
      }
    }
    final summaries = List<NotificationSummaryPlan>.generate(
      settings.summaryHorizonDays,
      (index) {
        final date = today.addDays(index);
        return NotificationSummaryPlan(
          date: date,
          counts: _counts(active, date),
        );
      },
    );
    return NotificationPlan._(
      today: today,
      depositOffsets: List.unmodifiable(settings.depositOffsets),
      depositReminders: List.unmodifiable(reminders),
      summaries: List.unmodifiable(summaries),
    );
  }

  final LocalDate today;
  final List<Duration> depositOffsets;
  final List<DepositReminderPlan> depositReminders;
  final List<NotificationSummaryPlan> summaries;

  NotificationSummaryPlan get summary => summaries.first;

  static NotificationSummaryCounts _counts(
    List<StoredDeposit> deposits,
    LocalDate date,
  ) {
    final buckets = ReminderBuckets.build(
      deposits.map((stored) => stored.deposit).toList(growable: false),
      date,
    );
    return NotificationSummaryCounts(
      today: buckets.dueToday.length,
      nextThreeDays: buckets.nextThreeDays.length,
      thisWeek: buckets.thisWeek.length,
      overdue: buckets.overdue.length,
    );
  }
}
