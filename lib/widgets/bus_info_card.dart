import 'package:flutter/material.dart';
import '../models/bus_stop.dart';

class BusInfoCard extends StatelessWidget {
  final BusStop nextStop;
  final String estimatedTime;
  final double routeProgress;
  final VoidCallback onToggleStopsList;
  final bool isStopListExpanded;

  const BusInfoCard({
    Key? key,
    required this.nextStop,
    required this.estimatedTime,
    required this.routeProgress,
    required this.onToggleStopsList,
    required this.isStopListExpanded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
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
                        "Next Stop: ${nextStop.name}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text("Estimated Time: $estimatedTime minutes"),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isStopListExpanded ? Icons.expand_more : Icons.expand_less),
                  onPressed: onToggleStopsList,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: routeProgress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 5,
            ),
          ],
        ),
      ),
    );
  }
}