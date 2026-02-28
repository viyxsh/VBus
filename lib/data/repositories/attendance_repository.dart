import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/supabase_constants.dart';
import '../../main.dart';

part 'attendance_repository.g.dart';

@riverpod
AttendanceRepository attendanceRepository(Ref ref) => AttendanceRepository();

/// Data access for trip lifecycle and per-passenger attendance records.
class AttendanceRepository {
  /// Today's trip for a conductor's bus — prefers an ongoing trip, else the
  /// most recent ended one, else null.
  Future<Map<String, dynamic>?> currentOrLastTrip({
    required String busId,
    required String conductorId,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final ongoing = await supabase
        .from(SupabaseConstants.trips)
        .select()
        .eq('bus_id', busId)
        .eq('conductor_id', conductorId)
        .eq('trip_date', today)
        .eq('state', 'ongoing')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (ongoing != null) return Map<String, dynamic>.from(ongoing);

    final ended = await supabase
        .from(SupabaseConstants.trips)
        .select()
        .eq('bus_id', busId)
        .eq('conductor_id', conductorId)
        .eq('trip_date', today)
        .eq('state', 'ended')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return ended == null ? null : Map<String, dynamic>.from(ended);
  }

  // Demo roster names, shown on the conductor attendance page in demo mode.
  static const _demoNames = [
    'Aarav Sharma', 'Diya Patel', 'Kabir Reddy', 'Ananya Verma',
    'Rohan Mehta', 'Isha Kulkarni', 'Vihaan Tiwari', 'Sara Nair',
    'Arjun Desai', 'Myra Joshi', 'Aditya Rao', 'Tara Menon',
    'Krishna Iyer', 'Riya Gupta', 'Dev Malhotra', 'Anvi Shah',
  ];

  /// All attendance rows for a trip, joined with passenger and stop info.
  Future<List<Map<String, dynamic>>> attendanceForTrip(String tripId) async {
    if (AppConfig.demoMode) return _demoAttendance(tripId);
    final data = await supabase
        .from(SupabaseConstants.attendance)
        .select(
          'id, passenger_id, stop_id, state, scanned_at, '
          'passengers(name), bus_stops(name, stop_order)',
        )
        .eq('trip_id', tripId);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Builds a believable attendance roster for the demo: students spread across
  /// the route's stops, with states derived from where the bus currently is
  /// (passed stops → present/missing, current & upcoming → waiting).
  Future<List<Map<String, dynamic>>> _demoAttendance(String tripId) async {
    final trip = await supabase
        .from(SupabaseConstants.trips)
        .select('bus_id, current_stop_index')
        .eq('id', tripId)
        .single();
    final busId = trip['bus_id'] as String;
    final currentIdx = (trip['current_stop_index'] as num?)?.toInt() ?? 0;

    final bus = await supabase
        .from(SupabaseConstants.buses)
        .select('route_id')
        .eq('id', busId)
        .single();

    final stops = List<Map<String, dynamic>>.from(await supabase
        .from(SupabaseConstants.busStops)
        .select('id, name, stop_order')
        .eq('route_id', bus['route_id'] as String)
        .order('stop_order') as List);
    if (stops.isEmpty) return [];

    final result = <Map<String, dynamic>>[];
    for (int j = 0; j < _demoNames.length; j++) {
      final stopIdx = j % stops.length;
      final stop = stops[stopIdx];

      final String state;
      if (stopIdx < currentIdx) {
        state = (j % 4 == 0) ? 'missing' : 'present'; // passed stops
      } else if (stopIdx == currentIdx) {
        state = (j % 2 == 0) ? 'present' : 'waiting'; // boarding now
      } else {
        state = 'waiting'; // upcoming stops
      }

      result.add({
        'id': 'demo-att-$j',
        'passenger_id': 'demo-passenger-$j',
        'stop_id': stop['id'],
        'state': state,
        'scanned_at': null,
        'passengers': {'name': _demoNames[j]},
        'bus_stops': {
          'name': stop['name'],
          'stop_order': stop['stop_order'],
        },
      });
    }
    return result;
  }

  /// Starts a new ongoing trip and returns the created row.
  Future<Map<String, dynamic>> startTrip({
    required String busId,
    required String conductorId,
  }) async {
    if (AppConfig.demoMode) {
      // Reuse the seeded live trip instead of creating one.
      final existing =
          await currentOrLastTrip(busId: busId, conductorId: conductorId);
      if (existing != null) return existing;
    }
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final trip = await supabase
        .from(SupabaseConstants.trips)
        .insert({
          'bus_id': busId,
          'conductor_id': conductorId,
          'trip_date': today,
          'state': 'ongoing',
          'started_at': DateTime.now().toIso8601String(),
          'current_stop_index': 0,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(trip);
  }

  /// Approved passengers on a bus with their boarding stop, for generating
  /// the initial attendance roster.
  Future<List<Map<String, dynamic>>> approvedRoster(String busId) async {
    final data = await supabase
        .from(SupabaseConstants.passengers)
        .select('id, stop_id')
        .eq('bus_id', busId)
        .eq('approval_status', 'approved');
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Creates 'waiting' attendance records for a trip's roster.
  Future<void> createAttendanceRecords(
    String tripId,
    List<Map<String, dynamic>> roster,
  ) async {
    if (AppConfig.demoMode) return; // live prototype: no roster writes
    if (roster.isEmpty) return;
    await supabase.from(SupabaseConstants.attendance).insert(
          roster
              .map((p) => {
                    'trip_id': tripId,
                    'passenger_id': p['id'],
                    'stop_id': p['stop_id'],
                    'state': 'waiting',
                  })
              .toList(),
        );
  }

  /// Marks waiting passengers at a passed stop as missing.
  Future<void> markStopWaitingMissing(String tripId, String stopId) async {
    if (AppConfig.demoMode) return;
    await supabase
        .from(SupabaseConstants.attendance)
        .update({'state': 'missing'})
        .eq('trip_id', tripId)
        .eq('stop_id', stopId)
        .eq('state', 'waiting');
  }

  Future<void> updateCurrentStopIndex(String tripId, int index) async {
    if (AppConfig.demoMode) return; // the seeded cron job drives the index
    await supabase
        .from(SupabaseConstants.trips)
        .update({'current_stop_index': index})
        .eq('id', tripId);
  }

  /// Ends a trip: marks remaining waiting passengers absent, then closes it.
  Future<void> endTrip(String tripId) async {
    if (AppConfig.demoMode) return; // never end the seeded live demo trip
    await supabase
        .from(SupabaseConstants.attendance)
        .update({'state': 'absent'})
        .eq('trip_id', tripId)
        .eq('state', 'waiting');

    await supabase.from(SupabaseConstants.trips).update({
      'state': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', tripId);
  }

  /// Finds a passenger on a bus by their VIT registration number.
  Future<Map<String, dynamic>?> findPassengerByReg(
      String regNumber, String busId) async {
    final passenger = await supabase
        .from(SupabaseConstants.passengers)
        .select('id, name')
        .eq('institute_id', regNumber)
        .eq('bus_id', busId)
        .maybeSingle();
    return passenger == null ? null : Map<String, dynamic>.from(passenger);
  }

  Future<void> markPresent(String attendanceId) async {
    if (AppConfig.demoMode) return; // live prototype: simulate the scan only
    await supabase.from(SupabaseConstants.attendance).update({
      'state': 'present',
      'scanned_at': DateTime.now().toIso8601String(),
    }).eq('id', attendanceId);
  }
}
