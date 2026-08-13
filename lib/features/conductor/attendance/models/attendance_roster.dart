// Attendance state machine for a conductor trip.
//
// The transition rules here are the single source of truth for how records
// move between states. [AttendanceRepository] applies the identical rules in
// SQL (markPresent / markStopWaitingMissing / endTrip), the screen applies
// them locally for optimistic updates between database reloads, and the
// tests verify them.
//
// Pure Dart — no Flutter imports — so it can be unit-tested directly.

/// Lifecycle states for a passenger's attendance record; the same names are
/// stored in the `attendance.state` column.
enum AttendanceState { waiting, present, missing, absent }

extension AttendanceStateX on AttendanceState {
  /// Parses a DB state string; unknown values fall back to [AttendanceState.waiting].
  static AttendanceState fromName(String name) => switch (name) {
        'present' => AttendanceState.present,
        'missing' => AttendanceState.missing,
        'absent' => AttendanceState.absent,
        _ => AttendanceState.waiting,
      };
}

/// One passenger's attendance record for a trip, joined with their boarding
/// stop. Mirrors a row of the `attendance` table.
class AttendanceEntry {
  final String id;
  final String passengerId;
  final String name;
  final String stopId;
  final String stopName;
  final int stopOrder;
  AttendanceState state;
  DateTime? scannedAt;

  AttendanceEntry({
    required this.id,
    required this.passengerId,
    required this.name,
    required this.stopId,
    required this.stopName,
    required this.stopOrder,
    required this.state,
    this.scannedAt,
  });
}

class AttendanceMachine {
  AttendanceMachine._();

  /// Initial state when the trip's roster is created: passengers with a seat
  /// booking for today are waiting to board; everyone else starts absent.
  static AttendanceState initialState({required bool hasSeatBooking}) =>
      hasSeatBooking ? AttendanceState.waiting : AttendanceState.absent;

  /// Mirrors AttendanceRepository.markPresent — overwrites unconditionally,
  /// even when the passenger was previously marked missing at a passed stop,
  /// and always stamps [scannedAt]. Returns false when no record matches.
  static bool markPresent(
    List<AttendanceEntry> entries,
    String attendanceId, {
    DateTime? scannedAt,
  }) {
    for (final e in entries) {
      if (e.id == attendanceId) {
        e.state = AttendanceState.present;
        e.scannedAt = scannedAt ?? DateTime.now();
        return true;
      }
    }
    return false;
  }

  /// Waiting passengers at a stop the bus has passed become missing.
  /// Present / missing / absent records are left untouched.
  /// Returns how many records changed.
  static int markStopWaitingMissing(
      List<AttendanceEntry> entries, String stopId) {
    var changed = 0;
    for (final e in entries) {
      if (e.stopId == stopId && e.state == AttendanceState.waiting) {
        e.state = AttendanceState.missing;
        changed++;
      }
    }
    return changed;
  }

  /// End of trip: everyone still waiting is marked absent.
  /// Returns how many records changed.
  static int markRemainingAbsent(List<AttendanceEntry> entries) {
    var changed = 0;
    for (final e in entries) {
      if (e.state == AttendanceState.waiting) {
        e.state = AttendanceState.absent;
        changed++;
      }
    }
    return changed;
  }

  /// Per-state counts, including the grand total.
  static Map<String, int> stats(List<AttendanceEntry> entries) => {
        'total': entries.length,
        'present':
            entries.where((e) => e.state == AttendanceState.present).length,
        'missing':
            entries.where((e) => e.state == AttendanceState.missing).length,
        'absent':
            entries.where((e) => e.state == AttendanceState.absent).length,
        'waiting':
            entries.where((e) => e.state == AttendanceState.waiting).length,
      };

  /// List ordering used by the attendance screen: the current stop's
  /// passengers first, then every other stop in route order.
  static void sortByCurrentStop(
      List<AttendanceEntry> entries, int currentStopOrder) {
    entries.sort((a, b) {
      if (a.stopOrder == currentStopOrder &&
          b.stopOrder != currentStopOrder) {
        return -1;
      }
      if (a.stopOrder != currentStopOrder &&
          b.stopOrder == currentStopOrder) {
        return 1;
      }
      return a.stopOrder.compareTo(b.stopOrder);
    });
  }
}
