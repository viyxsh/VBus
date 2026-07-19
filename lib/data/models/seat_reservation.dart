/// A permanent seat reservation request, typically from a faculty member to a
/// conductor. Once approved the seat is permanently assigned to that passenger.
class SeatReservation {
  final String id;
  final String busId;
  final String passengerId;
  final int seatNumber;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? respondedBy;
  final String? rejectionReason;

  /// Passenger details populated on joined queries.
  final String? passengerName;
  final String? passengerInstituteId;
  final String? passengerUserType;

  const SeatReservation({
    required this.id,
    required this.busId,
    required this.passengerId,
    required this.seatNumber,
    required this.status,
    required this.requestedAt,
    this.respondedAt,
    this.respondedBy,
    this.rejectionReason,
    this.passengerName,
    this.passengerInstituteId,
    this.passengerUserType,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory SeatReservation.fromMap(Map<String, dynamic> m) {
    final p = m['passengers'] as Map?;
    return SeatReservation(
      id: m['id'] as String,
      busId: m['bus_id'] as String,
      passengerId: m['passenger_id'] as String,
      seatNumber: (m['seat_number'] as num).toInt(),
      status: m['status'] as String? ?? 'pending',
      requestedAt: DateTime.parse(m['requested_at'] as String),
      respondedAt: m['responded_at'] != null
          ? DateTime.parse(m['responded_at'] as String)
          : null,
      respondedBy: m['responded_by'] as String?,
      rejectionReason: m['rejection_reason'] as String?,
      passengerName: p?['name'] as String?,
      passengerInstituteId: p?['institute_id'] as String?,
      passengerUserType: p?['user_type'] as String?,
    );
  }
}
