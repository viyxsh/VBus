enum AttendanceState { waiting, present, missing, absent }

extension AttendanceStateX on AttendanceState {
  String get value => switch (this) {
        AttendanceState.waiting => 'waiting',
        AttendanceState.present => 'present',
        AttendanceState.missing => 'missing',
        AttendanceState.absent => 'absent',
      };

  static AttendanceState fromString(String value) => switch (value) {
        'present' => AttendanceState.present,
        'missing' => AttendanceState.missing,
        'absent' => AttendanceState.absent,
        _ => AttendanceState.waiting,
      };
}
