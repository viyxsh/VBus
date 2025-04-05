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

    if (user == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }
    // if a user is logged in then query the users collection in Firestore using UID to check if their profile exists
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      // if the user document doesn’t exist then check the email domain
      // redirect to the profile setup page if the email ends with @vitbhopal.ac.in otherwise to the cond profile setup
      if (!mounted) return;

      if (!userDoc.exists) {
        if (user.email != null && user.email!.endsWith('@vitbhopal.ac.in')) {
          Navigator.of(context).pushReplacementNamed('/studentProfileSetup');
        } else {
          Navigator.of(context).pushReplacementNamed('/conductorProfileSetup');
        }
      }
      // if the user document exists then retrieve the user’s role (student/faculty)
      // redirect to the StudentApp for students/faculty or /conductorHome for others
      else {
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
    }
    // handle errors during status check
    catch (e) {
      print('Error in UserStatusCheck: $e');
      if (!mounted) return;
      if (e.toString().contains('permission-denied')) {
        final String? email = user?.email;
        if (email != null && email.endsWith('@vitbhopal.ac.in')) {
          Navigator.of(context).pushReplacementNamed('/studentProfileSetup');
        } else {
          Navigator.of(context).pushReplacementNamed('/conductorProfileSetup');
        }
      } else {
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