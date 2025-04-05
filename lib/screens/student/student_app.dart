import 'package:flutter/material.dart';
import 'package:vbuss/screens/student/seat_booking_screen.dart';
import 'package:vbuss/screens/common/profile_screens.dart';
import 'package:vbuss/screens/common/map.dart';
import 'package:vbuss/screens/common/inbox.dart';
import 'package:vbuss/screens/student/notifications.dart'; 

class StudentApp extends StatefulWidget {
  final String userType;

  const StudentApp({super.key, required this.userType});

  @override
  _StudentAppState createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  int _selectedIndex = 0; //manage tab selection

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    //set up the screen widgets list using userType for Seat Booking
    _screens = [
      const BusMap(),
      const InboxScreen(isConductor: false),
      SeatBookingScreen(userType: widget.userType),
      const StudentProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  // for alerts in the home screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Stack(
        children: [
          _screens[_selectedIndex],
          if (_selectedIndex == 0)
            Positioned(
              top: 40,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.event_seat), label: 'My Seat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}