import 'package:flutter_test/flutter_test.dart';

// Mirrors the attendance state machine from conductor_attendance_screen.dart

enum AttendanceState { waiting, present, missing, absent }

class MockAttendance {
  final String passengerId;
  final int stopOrder;
  AttendanceState state;
  DateTime? scannedAt;

  MockAttendance({
    required this.passengerId,
    required this.stopOrder,
    this.state = AttendanceState.waiting,
    this.scannedAt,
  });
}

// Simulates "Next Stop" — marks all waiting passengers at the current stop as missing
List<MockAttendance> advanceStop(
    List<MockAttendance> attendances, int currentStopOrder) {
  return attendances.map((a) {
    if (a.state == AttendanceState.waiting &&
        a.stopOrder == currentStopOrder) {
      return MockAttendance(
        passengerId: a.passengerId,
        stopOrder: a.stopOrder,
        state: AttendanceState.missing,
      );
    }
    return a;
  }).toList();
}

// Simulates "End Trip" — marks all remaining waiting passengers as absent
List<MockAttendance> endTrip(List<MockAttendance> attendances) {
  return attendances.map((a) {
    if (a.state == AttendanceState.waiting) {
      return MockAttendance(
        passengerId: a.passengerId,
        stopOrder: a.stopOrder,
        state: AttendanceState.absent,
      );
    }
    return a;
  }).toList();
}

// Simulates scanning an ID — marks the matching passenger as present
List<MockAttendance> scanPassenger(
    List<MockAttendance> attendances, String passengerId) {
  return attendances.map((a) {
    if (a.passengerId == passengerId &&
        a.state == AttendanceState.waiting) {
      return MockAttendance(
        passengerId: a.passengerId,
        stopOrder: a.stopOrder,
        state: AttendanceState.present,
        scannedAt: DateTime.now(),
      );
    }
    return a;
  }).toList();
}

