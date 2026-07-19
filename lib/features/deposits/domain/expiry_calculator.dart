import 'local_date.dart';

sealed class DepositTerm {
  const DepositTerm._(this.value);

  const factory DepositTerm.days(int value) = DayTerm._;

  const factory DepositTerm.months(int value) = MonthTerm._;

  const factory DepositTerm.years(int value) = YearTerm._;

  final int value;
}

final class DayTerm extends DepositTerm {
  const DayTerm._(super.value)
    : assert(value > 0, 'Day term must be positive'),
      super._();
}

final class MonthTerm extends DepositTerm {
  const MonthTerm._(super.value)
    : assert(value > 0, 'Month term must be positive'),
      super._();
}

final class YearTerm extends DepositTerm {
  const YearTerm._(super.value)
    : assert(value > 0, 'Year term must be positive'),
      super._();
}

final class ExpiryCalculator {
  LocalDate calculate(LocalDate start, DepositTerm term) {
    if (term.value <= 0) {
      throw ArgumentError.value(term.value, 'term', 'Term must be positive');
    }
    return switch (term) {
      DayTerm(:final value) => start.addDays(value),
      MonthTerm(:final value) => start.addMonthsClamped(value),
      YearTerm(:final value) => start.addYearsClamped(value),
    };
  }
}
