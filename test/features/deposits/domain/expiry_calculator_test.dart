import 'package:deposit_renewal_manager/features/deposits/domain/deposit.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/expiry_calculator.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDate', () {
    test('has value equality and calendar ordering', () {
      expect(LocalDate(2025, 1, 31), LocalDate(2025, 1, 31));
      expect(LocalDate(2024, 12, 31).isBefore(LocalDate(2025, 1, 1)), isTrue);
    });

    test('rejects invalid calendar dates', () {
      expect(() => LocalDate(2025, 2, 29), throwsArgumentError);
      expect(() => LocalDate(2025, 13, 1), throwsArgumentError);
    });
  });

  group('ExpiryCalculator', () {
    final calculator = ExpiryCalculator();

    test('adds day terms across year boundaries', () {
      expect(
        calculator.calculate(
          LocalDate(2025, 12, 31),
          const DepositTerm.days(1),
        ),
        LocalDate(2026, 1, 1),
      );
    });

    test('clamps month terms to the target month end', () {
      expect(
        calculator.calculate(
          LocalDate(2025, 1, 31),
          const DepositTerm.months(1),
        ),
        LocalDate(2025, 2, 28),
      );
      expect(
        calculator.calculate(
          LocalDate(2024, 1, 31),
          const DepositTerm.months(1),
        ),
        LocalDate(2024, 2, 29),
      );
    });

    test('adds month terms across year boundaries', () {
      expect(
        calculator.calculate(
          LocalDate(2025, 11, 30),
          const DepositTerm.months(2),
        ),
        LocalDate(2026, 1, 30),
      );
    });

    test('clamps leap-day year terms', () {
      expect(
        calculator.calculate(
          LocalDate(2024, 2, 29),
          const DepositTerm.years(1),
        ),
        LocalDate(2025, 2, 28),
      );
      expect(
        calculator.calculate(
          LocalDate(2024, 2, 29),
          const DepositTerm.years(4),
        ),
        LocalDate(2028, 2, 29),
      );
    });

    test('rejects non-positive terms', () {
      expect(() => DepositTerm.days(0), throwsA(isA<AssertionError>()));
      expect(() => DepositTerm.months(-1), throwsA(isA<AssertionError>()));
      expect(() => DepositTerm.years(0), throwsA(isA<AssertionError>()));
    });
  });

  group('Deposit expiry modes and status', () {
    test('keeps calculated and manually adjusted dates', () {
      final deposit = Deposit.automatic(
        id: 'adjusted',
        calculatedExpiryDate: LocalDate(2025, 2, 28),
        finalExpiryDate: LocalDate(2025, 3, 1),
      );

      expect(deposit.calculatedExpiryDate, LocalDate(2025, 2, 28));
      expect(deposit.effectiveExpiryDate, LocalDate(2025, 3, 1));
      expect(deposit.isExpiryAdjusted, isTrue);
    });

    test('automatic date is unadjusted when final date is omitted', () {
      final calculated = LocalDate(2025, 2, 28);
      final deposit = Deposit.automatic(
        id: 'automatic',
        calculatedExpiryDate: calculated,
      );

      expect(deposit.effectiveExpiryDate, calculated);
      expect(deposit.isExpiryAdjusted, isFalse);
    });

    test('direct entry cannot carry a fabricated calculated date', () {
      final deposit = Deposit.direct(
        id: 'direct',
        expiryDate: LocalDate(2025, 8, 1),
      );

      expect(deposit.calculatedExpiryDate, isNull);
      expect(deposit.effectiveExpiryDate, LocalDate(2025, 8, 1));
      expect(deposit.isExpiryAdjusted, isFalse);
    });

    test('overdue is derived only for active deposits', () {
      final expiry = LocalDate(2025, 7, 1);
      final today = LocalDate(2025, 7, 2);

      expect(
        Deposit.direct(id: 'active', expiryDate: expiry).isOverdueOn(today),
        isTrue,
      );
      expect(
        Deposit.direct(
          id: 'renewed',
          expiryDate: expiry,
          lifecycle: DepositLifecycle.renewed,
        ).isOverdueOn(today),
        isFalse,
      );
      expect(
        Deposit.direct(
          id: 'stopped',
          expiryDate: expiry,
          lifecycle: DepositLifecycle.stopped,
        ).isOverdueOn(today),
        isFalse,
      );
    });
  });
}
