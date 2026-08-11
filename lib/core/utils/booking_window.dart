/// Booking-window rules for daily seat reservations, shared by the seat
/// screen, its countdown status bar, and tests.
///
/// The window opens at [openHour] (8 PM) for the *following* day's trip and
/// locks at [closeHour] (7 PM) on the day of the trip itself.
class BookingWindow {
  static const int openHour = 20; // 8 PM — opens for next day
  static const int closeHour = 19; // 7 PM — locks for current day

  /// Whether the booking window is currently open (selection allowed).
  static bool isOpen(DateTime now) {
    final h = now.hour;
    return !(h >= closeHour && h < openHour);
  }

  /// The trip date a booking made at [now] applies to: today before 8 PM,
  /// otherwise tomorrow.
  static DateTime bookingDateFor(DateTime now) {
    if (now.hour >= openHour) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    return DateTime(now.year, now.month, now.day);
  }

  /// Time remaining until the window next opens or closes.
  static Duration timeUntilNextEvent(DateTime now) {
    final h = now.hour;
    final DateTime target;
    if (h >= closeHour && h < openHour) {
      target = DateTime(now.year, now.month, now.day, openHour);
    } else if (h < closeHour) {
      target = DateTime(now.year, now.month, now.day, closeHour);
    } else {
      target = DateTime(now.year, now.month, now.day + 1, closeHour);
    }
    return target.difference(now);
  }
}
