// test/date_formatter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:handover/core/utils/date_formatter.dart';

void main() {
  group('AppDateFormatter - Normal Date Formatting', () {
    final eveningDate = DateTime(2026, 10, 16, 17, 0); // 16 Oct 2026, 5:00 PM
    final morningDate = DateTime(2026, 10, 14, 9, 12); // 14 Oct 2026, 9:12 AM
    final wednesdayDate = DateTime(
      2026,
      10,
      14,
      8,
      30,
    ); // Wednesday, 14 Oct 2026

    test('formatDateTime formats date and time with bullet separator', () {
      expect(
        AppDateFormatter.formatDateTime(eveningDate),
        '16 Oct 2026 • 5:00 PM',
      );
      expect(
        AppDateFormatter.formatDateTime(morningDate),
        '14 Oct 2026 • 9:12 AM',
      );
    });

    test('formatDateOnly formats date without time', () {
      expect(AppDateFormatter.formatDateOnly(eveningDate), '16 Oct 2026');
      expect(AppDateFormatter.formatDateOnly(morningDate), '14 Oct 2026');
    });

    test('formatShortDate formats day and month only', () {
      expect(AppDateFormatter.formatShortDate(eveningDate), '16 Oct');
      expect(AppDateFormatter.formatShortDate(morningDate), '14 Oct');
    });

    test('formatTimeOnly formats time with AM/PM', () {
      expect(AppDateFormatter.formatTimeOnly(eveningDate), '5:00 PM');
      expect(AppDateFormatter.formatTimeOnly(morningDate), '9:12 AM');
    });

    test('formatAtDateTime formats date with at and time', () {
      expect(
        AppDateFormatter.formatAtDateTime(DateTime(2026, 10, 15, 9, 0)),
        '15 Oct 2026 at 9:00 AM',
      );
    });

    test('formatHeaderDate formats day of week and month in uppercase', () {
      expect(
        AppDateFormatter.formatHeaderDate(wednesdayDate),
        'WEDNESDAY, 14 OCTOBER',
      );
    });
  });

  group('AppDateFormatter - Safe Null Handling (No Invented Values)', () {
    test('formatDateTime returns fallback on null', () {
      expect(AppDateFormatter.formatDateTime(null), '—');
      expect(
        AppDateFormatter.formatDateTime(null, fallback: 'Not set'),
        'Not set',
      );
    });

    test('formatDateOnly returns fallback on null', () {
      expect(AppDateFormatter.formatDateOnly(null), '—');
      expect(
        AppDateFormatter.formatDateOnly(null, fallback: 'No date'),
        'No date',
      );
    });

    test('formatShortDate returns fallback on null', () {
      expect(AppDateFormatter.formatShortDate(null), '—');
    });

    test('formatTimeOnly returns fallback on null', () {
      expect(AppDateFormatter.formatTimeOnly(null), '—');
    });

    test('formatAtDateTime returns fallback on null', () {
      expect(AppDateFormatter.formatAtDateTime(null), '—');
    });

    test('formatHeaderDate returns fallback on null', () {
      expect(AppDateFormatter.formatHeaderDate(null), '—');
    });

    test('formatOverdueDuration returns fallback on null', () {
      expect(AppDateFormatter.formatOverdueDuration(null), '');
      expect(
        AppDateFormatter.formatOverdueDuration(null, fallback: 'Unknown'),
        'Unknown',
      );
    });

    test('formatOverdueShort returns fallback on null', () {
      expect(AppDateFormatter.formatOverdueShort(null), '');
      expect(
        AppDateFormatter.formatOverdueShort(null, fallback: 'None'),
        'None',
      );
    });
  });

  group('AppDateFormatter - QR Expiry Calculation (createdAt + 24 Hours)', () {
    test('calculateQrExpiry returns exactly 24 hours after createdAt', () {
      final created = DateTime(2026, 10, 14, 9, 0);
      final expectedExpiry = DateTime(2026, 10, 15, 9, 0);

      final expiry = AppDateFormatter.calculateQrExpiry(created);
      expect(expiry, expectedExpiry);
    });

    test(
      'calculateQrExpiry returns null when createdAt is null (never invents timestamp)',
      () {
        expect(AppDateFormatter.calculateQrExpiry(null), isNull);
      },
    );

    test('formatQrExpiry formats calculated expiry timestamp', () {
      final created = DateTime(2026, 10, 14, 9, 0);
      expect(
        AppDateFormatter.formatQrExpiry(created),
        '15 Oct 2026 at 9:00 AM',
      );
    });

    test('formatQrExpiry returns fallback when createdAt is null', () {
      expect(AppDateFormatter.formatQrExpiry(null), '—');
      expect(
        AppDateFormatter.formatQrExpiry(null, fallback: 'Pending code'),
        'Pending code',
      );
    });
  });

  group('AppDateFormatter - Overdue Duration Calculation', () {
    final dueAt = DateTime(2026, 10, 16, 17, 0); // Due 16 Oct, 5:00 PM

    test('returns empty when current time is before or equal to due date', () {
      final before = DateTime(2026, 10, 16, 16, 0);
      final exactly = DateTime(2026, 10, 16, 17, 0);

      expect(AppDateFormatter.formatOverdueDuration(dueAt, now: before), '');
      expect(AppDateFormatter.formatOverdueDuration(dueAt, now: exactly), '');
    });

    test(
      'formats combined days and hours overdue (e.g. 1 day, 19 hours overdue)',
      () {
        // 1 day (24h) + 19 hours = 43 hours after due date
        final now = dueAt.add(const Duration(days: 1, hours: 19));
        expect(
          AppDateFormatter.formatOverdueDuration(dueAt, now: now),
          '1 day, 19 hours overdue',
        );
      },
    );

    test('formats plural and singular days overdue', () {
      final twoDaysLater = dueAt.add(const Duration(days: 2));
      final oneDayLater = dueAt.add(const Duration(days: 1));

      expect(
        AppDateFormatter.formatOverdueDuration(dueAt, now: twoDaysLater),
        '2 days overdue',
      );
      expect(
        AppDateFormatter.formatOverdueDuration(dueAt, now: oneDayLater),
        '1 day overdue',
      );
    });

    test('formats plural and singular hours overdue', () {
      final fiveHoursLater = dueAt.add(const Duration(hours: 5));
      final oneHourLater = dueAt.add(const Duration(hours: 1));

      expect(
        AppDateFormatter.formatOverdueDuration(dueAt, now: fiveHoursLater),
        '5 hours overdue',
      );
      expect(
        AppDateFormatter.formatOverdueDuration(dueAt, now: oneHourLater),
        '1 hour overdue',
      );
    });

    test('formats minutes overdue when under an hour', () {
      final fortyFiveMinutes = dueAt.add(const Duration(minutes: 45));
      final oneMinute = dueAt.add(const Duration(minutes: 1));

      expect(
        AppDateFormatter.formatOverdueDuration(dueAt, now: fortyFiveMinutes),
        '45 minutes overdue',
      );
      expect(
        AppDateFormatter.formatOverdueDuration(dueAt, now: oneMinute),
        '1 minute overdue',
      );
    });

    test('formatOverdueShort returns concise card labels', () {
      final twoDays = dueAt.add(const Duration(days: 2, hours: 4));
      final oneDay = dueAt.add(const Duration(days: 1));
      final threeHours = dueAt.add(const Duration(hours: 3));
      final twentyMins = dueAt.add(const Duration(minutes: 20));

      expect(
        AppDateFormatter.formatOverdueShort(dueAt, now: twoDays),
        '2 days overdue',
      );
      expect(
        AppDateFormatter.formatOverdueShort(dueAt, now: oneDay),
        '1 day overdue',
      );
      expect(
        AppDateFormatter.formatOverdueShort(dueAt, now: threeHours),
        '3 hours overdue',
      );
      expect(
        AppDateFormatter.formatOverdueShort(dueAt, now: twentyMins),
        '20 minutes overdue',
      );
    });
  });
}
