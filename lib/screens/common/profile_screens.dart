import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../common/edit_profile_screen.dart'; 
import 'package:vbuss/widgets/profile_option.dart';

// prof screen for stud 
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});
  // handle sign out
  Future _signOut(BuildContext context) async {
    final bool confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmLogout) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      Navigator.pop(context);
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: ${e.toString()}')),
      );
    }
  }
  // fetch stud name from firestore and render ui
  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.grey[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    backgroundImage: currentUser?.photoURL != null
                        ? NetworkImage(currentUser!.photoURL!)
                        : null,
                    child: currentUser?.photoURL == null
                        ? const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentUser?.displayName ?? 'Student User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currentUser?.email ?? 'No email available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ProfileOption(
                    icon: Icons.edit,
                    title: "Edit Profile",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                          const EditProfileScreen(role: 'student'), 
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ProfileOption(
                    icon: Icons.notifications,
                    title: "Notifications",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                          Text("Notifications functionality will be implemented here"),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ProfileOption(
                    icon: Icons.bar_chart,
                    title: "Statistics",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                          Text("Statistics functionality will be implemented here"),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ProfileOption(
                    icon: Icons.help_outline,
                    title: "Help & Support",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                          Text("Help & Support functionality will be implemented here"),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ProfileOption(
                    icon: Icons.info_outline,
                    title: "About",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                          Text("About functionality will be implemented here"),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ProfileOption(
                    icon: Icons.logout,
                    title: "Log out",
                    onTap: () => _signOut(context),
                    textColor: Colors.red,
                    iconColor: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// prof screen for cond 
class ConductorProfileScreen extends StatelessWidget {
  const ConductorProfileScreen({super.key});
  // handle sign out
  Future _signOut(BuildContext context) async {
    final bool confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmLogout) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseAuth.instance.signOut();
      Navigator.pop(context);
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: ${e.toString()}')),
      );
    }
  }

  Future<String?> _fetchConductorName() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('conductors')
        .where('firebaseUid', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data()['name'] ?? 'Conductor User';
    }
    return 'Conductor User';
  }
  // fetch cond name from firestore and render ui
  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.grey[100],
      ),
      body: FutureBuilder<String?>(
        future: _fetchConductorName(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final displayName = snapshot.data ?? 'Conductor User';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue,
                        backgroundImage: currentUser?.photoURL != null
                            ? NetworkImage(currentUser!.photoURL!)
                            : null,
                        child: currentUser?.photoURL == null
                            ? const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        currentUser?.email ?? 'No email available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ProfileOption(
                        icon: Icons.edit,
                        title: "Edit Profile",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const EditProfileScreen(role: 'conductor'), 
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ProfileOption(
                        icon: Icons.notifications,
                        title: "Notifications",
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Notifications functionality will be implemented here"),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ProfileOption(
                        icon: Icons.logout,
                        title: "Log out",
                        onTap: () => _signOut(context),
                        textColor: Colors.red,
                        iconColor: Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}