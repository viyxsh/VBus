import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:vbuss/models/bus_stop.dart';
import 'package:vbuss/widgets/bus_stops_list.dart';
import 'package:vbuss/widgets/bus_info_card.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  bool _isStopListExpanded = false;

  // Current bus location
  final LatLng _currentBusLocation = const LatLng(23.263991, 77.472503);

  // Set initial camera position to the current bus location
  late CameraPosition _initialPosition;

  // Set of markers to be displayed on the map
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};

  // Sample bus stops data but in a real application, this data should be fetched from api or db
  final List<BusStop> _busStops = [
    BusStop(id: "1", name: "Vijay Market", time: "6:40", returnTime: "6:40", location: const LatLng(23.227256, 77.467591), isVisited: true),
    BusStop(id: "2", name: "Mahatma Gandhi Square", time: "6:41", returnTime: "6:36", location: const LatLng(23.232291, 77.471972), isVisited: true),
    BusStop(id: "3", name: "Gandhi Market", time: "6:43", returnTime: "6:34", location: const LatLng(23.239570, 77.472964), isVisited: true),
    BusStop(id: "4", name: "Piplani", time: "6:45", returnTime: "6:32", location: const LatLng(23.249139, 77.471609), isVisited: true),
    BusStop(id: "5", name: "Ayodhya Bypass", time: "6:47", returnTime: "6:28", location: const LatLng(23.251102, 77.479520), isVisited: true),
    BusStop(id: "6", name: "Narela Jod", time: "6:48", returnTime: "6:23", location: const LatLng(23.268628, 77.468866), isVisited: false),
    BusStop(id: "7", name: "Minal Residency (Gate No. 2)", time: "6:49", returnTime: "6:20", location: const LatLng(23.275646, 77.463426), isVisited: false),
    BusStop(id: "8", name: "SIRT", time: "6:51", returnTime: "6:15", location: const LatLng(23.278570, 77.4553149), isVisited: false),
    BusStop(id: "9", name: "People's Mall", time: "6:56", returnTime: "6:12", location: const LatLng(23.303084, 77.421494), isVisited: false),
    BusStop(id: "10", name: "BMHRC", time: "6:57", returnTime: "6:10", location: const LatLng(23.303185, 77.417310), isVisited: false),
    BusStop(id: "11", name: "Karond Square", time: "6:59", returnTime: "6:08", location: const LatLng(23.302651, 77.403840), isVisited: false),
    BusStop(id: "12", name: "Sanjeev Nagar Bus Stop", time: "7:05", returnTime: "5:57", location: const LatLng(23.301351, 77.3785242), isVisited: false),
    BusStop(id: "13", name: "RGPV", time: "7:10", returnTime: "5:52", location: const LatLng(23.301361, 77.36218), isVisited: false),
    BusStop(id: "14", name: "Lalghati", time: "7:18", returnTime: "5:45", location: const LatLng(23.281227, 77.360611), isVisited: false),
    BusStop(id: "15", name: "Chanchal Chouraha (Bairagarh)", time: "7:23", returnTime: "5:40", location: const LatLng(23.271003, 77.337352), isVisited: false),
    BusStop(id: "16", name: "Fanda", time: "7:30", returnTime: "5:30", location: const LatLng(23.229197, 77.210600), isVisited: false),
    BusStop(id: "17", name: "VIT Campus", time: "8:20", returnTime: "4:45", location: const LatLng(23.084549, 76.849612), isVisited: false),
  ];

  @override
  void initState() {
    super.initState();
    _initialPosition = CameraPosition(
      target: _currentBusLocation,
      zoom: 14.0,
    );
    _initializeMapElements();
  }

  void _initializeMapElements() {
    // Add route polyline
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: _busStops.map((stop) => stop.location).toList(),
        color: Colors.black,
        width: 4,
      ),
    );

    // Add stop markers
    for (var stop in _busStops) {
      // Add circle for each stop
      _circles.add(
        Circle(
          circleId: CircleId('circle_${stop.id}'),
          center: stop.location,
          radius: 30, // in meters
          strokeWidth: 3,
          strokeColor: stop.isVisited ? Colors.black : Colors.white,
          fillColor: stop.isVisited ? Colors.black.withOpacity(0.7) : Colors.transparent,
        ),
      );

      // Add info window marker for each stop
      _markers.add(
        Marker(
          markerId: MarkerId('stop_${stop.id}'),
          position: stop.location,
          infoWindow: InfoWindow(
            title: stop.name,
            snippet: "BPL→VIT: ${stop.time} | VIT→BPL: ${stop.returnTime}",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            stop.isVisited ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          // Make the marker invisible but keep the info window
          alpha: 0.01,
        ),
      );
    }

    // Add current bus location marker
    _markers.add(
      Marker(
        markerId: const MarkerId('current_bus'),
        position: _currentBusLocation,
        infoWindow: const InfoWindow(
          title: 'Current Bus Location',
          snippet: 'Bus is currently here',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Tracker'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            polylines: _polylines,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false, // Disable default zoom controls
            zoomGesturesEnabled: true, // Enable pinch to zoom
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),
          // Bottom info card with expandable list
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Expandable stop list
                if (_isStopListExpanded)
                  BusStopsList(
                    busStops: _busStops,
                    onStopTap: (location) async {
                      final GoogleMapController controller = await _controller.future;
                      controller.animateCamera(CameraUpdate.newLatLngZoom(
                        location,
                        15,
                      ));
                      setState(() {
                        _isStopListExpanded = false;
                      });
                    },
                    onClose: () {
                      setState(() {
                        _isStopListExpanded = false;
                      });
                    },
                  ),
                //add recenter button

                // Main info card
                BusInfoCard(
                  nextStop: _getNextStop(),
                  estimatedTime: _getEstimatedTime(),
                  routeProgress: _getRouteProgress(),
                  onToggleStopsList: () {
                    setState(() {
                      _isStopListExpanded = !_isStopListExpanded;
                    });
                  },
                  isStopListExpanded: _isStopListExpanded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Method to go to current bus location
  Future<void> _goToCurrentBusLocation() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(
      _currentBusLocation,
      15,
    ));
  }

  // Get the next unvisited stop
  BusStop _getNextStop() {
    for (final stop in _busStops) {
      if (!stop.isVisited) {
        return stop;
      }
    }
    return _busStops.last;
  }

  // Get estimated time to next stop
  String _getEstimatedTime() {
    // Replace with actual calculation based on distance and speed
    return "2";
  }

  // Calculate the route progress
  double _getRouteProgress() {
    int visitedStops = _busStops.where((stop) => stop.isVisited).length;
    return visitedStops / _busStops.length;
  }
}