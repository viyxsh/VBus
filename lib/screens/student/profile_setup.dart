import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:vbuss/screens/student/student_app.dart';

class StudentProfileSetup extends StatefulWidget {
  const StudentProfileSetup({Key? key}) : super(key: key);

  @override
  _StudentProfileSetupState createState() => _StudentProfileSetupState();
}
// init state vars for email, name, reg no, etc.
class _StudentProfileSetupState extends State<StudentProfileSetup> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _genderController = TextEditingController();
  final _userTypeController = TextEditingController();
  final _pickupCityController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _busNumberController = TextEditingController();

  bool _isLoading = false;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;
// retrieve user info from fb auth 
  @override
  void initState() {
    super.initState();
    _populateFieldsFromEmail();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regIdController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _genderController.dispose();
    _userTypeController.dispose();
    _pickupCityController.dispose();
    _pickupLocationController.dispose();
    _busNumberController.dispose();
    super.dispose();
  }

  void _populateFieldsFromEmail() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      final String displayName = user.displayName ?? '';
      RegExp regExp = RegExp(r'(.+)\s+(\d+[A-Z]+\d+)$');
      Match? match = regExp.firstMatch(displayName);
      if (match != null && match.groupCount >= 2) {
        _nameController.text = match.group(1)?.trim() ?? '';
        _regIdController.text = match.group(2)?.trim() ?? '';
      } else {
        _nameController.text = displayName;
      }
      _userTypeController.text = 'Student'; 
    }
  }
// pick pfp
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
// upload pfp to fb storage
  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');
      await storageRef.putFile(_profileImage!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String? imageUrl;
      if (_profileImage != null) {
        imageUrl = await _uploadProfileImage();
      }

      String userType = _userTypeController.text.toLowerCase(); // 'student' or 'faculty'
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text,
        'regId': _regIdController.text,
        'email': _emailController.text,
        'contactNumber': _contactController.text,
        'gender': _genderController.text,
        'userType': userType,
        'pickupCity': _pickupCityController.text,
        'pickupLocation': _pickupLocationController.text,
        'busNumber': _busNumberController.text,
        'profileImageUrl': imageUrl,
        'role': userType, 
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StudentApp(userType: userType),
          ),
        );
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
// render UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Setup'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _profileImage != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_profileImage!, fit: BoxFit.cover),
                        )
                            : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: Colors.grey, size: 32),
                              SizedBox(height: 4),
                              Text('profile picture', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                    readOnly: false,
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _regIdController,
                    decoration: const InputDecoration(labelText: 'Emp ID/Reg No', border: OutlineInputBorder()),
                    readOnly: false,
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your ID' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email address', border: OutlineInputBorder()),
                    readOnly: true,
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter your contact number' : value.length != 10 ? 'Please enter a valid 10-digit number' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                    value: _genderController.text.isEmpty ? null : _genderController.text,
                    items: ['Male', 'Female', 'Other'].map((gender) => DropdownMenuItem(value: gender, child: Text(gender))).toList(),
                    onChanged: (value) => _genderController.text = value ?? '',
                    validator: (value) => value == null || value.isEmpty ? 'Please select your gender' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'User Type', border: OutlineInputBorder()),
                    value: _userTypeController.text.isEmpty ? null : _userTypeController.text,
                    items: ['Student', 'Faculty'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (value) => _userTypeController.text = value ?? '',
                    validator: (value) => value == null || value.isEmpty ? 'Please select your user type' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pickupCityController,
                    decoration: const InputDecoration(labelText: 'Pickup City', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your pickup city' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pickupLocationController,
                    decoration: const InputDecoration(labelText: 'Pickup Location', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your pickup location' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _busNumberController,
                    decoration: const InputDecoration(labelText: 'Bus Number', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your bus number' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}