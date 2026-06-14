enum TripState { notStarted, ongoing, ended }

extension TripStateX on TripState {
  String get value => switch (this) {
        TripState.notStarted => 'not_started',
        TripState.ongoing => 'ongoing',
        TripState.ended => 'ended',
      };

  static TripState fromString(String value) => switch (value) {
        'ongoing' => TripState.ongoing,
        'ended' => TripState.ended,
        _ => TripState.notStarted,
      };
}
