/// A chat room as shown in an inbox list, with its last-message preview and
/// unread count already resolved.
class InboxRoom {
  final String id;
  final String title;
  final bool isBroadcast;
  final String? phone;
  final String? userType; // 'student' | 'faculty' | null (broadcast)
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastIsMe;
  final int unreadCount;

  const InboxRoom({
    required this.id,
    required this.title,
    required this.isBroadcast,
    this.phone,
    this.userType,
    this.lastMessage,
    this.lastMessageAt,
    this.lastIsMe = false,
    this.unreadCount = 0,
  });
}

/// Result of loading the passenger inbox: at most one broadcast room and one
/// direct room, plus the conductor's details for the "start chat" affordance.
class PassengerInbox {
  final String busId;
  final String busNumber;
  final String conductorName;
  final String? conductorPhone;
  final InboxRoom? broadcast;
  final InboxRoom? direct;

  const PassengerInbox({
    required this.busId,
    required this.busNumber,
    required this.conductorName,
    required this.conductorPhone,
    required this.broadcast,
    required this.direct,
  });
}

/// Result of loading the conductor inbox: the bus broadcast room plus a direct
/// room per passenger who has one.
class ConductorInbox {
  final String busId;
  final InboxRoom? broadcast;
  final List<InboxRoom> directs;

  const ConductorInbox({
    required this.busId,
    required this.broadcast,
    required this.directs,
  });

  int get totalUnread =>
      (broadcast?.unreadCount ?? 0) +
      directs.fold(0, (sum, r) => sum + r.unreadCount);
}
