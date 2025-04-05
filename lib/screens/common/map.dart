import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class BusMap extends StatefulWidget {
  const BusMap({super.key});

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> {
  final MapController _mapController = MapController();
  bool _isStopListExpanded = false;
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

  final LatLng _currentBusLocation = const LatLng(23.263991, 77.472503);
// use flutter_map package for map rendering
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentBusLocation,
              initialZoom: 12,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              // load osm tiles
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.vbuss',
              ),
              // draw a black route connecting all stops
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _busStops.map((stop) => stop.location).toList(),
                    strokeWidth: 4.0,
                    color: Colors.black,
                  ),
                ],
              ),
              // marks stops (black if visited, white if not)
              CircleLayer(
                circles: _busStops.map((stop) =>
                    CircleMarker(
                      point: stop.location,
                      radius: 5,
                      borderStrokeWidth: 3.0,
                      color: stop.isVisited
                          ? Colors.black.withOpacity(0.7)
                          : Colors.transparent,
                      borderColor: stop.isVisited ? Colors.black : Colors.white,
                    )
                ).toList(),
              ),
              MarkerLayer(
                markers: [
                  // Bus current location marker
                  Marker(
                    point: _currentBusLocation,
                    width: 25,
                    height: 25,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // zoom controls
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "zoomIn",
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: "zoomOut",
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
          // bottom info card with expandable list
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // expandable stop list
                if (_isStopListExpanded)
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Bus Stops",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _isStopListExpanded = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _busStops.length,
                            itemBuilder: (context, index) {
                              final stop = _busStops[index];
                              return ListTile(
                                leading: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: stop.isVisited ? Colors.green : Colors.white,
                                    border: Border.all(
                                      color: stop.isVisited ? Colors.green : Colors.red,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      stop.id,
                                      style: TextStyle(
                                        color: stop.isVisited ? Colors.white : Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(stop.name),
                                subtitle: Text("BPL→VIT: ${stop.time} | VIT→BPL: ${stop.returnTime}"),
                                onTap: () {
                                  _mapController.move(stop.location, 14);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                // main info card
                Card(
                  elevation: 4,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Next Stop: ${_getNextStop().name}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Estimated Time: ${_getEstimatedTime()} minutes"),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(_isStopListExpanded ? Icons.expand_more : Icons.expand_less),
                              onPressed: () {
                                setState(() {
                                  _isStopListExpanded = !_isStopListExpanded;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _getRouteProgress(),
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          minHeight: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// return the first unvisited stop or the last stop if all visited
  BusStop _getNextStop() {
    for (final stop in _busStops) {
      if (!stop.isVisited) {
        return stop;
      }
    }
    return _busStops.last;
  }

  String _getEstimatedTime() {
    // replace with actual calculation based on distance and speed
    return "2";
  }
  // calculate the fraction of visited stops
  double _getRouteProgress() {
    int visitedStops = _busStops.where((stop) => stop.isVisited).length;
    return visitedStops / _busStops.length;
  }
}

// model for bus stop
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