// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatMessagesHash() => r'06eab01dfe0b487325e5f3442116d8af9c8a5665';

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

/// Live messages for a chat room (initial page + realtime inserts).
///
/// Copied from [chatMessages].
@ProviderFor(chatMessages)
const chatMessagesProvider = ChatMessagesFamily();

/// Live messages for a chat room (initial page + realtime inserts).
///
/// Copied from [chatMessages].
class ChatMessagesFamily extends Family<AsyncValue<List<ChatMessage>>> {
  /// Live messages for a chat room (initial page + realtime inserts).
  ///
  /// Copied from [chatMessages].
  const ChatMessagesFamily();

  /// Live messages for a chat room (initial page + realtime inserts).
  ///
  /// Copied from [chatMessages].
  ChatMessagesProvider call(String roomId) {
    return ChatMessagesProvider(roomId);
  }

  @override
  ChatMessagesProvider getProviderOverride(
    covariant ChatMessagesProvider provider,
  ) {
    return call(provider.roomId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatMessagesProvider';
}

/// Live messages for a chat room (initial page + realtime inserts).
///
/// Copied from [chatMessages].
class ChatMessagesProvider
    extends AutoDisposeStreamProvider<List<ChatMessage>> {
  /// Live messages for a chat room (initial page + realtime inserts).
  ///
  /// Copied from [chatMessages].
  ChatMessagesProvider(String roomId)
    : this._internal(
        (ref) => chatMessages(ref as ChatMessagesRef, roomId),
        from: chatMessagesProvider,
        name: r'chatMessagesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$chatMessagesHash,
        dependencies: ChatMessagesFamily._dependencies,
        allTransitiveDependencies:
            ChatMessagesFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  ChatMessagesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.roomId,
  }) : super.internal();

  final String roomId;

  @override
  Override overrideWith(
    Stream<List<ChatMessage>> Function(ChatMessagesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ChatMessagesProvider._internal(
        (ref) => create(ref as ChatMessagesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        roomId: roomId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<ChatMessage>> createElement() {
    return _ChatMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessagesProvider && other.roomId == roomId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, roomId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatMessagesRef on AutoDisposeStreamProviderRef<List<ChatMessage>> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _ChatMessagesProviderElement
    extends AutoDisposeStreamProviderElement<List<ChatMessage>>
    with ChatMessagesRef {
  _ChatMessagesProviderElement(super.provider);

  @override
  String get roomId => (origin as ChatMessagesProvider).roomId;
}

String _$currentUserDisplayNameHash() =>
    r'418a8c5c753d43dd6bff95aa9300bfd46c1d92ea';

/// The signed-in user's display name, used as the message sender name.
///
/// Copied from [currentUserDisplayName].
@ProviderFor(currentUserDisplayName)
final currentUserDisplayNameProvider =
    AutoDisposeFutureProvider<String>.internal(
      currentUserDisplayName,
      name: r'currentUserDisplayNameProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentUserDisplayNameHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserDisplayNameRef = AutoDisposeFutureProviderRef<String>;
String _$chatPartnerInfoHash() => r'5fcaafcf21396c07a8fc4812376f0f17847b5542';

/// Details about the other party in a direct chat, for the info sheet.
///
/// Copied from [chatPartnerInfo].
@ProviderFor(chatPartnerInfo)
const chatPartnerInfoProvider = ChatPartnerInfoFamily();

/// Details about the other party in a direct chat, for the info sheet.
///
/// Copied from [chatPartnerInfo].
class ChatPartnerInfoFamily extends Family<AsyncValue<Map<String, dynamic>?>> {
  /// Details about the other party in a direct chat, for the info sheet.
  ///
  /// Copied from [chatPartnerInfo].
  const ChatPartnerInfoFamily();

  /// Details about the other party in a direct chat, for the info sheet.
  ///
  /// Copied from [chatPartnerInfo].
  ChatPartnerInfoProvider call(String roomId) {
    return ChatPartnerInfoProvider(roomId);
  }

  @override
  ChatPartnerInfoProvider getProviderOverride(
    covariant ChatPartnerInfoProvider provider,
  ) {
    return call(provider.roomId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatPartnerInfoProvider';
}

/// Details about the other party in a direct chat, for the info sheet.
///
/// Copied from [chatPartnerInfo].
class ChatPartnerInfoProvider
    extends AutoDisposeFutureProvider<Map<String, dynamic>?> {
  /// Details about the other party in a direct chat, for the info sheet.
  ///
  /// Copied from [chatPartnerInfo].
  ChatPartnerInfoProvider(String roomId)
    : this._internal(
        (ref) => chatPartnerInfo(ref as ChatPartnerInfoRef, roomId),
        from: chatPartnerInfoProvider,
        name: r'chatPartnerInfoProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$chatPartnerInfoHash,
        dependencies: ChatPartnerInfoFamily._dependencies,
        allTransitiveDependencies:
            ChatPartnerInfoFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  ChatPartnerInfoProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.roomId,
  }) : super.internal();

  final String roomId;

  @override
  Override overrideWith(
    FutureOr<Map<String, dynamic>?> Function(ChatPartnerInfoRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ChatPartnerInfoProvider._internal(
        (ref) => create(ref as ChatPartnerInfoRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        roomId: roomId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<String, dynamic>?> createElement() {
    return _ChatPartnerInfoProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatPartnerInfoProvider && other.roomId == roomId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, roomId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatPartnerInfoRef
    on AutoDisposeFutureProviderRef<Map<String, dynamic>?> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _ChatPartnerInfoProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>?>
    with ChatPartnerInfoRef {
  _ChatPartnerInfoProviderElement(super.provider);

  @override
  String get roomId => (origin as ChatPartnerInfoProvider).roomId;
}

String _$passengerInboxHash() => r'8887e15eb9ce3f7b55cef7d26f531ba4f3999214';

/// The passenger's inbox (broadcast + own direct room + conductor details).
///
/// Copied from [passengerInbox].
@ProviderFor(passengerInbox)
final passengerInboxProvider =
    AutoDisposeFutureProvider<PassengerInbox>.internal(
      passengerInbox,
      name: r'passengerInboxProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$passengerInboxHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PassengerInboxRef = AutoDisposeFutureProviderRef<PassengerInbox>;
String _$conductorInboxHash() => r'951eb5a4c80e53410ea5e8e2fcfa7ad86d421afc';

/// The conductor's inbox (broadcast + a direct room per passenger).
///
/// Copied from [conductorInbox].
@ProviderFor(conductorInbox)
final conductorInboxProvider =
    AutoDisposeFutureProvider<ConductorInbox>.internal(
      conductorInbox,
      name: r'conductorInboxProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$conductorInboxHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConductorInboxRef = AutoDisposeFutureProviderRef<ConductorInbox>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
