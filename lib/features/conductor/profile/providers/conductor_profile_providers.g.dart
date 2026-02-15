// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conductor_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$conductorProfileHash() => r'086dd8b0168e2f345628b52095c5efe2e4a11963';

/// The signed-in conductor's profile joined with their bus configuration.
///
/// Copied from [conductorProfile].
@ProviderFor(conductorProfile)
final conductorProfileProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>>.internal(
      conductorProfile,
      name: r'conductorProfileProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$conductorProfileHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConductorProfileRef =
    AutoDisposeFutureProviderRef<Map<String, dynamic>>;
String _$busPassengersHash() => r'952a19d4bd12f05bfd24347203e5f14e160f4370';

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

/// All passengers on a bus (any approval status), for the manage sheet.
///
/// Copied from [busPassengers].
@ProviderFor(busPassengers)
const busPassengersProvider = BusPassengersFamily();

/// All passengers on a bus (any approval status), for the manage sheet.
///
/// Copied from [busPassengers].
class BusPassengersFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// All passengers on a bus (any approval status), for the manage sheet.
  ///
  /// Copied from [busPassengers].
  const BusPassengersFamily();

  /// All passengers on a bus (any approval status), for the manage sheet.
  ///
  /// Copied from [busPassengers].
  BusPassengersProvider call(String busId) {
    return BusPassengersProvider(busId);
  }

  @override
  BusPassengersProvider getProviderOverride(
    covariant BusPassengersProvider provider,
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
  String? get name => r'busPassengersProvider';
}

/// All passengers on a bus (any approval status), for the manage sheet.
///
/// Copied from [busPassengers].
class BusPassengersProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// All passengers on a bus (any approval status), for the manage sheet.
  ///
  /// Copied from [busPassengers].
  BusPassengersProvider(String busId)
    : this._internal(
        (ref) => busPassengers(ref as BusPassengersRef, busId),
        from: busPassengersProvider,
        name: r'busPassengersProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$busPassengersHash,
        dependencies: BusPassengersFamily._dependencies,
        allTransitiveDependencies:
            BusPassengersFamily._allTransitiveDependencies,
        busId: busId,
      );

  BusPassengersProvider._internal(
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
    FutureOr<List<Map<String, dynamic>>> Function(BusPassengersRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BusPassengersProvider._internal(
        (ref) => create(ref as BusPassengersRef),
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
    return _BusPassengersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BusPassengersProvider && other.busId == busId;
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
mixin BusPassengersRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `busId` of this provider.
  String get busId;
}

class _BusPassengersProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with BusPassengersRef {
  _BusPassengersProviderElement(super.provider);

  @override
  String get busId => (origin as BusPassengersProvider).busId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
