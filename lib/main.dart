import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vbuss/screens/auth/login_screen.dart';
import 'package:vbuss/screens/student/student_app.dart';
import 'package:vbuss/screens/conductor/conductor_app.dart';
import 'package:vbuss/screens/splash_screen.dart';
import 'package:vbuss/screens/student/profile_setup.dart';
import 'package:vbuss/screens/conductor/profile_setup.dart';
import 'package:vbuss/screens/common/profile_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/conductorHome': (context) => const ConductorApp(),
        '/studentProfileSetup': (context) => const StudentProfileSetup(),
        '/conductorProfileSetup': (context) => const ConductorProfileSetup(),
        '/studentProfile': (context) => const StudentProfileScreen(),
        '/conductorProfile': (context) => const ConductorProfileScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/checkUserStatus') {
          return MaterialPageRoute(
            builder: (context) => const UserStatusCheck(),
          );
        }
        return null;
      },
    );
  }
}
// define the UserStatusCheck Widget (authentication and role status)
class UserStatusCheck extends StatefulWidget {
  const UserStatusCheck({Key? key}) : super(key: key);

  @override
  _UserStatusCheckState createState() => _UserStatusCheckState();
}

class _UserStatusCheckState extends State<UserStatusCheck> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserStatus();
    });
  }
  // retrieve the current Firebase user and if no user is logged in then redirect to the login screen.
  Future<void> _checkUserStatus() async {
    final User? user = FirebaseAuth.instance.currentUser;

    // If no user is logged in, go to login screen
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    // Check if this is an anonymous user (conductor)
    if (user.isAnonymous) {
      try {
        // Try to find the conductor document by querying the firebaseUid field
        final conductorQuery = await FirebaseFirestore.instance
            .collection('conductors')
            .where('firebaseUid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (!mounted) return;

        if (conductorQuery.docs.isEmpty) {
          // No conductor found with this UID, sign out and go to login
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pushReplacementNamed('/login');
        } else {
          // Conductor found, check if profile is complete
          final conductorDoc = conductorQuery.docs.first;
          if (conductorDoc.data().containsKey('name') &&
              conductorDoc.data().containsKey('phoneNumber') &&
              conductorDoc.data().containsKey('busNumber')) {
            // Profile is complete, go to conductor home
            Navigator.of(context).pushReplacementNamed('/conductorHome');
          } else {
            // Profile is incomplete, go to profile setup
            Navigator.of(context).pushReplacementNamed('/conductorProfileSetup');
          }
        }
        return;
      } catch (e) {
        print('Error checking conductor status: $e');
        if (!mounted) return;
        // On error, sign out and go to login
        await FirebaseAuth.instance.signOut();
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
    }

    // For non-anonymous users (students/faculty with Google sign-in)
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!userDoc.exists) {
        // Profile doesn't exist, check email domain for student/faculty
        if (user.email != null && user.email!.endsWith('@vitbhopal.ac.in')) {
          Navigator.of(context).pushReplacementNamed('/studentProfileSetup');
        } else {
          // Not a valid student email, sign out and go to login
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        // Profile exists, check role
        final String role = userDoc.data()?['role'] ?? '';
        if (role == 'student' || role == 'faculty') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => StudentApp(userType: role),
            ),
          );
        } else {
          Navigator.of(context).pushReplacementNamed('/conductorHome');
        }
      }
    } catch (e) {
      print('Error in UserStatusCheck: $e');
      if (!mounted) return;

      // Handle errors
      if (e.toString().contains('permission-denied')) {
        // Check if valid student email
        final String? email = user.email;
        if (email != null && email.endsWith('@vitbhopal.ac.in')) {
          Navigator.of(context).pushReplacementNamed('/studentProfileSetup');
        } else {
          // Not a valid student email, sign out
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        // Other errors, sign out and go to login
        await FirebaseAuth.instance.signOut();
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}