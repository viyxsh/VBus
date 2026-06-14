enum ApprovalStatus { pending, approved, rejected }

extension ApprovalStatusX on ApprovalStatus {
  String get value => switch (this) {
        ApprovalStatus.pending => 'pending',
        ApprovalStatus.approved => 'approved',
        ApprovalStatus.rejected => 'rejected',
      };

  static ApprovalStatus fromString(String value) => switch (value) {
        'approved' => ApprovalStatus.approved,
        'rejected' => ApprovalStatus.rejected,
        _ => ApprovalStatus.pending,
      };
}