void main() {
  // ─── Initial state ────────────────────────────────────────────────────────────
  group('Initial attendance state', () {
    test('all passengers start as waiting', () {
      final list = [
        MockAttendance(passengerId: 'p1', stopOrder: 1),
        MockAttendance(passengerId: 'p2', stopOrder: 2),
        MockAttendance(passengerId: 'p3', stopOrder: 3),
      ];
      expect(list.every((a) => a.state == AttendanceState.waiting), isTrue);
    });
  });

  // ─── Scan (mark present) ──────────────────────────────────────────────────────
  group('Scan passenger', () {
    late List<MockAttendance> list;
    setUp(() => list = [
          MockAttendance(passengerId: 'p1', stopOrder: 1),
          MockAttendance(passengerId: 'p2', stopOrder: 1),
          MockAttendance(passengerId: 'p3', stopOrder: 2),
        ]);

    test('marks scanned passenger as present', () {
      final updated = scanPassenger(list, 'p1');
      expect(updated.firstWhere((a) => a.passengerId == 'p1').state,
          AttendanceState.present);
    });

    test('does not affect other passengers', () {
      final updated = scanPassenger(list, 'p1');
      expect(updated.firstWhere((a) => a.passengerId == 'p2').state,
          AttendanceState.waiting);
      expect(updated.firstWhere((a) => a.passengerId == 'p3').state,
          AttendanceState.waiting);
    });

    test('scanning an already-present passenger does nothing', () {
      var updated = scanPassenger(list, 'p1');
      final firstScan = updated.firstWhere((a) => a.passengerId == 'p1').scannedAt;
      updated = scanPassenger(updated, 'p1');
      // state remains present, scannedAt unchanged
      final a = updated.firstWhere((a) => a.passengerId == 'p1');
      expect(a.state, AttendanceState.present);
      expect(a.scannedAt, firstScan);
    });
  });

  // ─── Advance stop ─────────────────────────────────────────────────────────────
  group('advanceStop', () {
    late List<MockAttendance> list;
    setUp(() => list = [
          MockAttendance(passengerId: 'p1', stopOrder: 1),
          MockAttendance(passengerId: 'p2', stopOrder: 1),
          MockAttendance(passengerId: 'p3', stopOrder: 2),
          MockAttendance(passengerId: 'p4', stopOrder: 3),
        ]);

    test('marks waiting passengers at current stop as missing', () {
      final updated = advanceStop(list, 1);
      expect(updated.firstWhere((a) => a.passengerId == 'p1').state,
          AttendanceState.missing);
      expect(updated.firstWhere((a) => a.passengerId == 'p2').state,
          AttendanceState.missing);
    });

    test('does not affect passengers at other stops', () {
      final updated = advanceStop(list, 1);
      expect(updated.firstWhere((a) => a.passengerId == 'p3').state,
          AttendanceState.waiting);
      expect(updated.firstWhere((a) => a.passengerId == 'p4').state,
          AttendanceState.waiting);
    });

    test('does not change already-present passengers', () {
      var updated = scanPassenger(list, 'p1');
      updated = advanceStop(updated, 1);
      // p1 was scanned, stays present
      expect(updated.firstWhere((a) => a.passengerId == 'p1').state,
          AttendanceState.present);
      // p2 was not scanned, becomes missing
      expect(updated.firstWhere((a) => a.passengerId == 'p2').state,
          AttendanceState.missing);
    });
  });

  // ─── End trip ─────────────────────────────────────────────────────────────────
  group('endTrip', () {
    test('marks all remaining waiting passengers as absent', () {
      final list = [
        MockAttendance(passengerId: 'p1', stopOrder: 1,
            state: AttendanceState.present),
        MockAttendance(passengerId: 'p2', stopOrder: 2,
            state: AttendanceState.missing),
        MockAttendance(passengerId: 'p3', stopOrder: 3),
        MockAttendance(passengerId: 'p4', stopOrder: 4),
      ];
      final ended = endTrip(list);
      expect(ended.firstWhere((a) => a.passengerId == 'p1').state,
          AttendanceState.present);  // unchanged
      expect(ended.firstWhere((a) => a.passengerId == 'p2').state,
          AttendanceState.missing);  // unchanged
      expect(ended.firstWhere((a) => a.passengerId == 'p3').state,
          AttendanceState.absent);   // was waiting
      expect(ended.firstWhere((a) => a.passengerId == 'p4').state,
          AttendanceState.absent);   // was waiting
    });

    test('all present at end of perfect trip', () {
      var list = [
        MockAttendance(passengerId: 'p1', stopOrder: 1),
        MockAttendance(passengerId: 'p2', stopOrder: 2),
      ];
      list = scanPassenger(list, 'p1');
      list = scanPassenger(list, 'p2');
      final ended = endTrip(list);
      expect(ended.every((a) => a.state == AttendanceState.present), isTrue);
    });
  });

  // ─── Stats computation ────────────────────────────────────────────────────────
  group('Attendance stats', () {
    Map<String, int> stats(List<MockAttendance> list) => {
          'total':   list.length,
          'present': list.where((a) => a.state == AttendanceState.present).length,
          'missing': list.where((a) => a.state == AttendanceState.missing).length,
          'absent':  list.where((a) => a.state == AttendanceState.absent).length,
          'waiting': list.where((a) => a.state == AttendanceState.waiting).length,
        };

    test('initial stats — all waiting', () {
      final s = stats([
        MockAttendance(passengerId: 'p1', stopOrder: 1),
        MockAttendance(passengerId: 'p2', stopOrder: 1),
        MockAttendance(passengerId: 'p3', stopOrder: 2),
      ]);
      expect(s['total'],   3);
      expect(s['waiting'], 3);
      expect(s['present'], 0);
      expect(s['missing'], 0);
      expect(s['absent'],  0);
    });

    test('stats after mixed scenario', () {
      var list = [
        MockAttendance(passengerId: 'p1', stopOrder: 1),
        MockAttendance(passengerId: 'p2', stopOrder: 1),
        MockAttendance(passengerId: 'p3', stopOrder: 2),
        MockAttendance(passengerId: 'p4', stopOrder: 2),
      ];
      list = scanPassenger(list, 'p1');       // p1 → present
      list = advanceStop(list, 1);            // p2 → missing
      list = scanPassenger(list, 'p3');       // p3 → present
      final s = stats(list);
      expect(s['present'], 2); // p1, p3
      expect(s['missing'], 1); // p2
      expect(s['waiting'], 1); // p4
      expect(s['absent'],  0);
    });

    test('totals are consistent', () {
      final list = [
        MockAttendance(passengerId: 'p1', stopOrder: 1,
            state: AttendanceState.present),
        MockAttendance(passengerId: 'p2', stopOrder: 1,
            state: AttendanceState.missing),
        MockAttendance(passengerId: 'p3', stopOrder: 2,
            state: AttendanceState.absent),
        MockAttendance(passengerId: 'p4', stopOrder: 2),
      ];
      final s = stats(list);
      expect(
        s['present']! + s['missing']! + s['absent']! + s['waiting']!,
        s['total'],
      );
    });
  });

  // ─── Sort order ───────────────────────────────────────────────────────────────
  group('Passenger list sort order', () {
    test('current stop passengers appear first', () {
      final list = [
        MockAttendance(passengerId: 'p_future', stopOrder: 3),
        MockAttendance(passengerId: 'p_past',   stopOrder: 1,
            state: AttendanceState.missing),
        MockAttendance(passengerId: 'p_current', stopOrder: 2),
      ];
      const currentStop = 2;
      list.sort((a, b) {
        if (a.stopOrder == currentStop && b.stopOrder != currentStop) return -1;
        if (a.stopOrder != currentStop && b.stopOrder == currentStop) return 1;
        return a.stopOrder.compareTo(b.stopOrder);
      });
      expect(list.first.passengerId, 'p_current');
    });
  });
}
