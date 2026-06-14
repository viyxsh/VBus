// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passenger_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$passengerProfileHash() => r'c7ba8719152efa7dd592294da4ad4b7a20ba37a7';

/// The signed-in passenger's profile.
///
/// Copied from [passengerProfile].
@ProviderFor(passengerProfile)
final passengerProfileProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>>.internal(
      passengerProfile,
      name: r'passengerProfileProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$passengerProfileHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PassengerProfileRef =
    AutoDisposeFutureProviderRef<Map<String, dynamic>>;
String _$passengerStopsHash() => r'3cc3ed86c1718616e5e230863f3d0067d1871cad';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Stops on a bus's route (for the boarding-stop picker).
///
/// Copied from [passengerStops].
@ProviderFor(passengerStops)
const passengerStopsProvider = PassengerStopsFamily();

/// Stops on a bus's route (for the boarding-stop picker).
///
/// Copied from [passengerStops].
class PassengerStopsFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// Stops on a bus's route (for the boarding-stop picker).
  ///
  /// Copied from [passengerStops].
  const PassengerStopsFamily();

  /// Stops on a bus's route (for the boarding-stop picker).
  ///
  /// Copied from [passengerStops].
  PassengerStopsProvider call(String busId) {
    return PassengerStopsProvider(busId);
  }

  @override
  PassengerStopsProvider getProviderOverride(
    covariant PassengerStopsProvider provider,
  ) {
    return call(provider.busId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'passengerStopsProvider';
}

/// Stops on a bus's route (for the boarding-stop picker).
///
/// Copied from [passengerStops].
class PassengerStopsProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// Stops on a bus's route (for the boarding-stop picker).
  ///
  /// Copied from [passengerStops].
  PassengerStopsProvider(String busId)
    : this._internal(
        (ref) => passengerStops(ref as PassengerStopsRef, busId),
        from: passengerStopsProvider,
        name: r'passengerStopsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$passengerStopsHash,
        dependencies: PassengerStopsFamily._dependencies,
        allTransitiveDependencies:
            PassengerStopsFamily._allTransitiveDependencies,
        busId: busId,
      );

  PassengerStopsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.busId,
  }) : super.internal();

  final String busId;

  @override
  Override overrideWith(
    FutureOr<List<Map<String, dynamic>>> Function(PassengerStopsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PassengerStopsProvider._internal(
        (ref) => create(ref as PassengerStopsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        busId: busId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _PassengerStopsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PassengerStopsProvider && other.busId == busId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, busId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PassengerStopsRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `busId` of this provider.
  String get busId;
}

class _PassengerStopsProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with PassengerStopsRef {
  _PassengerStopsProviderElement(super.provider);

  @override
  String get busId => (origin as PassengerStopsProvider).busId;
}

String _$customPinsHash() => r'e028be6f7b1039d02fa6d7bf81aa2474c2f7b965';

/// The passenger's custom map pins for a bus.
///
/// Copied from [customPins].
@ProviderFor(customPins)
const customPinsProvider = CustomPinsFamily();

/// The passenger's custom map pins for a bus.
///
/// Copied from [customPins].
class CustomPinsFamily extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// The passenger's custom map pins for a bus.
  ///
  /// Copied from [customPins].
  const CustomPinsFamily();

  /// The passenger's custom map pins for a bus.
  ///
  /// Copied from [customPins].
  CustomPinsProvider call(String busId) {
    return CustomPinsProvider(busId);
  }

  @override
  CustomPinsProvider getProviderOverride(
    covariant CustomPinsProvider provider,
  ) {
    return call(provider.busId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'customPinsProvider';
}

/// The passenger's custom map pins for a bus.
///
/// Copied from [customPins].
class CustomPinsProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// The passenger's custom map pins for a bus.
  ///
  /// Copied from [customPins].
  CustomPinsProvider(String busId)
    : this._internal(
        (ref) => customPins(ref as CustomPinsRef, busId),
        from: customPinsProvider,
        name: r'customPinsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customPinsHash,
        dependencies: CustomPinsFamily._dependencies,
        allTransitiveDependencies: CustomPinsFamily._allTransitiveDependencies,
        busId: busId,
      );

  CustomPinsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.busId,
  }) : super.internal();

  final String busId;

  @override
  Override overrideWith(
    FutureOr<List<Map<String, dynamic>>> Function(CustomPinsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CustomPinsProvider._internal(
        (ref) => create(ref as CustomPinsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        busId: busId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _CustomPinsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomPinsProvider && other.busId == busId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, busId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CustomPinsRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `busId` of this provider.
  String get busId;
}

class _CustomPinsProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with CustomPinsRef {
  _CustomPinsProviderElement(super.provider);

  @override
  String get busId => (origin as CustomPinsProvider).busId;
}

String _$seatBookingHistoryHash() =>
    r'5d1d21d785fece4d9d68c81a2d1c5985c282630a';

/// The passenger's seat-booking history over the last 7 days.
///
/// Copied from [seatBookingHistory].
@ProviderFor(seatBookingHistory)
final seatBookingHistoryProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      seatBookingHistory,
      name: r'seatBookingHistoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$seatBookingHistoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SeatBookingHistoryRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
