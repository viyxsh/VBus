import 'package:flutter/material.dart';

import '../../../../core/widgets/floating_nav_bar.dart';
import '../../inbox/screens/passenger_inbox_screen.dart';
import '../../profile/screens/passenger_profile_screen.dart';
import '../../seat_booking/screens/passenger_seat_screen.dart';
import '../widgets/passenger_map_tab.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  int _currentIndex = 0;
  final Set<int> _built = {0};

  static const List<Widget> _tabs = [
    PassengerMapTab(),
    PassengerInboxScreen(),
    PassengerSeatScreen(),
    PassengerProfileScreen(),
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
      linePath: 'assets/icons/seat_line.svg',
      boldPath: 'assets/icons/seat_bold.svg',
      label: 'Seat',
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
