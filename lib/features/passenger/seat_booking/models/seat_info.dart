enum SeatType { faculty, student }

enum BookingState { open, locked }

class SeatInfo {
  final int number;
  final String label;
  final SeatType type;
  String? bookedBy;
  bool isMyBooking = false;
  bool isReserved = false; // permanently reserved for someone

  SeatInfo({
    required this.number,
    required this.label,
    required this.type,
  });
}

/// Human label for a seat number given the bus layout: left column
/// (2-across) first, then right column (3-across), then the back bench.
String seatLabel(int seatNum, int leftSeats, int studentSeats) {
  if (seatNum <= leftSeats) return 'L$seatNum';
  final backCount = studentSeats >= 6 ? 6 : studentSeats;
  final rightCount = studentSeats - backCount;
  final rightIdx = seatNum - leftSeats;
  if (rightIdx <= rightCount) return 'R$rightIdx';
  return 'B${rightIdx - rightCount}';
}
