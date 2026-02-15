import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../data/repositories/bus_repository.dart';

part 'conductor_profile_providers.g.dart';

/// The signed-in conductor's profile joined with their bus configuration.
@riverpod
Future<Map<String, dynamic>> conductorProfile(Ref ref) =>
    ref.watch(busRepositoryProvider).conductorProfile();

/// All passengers on a bus (any approval status), for the manage sheet.
@riverpod
Future<List<Map<String, dynamic>>> busPassengers(Ref ref, String busId) =>
    ref.watch(busRepositoryProvider).busPassengers(busId);
