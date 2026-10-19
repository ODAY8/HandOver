// lib/core/utils/date_formatter.dart

import 'package:intl/intl.dart';

/// Reusable utility for formatting dates, timestamps, durations, and QR code expirations.
/// Follows the visual design conventions from the HandOver Figma specifications.
class AppDateFormatter {
  const AppDateFormatter._();

  static final DateFormat _dateTimeFormat = DateFormat(
    'd MMM yyyy • h:mm a',
    'en_US',
  );
  static final DateFormat _dateOnlyFormat = DateFormat('d MMM yyyy', 'en_US');
  static final DateFormat _shortDateFormat = DateFormat('d MMM', 'en_US');
  static final DateFormat _timeOnlyFormat = DateFormat('h:mm a', 'en_US');
  static final DateFormat _atDateFormat = DateFormat('d MMM yyyy', 'en_US');
  static final DateFormat _headerDateFormat = DateFormat(
    'EEEE, d MMMM',
    'en_US',
  );

  /// Formats date and time: e.g. "16 Oct 2026 • 5:00 PM"
  /// Safe null handling: returns [fallback] if [dateTime] is null.
  static String formatDateTime(DateTime? dateTime, {String fallback = '—'}) {
    if (dateTime == null) return fallback;
    return _dateTimeFormat.format(dateTime.toLocal());
  }

  /// Formats date only: e.g. "16 Oct 2026"
  /// Safe null handling: returns [fallback] if [dateTime] is null.
  static String formatDateOnly(DateTime? dateTime, {String fallback = '—'}) {
    if (dateTime == null) return fallback;
    return _dateOnlyFormat.format(dateTime.toLocal());
  }

  /// Formats short date: e.g. "16 Oct"
  /// Safe null handling: returns [fallback] if [dateTime] is null.
  static String formatShortDate(DateTime? dateTime, {String fallback = '—'}) {
    if (dateTime == null) return fallback;
    return _shortDateFormat.format(dateTime.toLocal());
  }

  /// Formats time only: e.g. "5:00 PM" or "9:12 AM"
  /// Safe null handling: returns [fallback] if [dateTime] is null.
  static String formatTimeOnly(DateTime? dateTime, {String fallback = '—'}) {
    if (dateTime == null) return fallback;
    return _timeOnlyFormat.format(dateTime.toLocal());
  }

  /// Formats date with "at": e.g. "15 Oct 2026 at 9:00 AM"
  /// Safe null handling: returns [fallback] if [dateTime] is null.
  static String formatAtDateTime(DateTime? dateTime, {String fallback = '—'}) {
    if (dateTime == null) return fallback;
    final local = dateTime.toLocal();
    return '${_atDateFormat.format(local)} at ${_timeOnlyFormat.format(local)}';
  }

  /// Formats top dashboard header date: e.g. "WEDNESDAY, 14 OCTOBER"
  /// Safe null handling: returns [fallback] if [dateTime] is null.
  static String formatHeaderDate(DateTime? dateTime, {String fallback = '—'}) {
    if (dateTime == null) return fallback;
    return _headerDateFormat.format(dateTime.toLocal()).toUpperCase();
  }

  /// Calculates QR code expiry timestamp: strictly 24 hours after creation.
  /// If [createdAt] is null, returns null (never invents missing historical timestamps).
  static DateTime? calculateQrExpiry(DateTime? createdAt) {
    if (createdAt == null) return null;
    return createdAt.add(const Duration(hours: 24));
  }

  /// Formats QR code expiry string: e.g. "15 Oct 2026 at 9:00 AM"
  /// Safe null handling: returns [fallback] if [createdAt] is null.
  static String formatQrExpiry(DateTime? createdAt, {String fallback = '—'}) {
    final expiry = calculateQrExpiry(createdAt);
    if (expiry == null) return fallback;
    return formatAtDateTime(expiry);
  }

  /// Formats the overdue duration between [dueAt] and [now].
  ///
  /// Examples:
  /// - "1 day, 19 hours overdue"
  /// - "2 days overdue"
  /// - "1 day overdue"
  /// - "5 hours overdue"
  /// - "1 hour overdue"
  /// - "45 minutes overdue"
  /// - "1 minute overdue"
  ///
  /// Safe null handling: returns [fallback] if [dueAt] is null.
  /// If the item is not yet overdue, returns [notOverdueFallback] (default: empty string).
  static String formatOverdueDuration(
    DateTime? dueAt, {
    DateTime? now,
    String fallback = '',
    String notOverdueFallback = '',
  }) {
    if (dueAt == null) return fallback;
    final reference = now ?? DateTime.now();
    if (!reference.isAfter(dueAt)) {
      return notOverdueFallback;
    }

    final diff = reference.difference(dueAt);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    if (days > 0) {
      final daysPart = '$days ${days == 1 ? "day" : "days"}';
      if (hours > 0) {
        final hoursPart = '$hours ${hours == 1 ? "hour" : "hours"}';
        return '$daysPart, $hoursPart overdue';
      }
      return '$daysPart overdue';
    }

    if (diff.inHours > 0) {
      final totalHours = diff.inHours;
      return '$totalHours ${totalHours == 1 ? "hour" : "hours"} overdue';
    }

    if (minutes > 0) {
      return '$minutes ${minutes == 1 ? "minute" : "minutes"} overdue';
    }

    return 'Just overdue';
  }

  /// Concise overdue label for cards: e.g. "2 days overdue" or "5 hours overdue"
  static String formatOverdueShort(
    DateTime? dueAt, {
    DateTime? now,
    String fallback = '',
  }) {
    if (dueAt == null) return fallback;
    final reference = now ?? DateTime.now();
    if (!reference.isAfter(dueAt)) return fallback;

    final diff = reference.difference(dueAt);
    if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? "day" : "days"} overdue';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"} overdue';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? "minute" : "minutes"} overdue';
    }
    return 'Overdue';
  }
}
