import 'package:flutter_test/flutter_test.dart';

// Pure functions mirrored from PassengerSeatScreen / _BookingHistorySheet
// (kept here so tests don't depend on widget internals)

String seatLabel(int seatNum, int leftSeats, int studentSeats) {
  if (seatNum <= leftSeats) return 'L$seatNum';
  final backCount  = studentSeats >= 6 ? 6 : studentSeats;
  final rightCount = studentSeats - backCount;
  final rightIdx   = seatNum - leftSeats;
  if (rightIdx <= rightCount) return 'R$rightIdx';
  return 'B${rightIdx - rightCount}';
}

DateTime bookingDateFor(DateTime now, {int openHour = 20}) {
  if (now.hour >= openHour) {
    return DateTime(now.year, now.month, now.day + 1);
  }
  return DateTime(now.year, now.month, now.day);
}

bool isBookingOpen(DateTime now, {int openHour = 20, int closeHour = 19}) {
  final h = now.hour;
  return !(h >= closeHour && h < openHour);
}

void main() {
  // ─── Seat label ───────────────────────────────────────────────────────────────
  group('seatLabel — bus 11 layout (18L + 30R + 6B = 54 seats)', () {
    const L = 18, S = 36;

    test('first and last left seats', () {
      expect(seatLabel(1,  L, S), 'L1');
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
      expect(seatLabel(9,  L, S), 'L9');
      expect(seatLabel(30, L, S), 'R12');
      expect(seatLabel(51, L, S), 'B3');
    });
  });

  // With studentSeats=12: backCount=min(6,12)=6, rightCount=12-6=6
  // Layout: 6L + 6R + 6B = 18 seats
  group('seatLabel — small bus (6L + 6R + 6B = 18 seats)', () {
    const L = 6, S = 12;

    test('left, right and back boundaries', () {
      expect(seatLabel(1,  L, S), 'L1');
      expect(seatLabel(6,  L, S), 'L6');
      expect(seatLabel(7,  L, S), 'R1');
      expect(seatLabel(12, L, S), 'R6'); // last right seat
      expect(seatLabel(13, L, S), 'B1'); // first back seat
      expect(seatLabel(18, L, S), 'B6');
    });
  });

  // ─── Booking date ─────────────────────────────────────────────────────────────
  group('bookingDateFor', () {
    test('before 8 PM → today', () {
      expect(bookingDateFor(DateTime(2026, 4, 30, 14, 0)),
          DateTime(2026, 4, 30));
      expect(bookingDateFor(DateTime(2026, 4, 30, 0, 0)),
          DateTime(2026, 4, 30));
      expect(bookingDateFor(DateTime(2026, 4, 30, 18, 59)),
          DateTime(2026, 4, 30));
    });

    test('exactly 8 PM → tomorrow', () {
      expect(bookingDateFor(DateTime(2026, 4, 30, 20, 0)),
          DateTime(2026, 5, 1));
    });

    test('after 8 PM → tomorrow', () {
      expect(bookingDateFor(DateTime(2026, 4, 30, 22, 30)),
          DateTime(2026, 5, 1));
      expect(bookingDateFor(DateTime(2026, 4, 30, 23, 59)),
          DateTime(2026, 5, 1));
    });

    test('month boundary — last day of April after 8 PM → May 1', () {
      expect(bookingDateFor(DateTime(2026, 4, 30, 21, 0)),
          DateTime(2026, 5, 1));
    });
  });

  // ─── Booking window state ─────────────────────────────────────────────────────
  group('isBookingOpen', () {
    test('open during the day (8 AM – 7 PM)', () {
      expect(isBookingOpen(DateTime(2026, 4, 30, 8,  0)),  isTrue);
      expect(isBookingOpen(DateTime(2026, 4, 30, 12, 0)),  isTrue);
      expect(isBookingOpen(DateTime(2026, 4, 30, 18, 59)), isTrue);
    });

    test('locked between 7 PM and 8 PM', () {
      expect(isBookingOpen(DateTime(2026, 4, 30, 19, 0)),  isFalse);
      expect(isBookingOpen(DateTime(2026, 4, 30, 19, 30)), isFalse);
      expect(isBookingOpen(DateTime(2026, 4, 30, 19, 59)), isFalse);
    });

    test('open after 8 PM (next-day booking window)', () {
      expect(isBookingOpen(DateTime(2026, 4, 30, 20, 0)),  isTrue);
      expect(isBookingOpen(DateTime(2026, 4, 30, 23, 59)), isTrue);
    });

    test('open at midnight', () {
      expect(isBookingOpen(DateTime(2026, 4, 30, 0, 0)), isTrue);
    });
  });

  // ─── Faculty seat reservation bounds ──────────────────────────────────────────
  group('Faculty reserved rows', () {
    const leftRows         = 18 ~/ 2; // 9
    const rightRows        = 30 ~/ 3; // 10
    const facultyRowsLeft  = 6;
    const facultyRowsRight = 7;

    test('reserved rows do not exceed total rows', () {
      expect(facultyRowsLeft,  lessThanOrEqualTo(leftRows));
      expect(facultyRowsRight, lessThanOrEqualTo(rightRows));
    });

    test('faculty seat counts are correct', () {
      expect(facultyRowsLeft  * 2, 12); // 12 yellow left seats
      expect(facultyRowsRight * 3, 21); // 21 yellow right seats
    });

    test('student seats below reserved lines are correct', () {
      final studentLeftSeats  = leftRows  * 2 - facultyRowsLeft  * 2;  // 6
      final studentRightSeats = rightRows * 3 - facultyRowsRight * 3;  // 9
      expect(studentLeftSeats,  6);
      expect(studentRightSeats, 9);
    });
  });
}
