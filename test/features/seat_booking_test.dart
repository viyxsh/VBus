import 'package:flutter_test/flutter_test.dart';

import 'package:vbusf/core/utils/booking_window.dart';
import 'package:vbusf/features/passenger/seat_booking/models/seat_info.dart';

void main() {
  // ─── Seat label ───────────────────────────────────────────────────────────────
  group('seatLabel — bus 11 layout (18L + 30R + 6B = 54 seats)', () {
    const L = 18, S = 36;

    test('first and last left seats', () {
      expect(seatLabel(1, L, S), 'L1');
      expect(seatLabel(18, L, S), 'L18');
    });

    test('first and last right seats', () {
      expect(seatLabel(19, L, S), 'R1');
      expect(seatLabel(48, L, S), 'R30');
    });

    test('all six back seats', () {
      expect(seatLabel(49, L, S), 'B1');
      expect(seatLabel(50, L, S), 'B2');
      expect(seatLabel(51, L, S), 'B3');
      expect(seatLabel(52, L, S), 'B4');
      expect(seatLabel(53, L, S), 'B5');
      expect(seatLabel(54, L, S), 'B6');
    });

    test('mid-range left, right and back', () {
      expect(seatLabel(9, L, S), 'L9');
      expect(seatLabel(30, L, S), 'R12');
      expect(seatLabel(51, L, S), 'B3');
    });
  });

  // With studentSeats=12: backCount=min(6,12)=6, rightCount=12-6=6
  // Layout: 6L + 6R + 6B = 18 seats
  group('seatLabel — small bus (6L + 6R + 6B = 18 seats)', () {
    const L = 6, S = 12;

    test('left, right and back boundaries', () {
      expect(seatLabel(1, L, S), 'L1');
      expect(seatLabel(6, L, S), 'L6');
      expect(seatLabel(7, L, S), 'R1');
      expect(seatLabel(12, L, S), 'R6'); // last right seat
      expect(seatLabel(13, L, S), 'B1'); // first back seat
      expect(seatLabel(18, L, S), 'B6');
    });
  });

  // ─── Booking date ─────────────────────────────────────────────────────────────
  group('bookingDateFor', () {
    test('before 8 PM → today', () {
      expect(
        BookingWindow.bookingDateFor(DateTime(2026, 4, 30, 14, 0)),
        DateTime(2026, 4, 30),
      );
      expect(
        BookingWindow.bookingDateFor(DateTime(2026, 4, 30, 0, 0)),
        DateTime(2026, 4, 30),
      );
      expect(
        BookingWindow.bookingDateFor(DateTime(2026, 4, 30, 18, 59)),
        DateTime(2026, 4, 30),
      );
    });

    test('exactly 8 PM → tomorrow', () {
      expect(
        BookingWindow.bookingDateFor(DateTime(2026, 4, 30, 20, 0)),
        DateTime(2026, 5, 1),
      );
    });

    test('after 8 PM → tomorrow', () {
      expect(
        BookingWindow.bookingDateFor(DateTime(2026, 4, 30, 22, 30)),
        DateTime(2026, 5, 1),
      );
      expect(
        BookingWindow.bookingDateFor(DateTime(2026, 4, 30, 23, 59)),
        DateTime(2026, 5, 1),
      );
    });

    test('month boundary — last day of April after 8 PM → May 1', () {
      expect(
        BookingWindow.bookingDateFor(DateTime(2026, 4, 30, 21, 0)),
        DateTime(2026, 5, 1),
      );
    });
  });

  // ─── Booking window state ─────────────────────────────────────────────────────
  group('isBookingOpen', () {
    test('open during the day (8 AM – 7 PM)', () {
      expect(BookingWindow.isOpen(DateTime(2026, 4, 30, 8, 0)), isTrue);
      expect(BookingWindow.isOpen(DateTime(2026, 4, 30, 12, 0)), isTrue);
      expect(BookingWindow.isOpen(DateTime(2026, 4, 30, 18, 59)), isTrue);
    });

    test('locked between 7 PM and 8 PM', () {
      expect(BookingWindow.isOpen(DateTime(2026, 4, 30, 19, 0)), isFalse);
      expect(BookingWindow.isOpen(DateTime(2026, 4, 30, 19, 30)), isFalse);
      expect(BookingWindow.isOpen(DateTime(2026, 4, 30, 19, 59)), isFalse);
    });

    test('open after 8 PM (next-day booking window)', () {
      expect(BookingWindow.isOpen(DateTime(2026, 4, 30, 20, 0)), isTrue);
      expect(BookingWindow.isOpen(DateTime(2026, 4, 30, 23, 59)), isTrue);
    });

    test('open at midnight', () {
      expect(BookingWindow.isOpen(DateTime(2026, 4, 30, 0, 0)), isTrue);
    });
  });
}
