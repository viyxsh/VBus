import 'package:flutter/material.dart';
import 'package:vbuss/screens/conductor/attendance_screen.dart';
import 'package:vbuss/screens/common/profile_screens.dart';
import 'package:vbuss/screens/common/map.dart';
import 'package:vbuss/screens/common/inbox.dart';
import 'package:vbuss/screens/common/google_map.dart';


class ConductorApp extends StatefulWidget {
  const ConductorApp({super.key});

  @override
  _ConductorAppState createState() => _ConductorAppState();
}
class _ConductorAppState extends State<ConductorApp> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    // const BusMap(),
    const GoogleMapScreen(),
    const InboxScreen(isConductor: true),
    const AttendanceScreen(),
    const ConductorProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  // Defines _screens of the 4 screen widgets (Map, Inbox, Attendance, Profile)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.scanner), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}