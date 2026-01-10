import 'package:google_maps_flutter/google_maps_flutter.dart';

class BusStop {
  final String id;
  final String name;
  final String time;
  final String returnTime;
  final LatLng location;
  final bool isVisited;

  BusStop({
    required this.id,
    required this.name,
    required this.time,
    required this.returnTime,
    required this.location,
    required this.isVisited,
  });
}