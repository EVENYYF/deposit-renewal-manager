import 'package:deposit_renewal_manager/features/deposits/domain/deposit.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/reminder_buckets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Deposit deposit(
    String id,
    LocalDate expiry, {
    DepositLifecycle lifecycle = DepositLifecycle.active,
  }) => Deposit.direct(id: id, expiryDate: expiry, lifecycle: lifecycle);

  test('builds four mutually exclusive reminder groups by priority', () {
    final today = LocalDate(2026, 7, 13); // Monday.
    final buckets = ReminderBuckets.build([
      deposit('overdue', LocalDate(2026, 7, 12)),
      deposit('today', today),
      deposit('tomorrow', LocalDate(2026, 7, 14)),
      deposit('three-days', LocalDate(2026, 7, 16)),
      deposit('this-week', LocalDate(2026, 7, 18)),
      deposit('later', LocalDate(2026, 7, 20)),
    ], today);

    expect(buckets.overdue.map((item) => item.id), ['overdue']);
    expect(buckets.dueToday.map((item) => item.id), ['today']);
    expect(buckets.nextThreeDays.map((item) => item.id), [
      'tomorrow',
      'three-days',
    ]);
    expect(buckets.thisWeek.map((item) => item.id), ['this-week']);
    expect(buckets.all, hasLength(5));
    expect(buckets.all.map((item) => item.id).toSet(), hasLength(5));
  });

  test('future three days wins even when it crosses week boundary', () {
    final today = LocalDate(2026, 7, 18); // Saturday.
    final crossingDeposit = deposit('crossing', LocalDate(2026, 7, 20));
    final buckets = ReminderBuckets.build([crossingDeposit], today);

    expect(buckets.nextThreeDays, [crossingDeposit]);
    expect(buckets.thisWeek, isEmpty);
  });

  test('excludes renewed and stopped deposits from every group', () {
    final today = LocalDate(2026, 7, 18);
    final buckets = ReminderBuckets.build([
      deposit(
        'renewed',
        LocalDate(2026, 7, 17),
        lifecycle: DepositLifecycle.renewed,
      ),
      deposit(
        'stopped',
        LocalDate(2026, 7, 18),
        lifecycle: DepositLifecycle.stopped,
      ),
    ], today);

    expect(buckets.all, isEmpty);
  });

  test('does not duplicate the same record', () {
    final today = LocalDate(2026, 7, 18);
    final repeated = deposit('same-record', today);

    final buckets = ReminderBuckets.build([repeated, repeated], today);

    expect(buckets.dueToday, [repeated]);
    expect(buckets.all, [repeated]);
  });

  test('this week means the remaining dates through Sunday', () {
    final today = LocalDate(2026, 7, 13); // Monday.
    final buckets = ReminderBuckets.build([
      deposit('thursday', LocalDate(2026, 7, 16)),
      deposit('sunday', LocalDate(2026, 7, 19)),
      deposit('next-monday', LocalDate(2026, 7, 20)),
    ], today);

    expect(buckets.nextThreeDays.map((item) => item.id), ['thursday']);
    expect(buckets.thisWeek.map((item) => item.id), ['sunday']);
    expect(buckets.all.map((item) => item.id), isNot(contains('next-monday')));
  });
}
