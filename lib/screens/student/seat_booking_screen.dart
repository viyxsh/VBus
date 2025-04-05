import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vbuss/widgets/bus_layouts/bus1_layout.dart';
import 'dart:async';

class SeatBookingScreen extends StatefulWidget {
  final String userType;

  const SeatBookingScreen({super.key, required this.userType});

  @override
  State<SeatBookingScreen> createState() => _SeatBookingScreenState();
}

class _SeatBookingScreenState extends State<SeatBookingScreen> {
  String? selectedSeat;
  Set<String> takenSeats = {'L2', 'R9', 'R15', 'L11'};
  bool isBookingOpen = false;
  String timerText = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadTakenSeats();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final startTime = DateTime(now.year, now.month, now.day, 20, 0); // 8 PM
      final endTime = DateTime(now.year, now.month, now.day, 22, 0);   // 10 PM

      if (now.isBefore(startTime)) {
        // before 8 PM: show time until booking opens
        final duration = startTime.difference(now);
        setState(() {
          isBookingOpen = false;
          timerText = 'Seat selection starts in ${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s';
        });
      } else if (now.isBefore(endTime)) {
        // bw 8 PM and 10 PM: show time remaining for booking
        final duration = endTime.difference(now);
        setState(() {
          isBookingOpen = true;
          timerText = 'Seat selection ends in ${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s';
        });
      } else {
        // after 10 PM: Auto-allocate if no seat selected
        setState(() {
          isBookingOpen = false;
          timerText = 'Seat selection closed';
        });
        _timer?.cancel();
        _autoAllocateSeat();
      }
    });
  }
// fetch booked seats from the bookings collection and update takenSeats
  Future<void> _loadTakenSeats() async {
    final snapshot = await FirebaseFirestore.instance.collection('bookings').get();
    setState(() {
      takenSeats = snapshot.docs.map((doc) => doc['seatNumber'] as String).toSet();
    });
  }
// retrievee booking and user data from Firestore for a given seat number
  Future<Map<String, dynamic>?> _getUserDetails(String seatNumber) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('seatNumber', isEqualTo: seatNumber)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final booking = snapshot.docs.first.data();
      final userId = booking['userId'] as String?;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          return userDoc.data();
        }
      }
    }
    return null;
  }
// confirm booking and update Firestore
  Future<void> _confirmBooking() async {
    if (selectedSeat != null && isBookingOpen) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('bookings').add({
        'seatNumber': selectedSeat,
        'userType': widget.userType,
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        takenSeats.add(selectedSeat!);
        selectedSeat = null;
      });

      // show confirmation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Seat booked successfully!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (!isBookingOpen) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Booking Closed'),
          content: const Text('Booking is only open from 8 PM to 10 PM.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
// auto-allocate a seat if no seat is selected and booking is open
  Future<void> _autoAllocateSeat() async {
    if (selectedSeat == null && !takenSeats.containsAll(allSeats)) {
      final availableSeats = allSeats.where((seat) {
        final isFacultySeat = (seat.startsWith('L') && int.parse(seat.substring(1)) <= 8) ||
            (seat.startsWith('R') && int.parse(seat.substring(1)) <= 18);
        return !takenSeats.contains(seat) &&
            ((isFacultySeat && widget.userType == 'faculty') || (!isFacultySeat && widget.userType == 'student'));
      }).toList();

      if (availableSeats.isNotEmpty) {
        setState(() {
          selectedSeat = availableSeats.first;
        });
        await _confirmBooking();
      }
    }
  }

  void _onSeatSelected(String? seatNumber) {
    setState(() {
      selectedSeat = seatNumber;
    });
  }
// show user details for taken seats
  void _onTakenSeatTapped(String seatNumber) async {
    final userDetails = await _getUserDetails(seatNumber);
    if (userDetails != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Seat $seatNumber Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${userDetails['name'] ?? 'Unknown'}'),
              Text('Reg ID: ${userDetails['regId'] ?? 'Unknown'}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
// render the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("11 - Minal"),
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
        backgroundColor: Colors.grey[200],
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // timer Display
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              timerText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
          // legend for seat types
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                ),
                const Text("Student", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                ),
                const Text("Faculty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: Icon(Icons.clear, size: 20)),
                ),
                const Text("Taken", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Bus1Layout(
                selectedSeat: selectedSeat,
                takenSeats: takenSeats,
                userType: widget.userType,
                onSeatSelected: _onSeatSelected,
                onTakenSeatTapped: _onTakenSeatTapped,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 84,
        child: BottomAppBar(
          elevation: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Text(
                  "Seat: ${selectedSeat == null ? '0/1' : '1/1'}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: GestureDetector(
                    onTap: _confirmBooking,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          "Confirm",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
// list of all seats in the bus
  final List<String> allSeats = [
    'L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7', 'L8', 'L9', 'L10', 'L11', 'L12', 'L13', 'L14', 'L15', 'L16', 'L17', 'L18',
    'R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8', 'R9', 'R10', 'R11', 'R12', 'R13', 'R14', 'R15', 'R16', 'R17', 'R18',
    'R19', 'R20', 'R21', 'R22', 'R23', 'R24', 'R25', 'R26', 'R27', 'R28', 'R29', 'R30',
    'B1', 'B2', 'B3', 'B4', 'B5', 'B6',
  ];
}
// Note: The Bus1Layout widget should be implemented to handle the layout of the bus seats
// - also improve auto-allocate logic to ensure optimal seat selection based on user type
// - current implementation is a basic example and needs refinement