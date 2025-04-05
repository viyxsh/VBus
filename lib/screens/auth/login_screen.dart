import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // track whether the stud or cond login is active
  bool isStudentSelected = true;
  // create selectable boxes for account types
  Widget _buildAccountBox({
    required bool isSelected,
    required VoidCallback onTap,
    required String iconPath,
    required String label,
  }) {
    // return gd with a styled container, SVG icon, and text label
    // highlight the selected box with a blue border and bold text.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            SvgPicture.asset(
              iconPath,
              height: 50,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // render main login screen UI
  // display app bar and column for choosing acc type
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Choose Account Type',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // show two acc boxes side by side cond/driv and stud/emp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAccountBox(
                isSelected: !isStudentSelected,
                onTap: () => setState(() => isStudentSelected = false),
                iconPath: 'icons/condriv-final.svg',
                label: 'Conductor/Driver',
              ),
              _buildAccountBox(
                isSelected: isStudentSelected,
                onTap: () => setState(() => isStudentSelected = true),
                iconPath: 'icons/studemp-final.svg',
                label: 'Student/Employee',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: isStudentSelected ? StudentLoginPage() : ConductorLoginPage(),
          ),
        ],
      ),
    );
  }
}

// stud login - Google sign in process
class StudentLoginPage extends StatelessWidget {
  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // initialize Google Sign In
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

        // if user cancels the sign-in process remove loading dialog
        if (googleUser == null) {
          Navigator.of(context).pop();
          return;
        }

        // check if the email domain is valid
        if (!googleUser.email.endsWith('@vitbhopal.ac.in')) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please use your @vitbhopal.ac.in email address'),
            ),
          );
          await GoogleSignIn().signOut(); // sign out the invalid user
          return;
        }

        // get auth details from Google Sign In
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // create credential for Firebase
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credential
        final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final User? user = userCredential.user;

        // Check if user profile exists in Firestore
        if (user != null) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            // remove loading dialog before navigation
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }

            // use Future.microtask to schedule navigation after the current build phase
            Future.microtask(() {
              // if user profile doesn't exist navigate to prof setup
              if (!userDoc.exists) {
                Navigator.of(context).pushReplacementNamed('/studentProfileSetup');
              } else {
                // if prof exists, navigate to home
                Navigator.of(context).pushReplacementNamed('/studentHome');
              }
            });
          } catch (firestoreError) {
            // remove loading dialog
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            print('Firestore error: $firestoreError');

            // handle Firestore errors
            if (firestoreError.toString().contains('permission-denied')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Authentication successful, but profile access failed. Please check Firestore rules.'),
                ),
              );
              // use Future.microtask to schedule navigation after the current build phase
              Future.microtask(() {
                Navigator.of(context).pushReplacementNamed('/studentProfileSetup');
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error accessing user profile: ${firestoreError.toString()}'),
                ),
              );
            }
          }
        }
      } catch (e) {
        // remove loading dialog if it's still showing
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        print('Sign-in error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing in: ${e.toString()}'),
          ),
        );
      }
    } catch (e) {
      print('Outer error: $e');
      // catch any errors that might occur showing the dialog
    }
  }
  // render stud login UI
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign in with your university Google account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _signInWithGoogle(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.white,
                  child: SvgPicture.asset(
                    'icons/google.svg',
                    height: 25,
                    width: 25,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Sign in with Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConductorLoginPage extends StatelessWidget {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _loginConductor(BuildContext context) async {
    String conductorId = idController.text.trim();
    String password = passwordController.text.trim();

    // loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // sign in anonymously
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      String? uid = userCredential.user?.uid;

      // check credentials in Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .get();

      if (doc.exists && doc['password'] == password) {
        // update login details
        await FirebaseFirestore.instance.collection('conductors').doc(conductorId).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'firebaseUid': uid,
        });

        Navigator.of(context).pop(); // Remove loading dialog
        Navigator.of(context).pushReplacementNamed('/conductorHome');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful')),
        );
      } else {
        // sign out if credentials are invalid
        await FirebaseAuth.instance.signOut();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid ID or password')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  // render cond login UI
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Conductor Login',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter your Conductor ID and Password',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'Conductor ID (e.g., C001)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _loginConductor(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}