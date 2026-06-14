import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../data/repositories/passenger_repository.dart';

part 'passenger_profile_providers.g.dart';

/// The signed-in passenger's profile.
@riverpod
Future<Map<String, dynamic>> passengerProfile(Ref ref) =>
    ref.watch(passengerRepositoryProvider).profile();

/// Stops on a bus's route (for the boarding-stop picker).
@riverpod
Future<List<Map<String, dynamic>>> passengerStops(Ref ref, String busId) =>
    ref.watch(passengerRepositoryProvider).stopsForBus(busId);

/// The passenger's custom map pins for a bus.
@riverpod
Future<List<Map<String, dynamic>>> customPins(Ref ref, String busId) =>
    ref.watch(passengerRepositoryProvider).customPins(busId);

/// The passenger's seat-booking history over the last 7 days.
@riverpod
Future<List<Map<String, dynamic>>> seatBookingHistory(Ref ref) =>
    ref.watch(passengerRepositoryProvider).recentSeatBookings();
