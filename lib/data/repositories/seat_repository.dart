import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/supabase_constants.dart';
import '../../main.dart';

part 'seat_repository.g.dart';

@riverpod
SeatRepository seatRepository(Ref ref) => SeatRepository();

/// Data access for the daily seat-booking screen.
class SeatRepository {
  // Live-prototype seat state: the current visitor's booking is held in memory
  // (keyed by booking date) so it survives reloads of the screen within the
  // session, but is never written to the backend.
  static final Map<String, int> _demoMyBooking = {};

  // Demo "other people" so the bus looks lived-in. Faculty take yellow seats,
  // students take red ones. Names show when a taken seat is tapped.
  static const _demoFacultyNames = ['Dr. Mehta', 'Prof. Iyer'];
  static const _demoStudentNames = [
    'Aarav S.', 'Diya P.', 'Kabir R.', 'Ananya V.', 'Rohan M.',
    'Isha K.', 'Vihaan T.', 'Sara N.',
  ];

  /// The passenger's bus, user type and seat layout.
  Future<Map<String, dynamic>> seatBusInfo() async {
    final userId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from(SupabaseConstants.passengers)
        .select(
          'bus_id, user_type, '
          'buses(bus_number, left_seats, student_seats, '
          'faculty_reserved_rows_left, faculty_reserved_rows_right)',
        )
        .eq('id', userId)
        .single();
    final map = Map<String, dynamic>.from(profile);

    // In the demo, guarantee at least one faculty row each side so the layout
    // shows both yellow (faculty) and red (student) seats.
    if (AppConfig.demoMode) {
      final bus = Map<String, dynamic>.from(map['buses'] as Map);
      if (((bus['faculty_reserved_rows_left'] as num?) ?? 0) == 0) {
        bus['faculty_reserved_rows_left'] = 1;
      }
      if (((bus['faculty_reserved_rows_right'] as num?) ?? 0) == 0) {
        bus['faculty_reserved_rows_right'] = 1;
      }
      map['buses'] = bus;
    }
    return map;
  }

  /// All seat bookings on a bus for a given date, with booker names.
  Future<List<Map<String, dynamic>>> bookingsForDate(
      String busId, String dateStr) async {
    if (AppConfig.demoMode) return _demoBookings(busId, dateStr);
    final data = await supabase
        .from(SupabaseConstants.seatBookings)
        .select('seat_number, passenger_id, passengers(name)')
        .eq('bus_id', busId)
        .eq('booking_date', dateStr);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Builds the demo's prefilled "taken" seats plus the visitor's own booking.
  Future<List<Map<String, dynamic>>> _demoBookings(
      String busId, String dateStr) async {
    final bus = await supabase
        .from(SupabaseConstants.buses)
        .select('left_seats, student_seats, '
            'faculty_reserved_rows_left, faculty_reserved_rows_right')
        .eq('id', busId)
        .single();

    final leftSeats = (bus['left_seats'] as num).toInt();
    final studentSeats = (bus['student_seats'] as num).toInt();
    // Mirror seatBusInfo's demo guarantee of at least one faculty row each side.
    final facultyRowsLeft =
        max(1, ((bus['faculty_reserved_rows_left'] as num?) ?? 0).toInt());
    final facultyRowsRight =
        max(1, ((bus['faculty_reserved_rows_right'] as num?) ?? 0).toInt());

    // Reconstruct the same seat-number zones the screen lays out.
    final facultyLeftSeats = facultyRowsLeft * 2;
    final backCount = min(6, studentSeats);
    final rightCount = studentSeats - backCount;
    final facultyRightSeats = facultyRowsRight * 3;

    final facultyNumbers = <int>[];
    for (int i = 1; i <= facultyLeftSeats; i++) {
      facultyNumbers.add(i);
    }
    for (int i = 1; i <= facultyRightSeats; i++) {
      facultyNumbers.add(leftSeats + i);
    }

    final studentNumbers = <int>[];
    for (int i = facultyLeftSeats + 1; i <= leftSeats; i++) {
      studentNumbers.add(i);
    }
    for (int i = facultyRightSeats + 1; i <= rightCount; i++) {
      studentNumbers.add(leftSeats + i);
    }
    for (int i = 1; i <= backCount; i++) {
      studentNumbers.add(leftSeats + rightCount + i);
    }

    final result = <Map<String, dynamic>>[];

    // A couple of faculty seats taken.
    for (int i = 0; i < _demoFacultyNames.length && i < facultyNumbers.length; i++) {
      result.add({
        'seat_number': facultyNumbers[i],
        'passenger_id': 'demo-faculty-$i',
        'passengers': {'name': _demoFacultyNames[i]},
      });
    }

    // A spread of student seats taken (every 3rd seat).
    var nameIdx = 0;
    for (int j = 0;
        j < studentNumbers.length && nameIdx < _demoStudentNames.length;
        j += 3) {
      result.add({
        'seat_number': studentNumbers[j],
        'passenger_id': 'demo-student-$nameIdx',
        'passengers': {'name': _demoStudentNames[nameIdx]},
      });
      nameIdx++;
    }

    // The visitor's own session booking, if any.
    final mine = _demoMyBooking[dateStr];
    if (mine != null) {
      // Don't collide with a prefilled seat.
      result.removeWhere((b) => b['seat_number'] == mine);
      result.add({
        'seat_number': mine,
        'passenger_id': currentUserId,
        'passengers': {'name': 'You'},
      });
    }
    return result;
  }

  /// Clears the current passenger's booking for a date.
  Future<void> clearMyBooking(String dateStr) async {
    if (AppConfig.demoMode) {
      _demoMyBooking.remove(dateStr);
      return;
    }
    final userId = supabase.auth.currentUser!.id;
    await supabase
        .from(SupabaseConstants.seatBookings)
        .delete()
        .eq('passenger_id', userId)
        .eq('booking_date', dateStr);
  }

  /// Books a seat for the current passenger. Throws a PostgrestException with
  /// code 23505 if the seat was taken concurrently.
  Future<void> bookSeat({
    required String busId,
    required int seatNumber,
    required String dateStr,
  }) async {
    if (AppConfig.demoMode) {
      _demoMyBooking[dateStr] = seatNumber; // persists for the session
      return;
    }
    final userId = supabase.auth.currentUser!.id;
    await supabase.from(SupabaseConstants.seatBookings).insert({
      'bus_id': busId,
      'passenger_id': userId,
      'seat_number': seatNumber,
      'booking_date': dateStr,
    });
  }

  String get currentUserId => supabase.auth.currentUser!.id;
}
