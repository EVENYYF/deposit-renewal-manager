import 'deposit.dart';
import 'local_date.dart';

final class ReminderBuckets {
  ReminderBuckets._({
    required List<Deposit> overdue,
    required List<Deposit> dueToday,
    required List<Deposit> nextThreeDays,
    required List<Deposit> thisWeek,
  }) : overdue = List.unmodifiable(overdue),
       dueToday = List.unmodifiable(dueToday),
       nextThreeDays = List.unmodifiable(nextThreeDays),
       thisWeek = List.unmodifiable(thisWeek),
       all = List.unmodifiable([
         ...overdue,
         ...dueToday,
         ...nextThreeDays,
         ...thisWeek,
       ]);

  final List<Deposit> overdue;
  final List<Deposit> dueToday;
  final List<Deposit> nextThreeDays;
  final List<Deposit> thisWeek;
  final List<Deposit> all;

  static ReminderBuckets build(List<Deposit> deposits, LocalDate today) {
    final overdue = <Deposit>[];
    final dueToday = <Deposit>[];
    final nextThreeDays = <Deposit>[];
    final thisWeek = <Deposit>[];
    final seenIds = <String>{};
    final threeDaysFromToday = today.addDays(3);

    for (final deposit in deposits) {
      if (deposit.lifecycle != DepositLifecycle.active ||
          !seenIds.add(deposit.id)) {
        continue;
      }

      final expiry = deposit.effectiveExpiryDate;
      if (expiry.isBefore(today)) {
        overdue.add(deposit);
      } else if (expiry == today) {
        dueToday.add(deposit);
      } else if (!expiry.isAfter(threeDaysFromToday)) {
        nextThreeDays.add(deposit);
      } else if (expiry.isWithinMondayToSundayOf(today)) {
        thisWeek.add(deposit);
      }
    }

    return ReminderBuckets._(
      overdue: overdue,
      dueToday: dueToday,
      nextThreeDays: nextThreeDays,
      thisWeek: thisWeek,
    );
  }
}
