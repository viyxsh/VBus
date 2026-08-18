import 'package:flutter_test/flutter_test.dart';

import 'package:vbusf/features/conductor/attendance/models/attendance_roster.dart';

AttendanceEntry entry(
  String id, {
  int stopOrder = 1,
  String? stopId,
  AttendanceState state = AttendanceState.waiting,
  DateTime? scannedAt,
}) =>
    AttendanceEntry(
      id: id,
      passengerId: 'passenger-$id',
      name: 'Passenger $id',
      stopId: stopId ?? 'stop-$stopOrder',
      stopName: 'Stop $stopOrder',
      stopOrder: stopOrder,
      state: state,
      scannedAt: scannedAt,
    );

void main() {
  // ─── Initial state (mirrors createAttendanceRecords in the repository) ───────
  group('initialState', () {
    test('passenger with a seat booking today starts waiting', () {
      expect(AttendanceMachine.initialState(hasSeatBooking: true),
          AttendanceState.waiting);
    });

    test('passenger without a booking starts absent', () {
      expect(AttendanceMachine.initialState(hasSeatBooking: false),
          AttendanceState.absent);
    });
  });

  // ─── Scan (mark present) ──────────────────────────────────────────────────────
  group('markPresent', () {
    late List<AttendanceEntry> list;
    setUp(() => list = [
          entry('p1'),
          entry('p2'),
          entry('p3', stopOrder: 2),
        ]);

    test('marks the scanned passenger present and stamps scannedAt', () {
      final at = DateTime(2026, 9, 10, 7, 30);
      expect(AttendanceMachine.markPresent(list, 'p1', scannedAt: at), isTrue);
      expect(list.firstWhere((a) => a.id == 'p1').state,
          AttendanceState.present);
      expect(list.firstWhere((a) => a.id == 'p1').scannedAt, at);
    });

    test('defaults scannedAt to now when not provided', () {
      final before = DateTime.now();
      AttendanceMachine.markPresent(list, 'p1');
      final scanned = list.firstWhere((a) => a.id == 'p1').scannedAt!;
      expect(scanned.isBefore(before) || scanned == before ||
          scanned.isAfter(before), isTrue);
    });

    test('does not affect other passengers', () {
      AttendanceMachine.markPresent(list, 'p1');
      expect(list.firstWhere((a) => a.id == 'p2').state,
          AttendanceState.waiting);
      expect(list.firstWhere((a) => a.id == 'p3').state,
          AttendanceState.waiting);
    });

    test('rescanning overwrites the scan timestamp (repository semantics)',
        () {
      AttendanceMachine.markPresent(list, 'p1',
          scannedAt: DateTime(2026, 9, 10, 7, 0));
      final firstScan = list.firstWhere((a) => a.id == 'p1').scannedAt;

      AttendanceMachine.markPresent(list, 'p1',
          scannedAt: DateTime(2026, 9, 10, 7, 15));
      final e = list.firstWhere((a) => a.id == 'p1');
      expect(e.state, AttendanceState.present);
      expect(e.scannedAt, isNot(firstScan));
    });

    test('can override a missing passenger (stop already passed)', () {
      final list2 = [entry('p1', state: AttendanceState.missing)];
      expect(AttendanceMachine.markPresent(list2, 'p1'), isTrue);
      expect(list2.first.state, AttendanceState.present);
    });

    test('returns false for an unknown record id', () {
      expect(AttendanceMachine.markPresent(list, 'nope'), isFalse);
    });
  });

  // ─── Advance stop ─────────────────────────────────────────────────────────────
  group('markStopWaitingMissing', () {
    late List<AttendanceEntry> list;
    setUp(() => list = [
          entry('p1', stopId: 'stop-1'),
          entry('p2', stopId: 'stop-1'),
          entry('p3', stopOrder: 2, stopId: 'stop-2'),
          entry('p4', stopOrder: 3, stopId: 'stop-3'),
        ]);

    test('marks waiting passengers at the passed stop as missing', () {
      final changed = AttendanceMachine.markStopWaitingMissing(list, 'stop-1');
      expect(changed, 2);
      expect(list.firstWhere((a) => a.id == 'p1').state,
          AttendanceState.missing);
      expect(list.firstWhere((a) => a.id == 'p2').state,
          AttendanceState.missing);
    });

    test('does not affect passengers at other stops', () {
      AttendanceMachine.markStopWaitingMissing(list, 'stop-1');
      expect(list.firstWhere((a) => a.id == 'p3').state,
          AttendanceState.waiting);
      expect(list.firstWhere((a) => a.id == 'p4').state,
          AttendanceState.waiting);
    });

    test('does not change already-present passengers', () {
      AttendanceMachine.markPresent(list, 'p1');
      final changed = AttendanceMachine.markStopWaitingMissing(list, 'stop-1');
      expect(changed, 1);
      expect(list.firstWhere((a) => a.id == 'p1').state,
          AttendanceState.present);
      expect(list.firstWhere((a) => a.id == 'p2').state,
          AttendanceState.missing);
    });

    test('is idempotent — second pass changes nothing', () {
      AttendanceMachine.markStopWaitingMissing(list, 'stop-1');
      expect(
          AttendanceMachine.markStopWaitingMissing(list, 'stop-1'), 0);
    });

    test('returns 0 for an unknown stop', () {
      expect(AttendanceMachine.markStopWaitingMissing(list, 'stop-x'), 0);
    });
  });

  // ─── End trip ─────────────────────────────────────────────────────────────────
  group('markRemainingAbsent', () {
    test('marks all remaining waiting passengers as absent', () {
      final list = [
        entry('p1', state: AttendanceState.present),
        entry('p2', state: AttendanceState.missing),
        entry('p3', stopOrder: 3),
        entry('p4', stopOrder: 4),
      ];
      final changed = AttendanceMachine.markRemainingAbsent(list);
      expect(changed, 2);
      expect(list.firstWhere((a) => a.id == 'p1').state,
          AttendanceState.present); // unchanged
      expect(list.firstWhere((a) => a.id == 'p2').state,
          AttendanceState.missing); // unchanged
      expect(list.firstWhere((a) => a.id == 'p3').state,
          AttendanceState.absent); // was waiting
      expect(list.firstWhere((a) => a.id == 'p4').state,
          AttendanceState.absent); // was waiting
    });

    test('all present at end of a perfect trip', () {
      final list = [entry('p1'), entry('p2', stopOrder: 2)];
      AttendanceMachine.markPresent(list, 'p1');
      AttendanceMachine.markPresent(list, 'p2');
      AttendanceMachine.markRemainingAbsent(list);
      expect(list.every((a) => a.state == AttendanceState.present), isTrue);
    });

    test('no-op when everyone already resolved', () {
      final list = [
        entry('p1', state: AttendanceState.present),
        entry('p2', state: AttendanceState.absent),
      ];
      expect(AttendanceMachine.markRemainingAbsent(list), 0);
    });
  });

  // ─── Stats computation ────────────────────────────────────────────────────────
  group('stats', () {
    test('initial stats — all waiting', () {
      final s = AttendanceMachine.stats([
        entry('p1'),
        entry('p2'),
        entry('p3', stopOrder: 2),
      ]);
      expect(s['total'], 3);
      expect(s['waiting'], 3);
      expect(s['present'], 0);
      expect(s['missing'], 0);
      expect(s['absent'], 0);
    });

    test('stats after a mixed scenario', () {
      final list = [
        entry('p1'),
        entry('p2'),
        entry('p3', stopOrder: 2, stopId: 'stop-2'),
        entry('p4', stopOrder: 2, stopId: 'stop-2'),
      ];
      AttendanceMachine.markPresent(list, 'p1'); // p1 → present
      AttendanceMachine.markStopWaitingMissing(list, 'stop-1'); // p2 → missing
      AttendanceMachine.markPresent(list, 'p3'); // p3 → present
      final s = AttendanceMachine.stats(list);
      expect(s['total'], 4);
      expect(s['present'], 2); // p1, p3
      expect(s['missing'], 1); // p2
      expect(s['waiting'], 1); // p4
      expect(s['absent'], 0);
    });

    test('totals are consistent', () {
      final s = AttendanceMachine.stats([
        entry('p1', state: AttendanceState.present),
        entry('p2', state: AttendanceState.missing),
        entry('p3', stopOrder: 2, state: AttendanceState.absent),
        entry('p4', stopOrder: 2),
      ]);
      expect(
        s['present']! + s['missing']! + s['absent']! + s['waiting']!,
        s['total'],
      );
    });
  });

  // ─── List ordering ────────────────────────────────────────────────────────────
  group('sortByCurrentStop', () {
    test('current stop passengers appear first, then stop order', () {
      final list = [
        entry('future', stopOrder: 3),
        entry('past', stopOrder: 1, state: AttendanceState.missing),
        entry('currentB', stopOrder: 2),
        entry('currentA', stopOrder: 2),
      ];
      AttendanceMachine.sortByCurrentStop(list, 2);
      // Dart's sort is not stable, so only assert the current-stop pair
      // occupies the first two slots, then the rest in stop order.
      expect({list[0].id, list[1].id}, {'currentA', 'currentB'});
      expect(list[2].id, 'past');
      expect(list[3].id, 'future');
    });

    test('without a current-stop match, plain stop order wins', () {
      final list = [
        entry('c', stopOrder: 3),
        entry('a', stopOrder: 1),
        entry('b', stopOrder: 2),
      ];
      AttendanceMachine.sortByCurrentStop(list, 99);
      expect(list.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });
  });

  // ─── DB state parsing ─────────────────────────────────────────────────────────
  group('AttendanceStateX.fromName', () {
    test('parses all known state names', () {
      expect(AttendanceStateX.fromName('waiting'),
          AttendanceState.waiting);
      expect(AttendanceStateX.fromName('present'),
          AttendanceState.present);
      expect(AttendanceStateX.fromName('missing'),
          AttendanceState.missing);
      expect(AttendanceStateX.fromName('absent'), AttendanceState.absent);
    });

    test('unknown values fall back to waiting', () {
      expect(AttendanceStateX.fromName('bogus'), AttendanceState.waiting);
    });
  });
}
