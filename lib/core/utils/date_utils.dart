/// Date / time helpers implementing the storage conventions of
/// docs/ARCHITECTURE-v0.1.md §9.6.
///
/// - **Storage**: every timestamp is a UTC ISO-8601 string.
/// - **Display**: timestamps are converted to the local zone and formatted.
/// - **Day boundaries**: streak, daily statistics and plan dates use the LOCAL
///   calendar date string `YYYY-MM-DD`.
library;

import 'package:intl/intl.dart';

/// Pure date/time utilities (no IO, safe to unit-test with a fixed clock).
abstract final class AppDateUtils {
  const AppDateUtils._();

  static final DateFormat _localDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _localDateTime = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _localTime = DateFormat('HH:mm');

  /// Converts [value] to a UTC ISO-8601 string for storage.
  static String toUtcIso(DateTime value) => value.toUtc().toIso8601String();

  /// The current instant as a UTC ISO-8601 string.
  static String nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  /// Parses a stored UTC ISO-8601 string back to a UTC [DateTime].
  ///
  /// Returns `null` when [value] is `null` or cannot be parsed.
  static DateTime? parseUtcIso(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed?.toUtc();
  }

  /// The LOCAL calendar date string `YYYY-MM-DD` for [value].
  static String localDateString(DateTime value) =>
      _localDate.format(value.toLocal());

  /// The LOCAL calendar date string for "now".
  static String todayLocalDateString() => localDateString(DateTime.now());

  /// Parses a `YYYY-MM-DD` local date string into a local midnight [DateTime].
  static DateTime parseLocalDate(String value) {
    final List<String> parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid local date string: $value');
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Formats a stored UTC timestamp for display in the device's local zone.
  static String formatLocal(
    DateTime utcValue, {
    String pattern = 'yyyy-MM-dd HH:mm',
  }) {
    final DateTime local = utcValue.toLocal();
    if (pattern == 'yyyy-MM-dd') {
      return _localDate.format(local);
    }
    if (pattern == 'HH:mm') {
      return _localTime.format(local);
    }
    return DateFormat(pattern).format(local);
  }

  /// Convenience: format the current instant as a local `yyyy-MM-dd HH:mm`.
  static String nowLocalDateTime() => _localDateTime.format(DateTime.now());

  /// Whole-day difference between two **local calendar dates** (to − from).
  ///
  /// The time-of-day component is dropped first, so the result is stable across
  /// daylight-saving transitions.
  static int daysBetweenLocalDates(DateTime from, DateTime to) {
    final DateTime a = DateTime(from.year, from.month, from.day);
    final DateTime b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Days from today (local) until [target], or `null` when [target] is null.
  static int? daysUntil(DateTime? target) {
    if (target == null) {
      return null;
    }
    return daysBetweenLocalDates(DateTime.now(), target);
  }

  /// Adds [days] to a `YYYY-MM-DD` local date string, returning the same format.
  static String addDaysToLocalDate(String dateString, int days) =>
      localDateString(parseLocalDate(dateString).add(Duration(days: days)));
}
