import 'package:flutter/material.dart';

import '../../../../core/widgets/floating_nav_bar.dart';
import '../../attendance/screens/conductor_attendance_screen.dart';
import '../../inbox/screens/conductor_inbox_screen.dart';
import '../../profile/screens/conductor_profile_screen.dart';
import '../widgets/conductor_map_tab.dart';

class ConductorHomeScreen extends StatefulWidget {
  const ConductorHomeScreen({super.key});

  @override
  State<ConductorHomeScreen> createState() => _ConductorHomeScreenState();
}

class _ConductorHomeScreenState extends State<ConductorHomeScreen> {
  int _currentIndex = 0;
  final Set<int> _built = {0};

  static const List<Widget> _tabs = [
    ConductorMapTab(),
    ConductorInboxScreen(),
    ConductorAttendanceScreen(),
    ConductorProfileScreen(),
  ];

  static const _navItems = [
    NavItem(
      linePath: 'assets/icons/home_line.svg',
      boldPath: 'assets/icons/home_bold.svg',
      label: 'Home',
    ),
    NavItem(
      linePath: 'assets/icons/inbox_line.svg',
      boldPath: 'assets/icons/inbox_bold.svg',
      label: 'Inbox',
    ),
    NavItem(
      linePath: 'assets/icons/attendance_line.svg',
      boldPath: 'assets/icons/attendance_bold.svg',
      label: 'Attendance',
    ),
    NavItem(
      linePath: 'assets/icons/profile_line.svg',
      boldPath: 'assets/icons/profile_bold.svg',
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_tabs.length, (i) {
          if (!_built.contains(i)) return const SizedBox.shrink();
          return _tabs[i];
        }),
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() {
          _currentIndex = i;
          _built.add(i);
        }),
        items: _navItems,
      ),
    );
  }
}
