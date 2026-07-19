final class LocalDate implements Comparable<LocalDate> {
  factory LocalDate(int year, int month, int day) {
    final candidate = DateTime.utc(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      throw ArgumentError.value(
        '$year-$month-$day',
        'date',
        'Must be a valid calendar date',
      );
    }
    return LocalDate._(year, month, day);
  }

  const LocalDate._(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  LocalDate addDays(int days) {
    final result = _asDateTime.add(Duration(days: days));
    return LocalDate(result.year, result.month, result.day);
  }

  LocalDate addMonthsClamped(int months) {
    final zeroBasedMonth = year * 12 + month - 1 + months;
    final targetYear = zeroBasedMonth ~/ 12;
    final targetMonth = zeroBasedMonth % 12 + 1;
    final targetDay = day.clamp(1, _daysInMonth(targetYear, targetMonth));
    return LocalDate(targetYear, targetMonth, targetDay);
  }

  LocalDate addYearsClamped(int years) {
    final targetYear = year + years;
    final targetDay = day.clamp(1, _daysInMonth(targetYear, month));
    return LocalDate(targetYear, month, targetDay);
  }

  bool isBefore(LocalDate other) => compareTo(other) < 0;

  bool isAfter(LocalDate other) => compareTo(other) > 0;

  bool isWithinMondayToSundayOf(LocalDate reference) {
    final monday = reference.addDays(1 - reference._asDateTime.weekday);
    final sunday = monday.addDays(6);
    return !isBefore(monday) && !isAfter(sunday);
  }

  @override
  int compareTo(LocalDate other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) return yearComparison;
    final monthComparison = month.compareTo(other.month);
    if (monthComparison != 0) return monthComparison;
    return day.compareTo(other.day);
  }

  DateTime get _asDateTime => DateTime.utc(year, month, day);

  static int _daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDate &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
