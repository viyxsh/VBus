import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vbuss/models/bus_stop.dart';

class BusStopsList extends StatelessWidget {
  final List<BusStop> busStops;
  final Function(LatLng) onStopTap;
  final VoidCallback onClose;

  const BusStopsList({
    Key? key,
    required this.busStops,
    required this.onStopTap,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: busStops.length,
              itemBuilder: (context, index) {
                final stop = busStops[index];
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
                  onTap: () => onStopTap(stop.location),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}