import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  final String role; // 'student' or 'conductor'

  const EditProfileScreen({super.key, required this.role});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // common fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // stud-specific fields
  final _regIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _genderController = TextEditingController();
  final _userTypeController = TextEditingController();
  final _pickupCityController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _busNumberController = TextEditingController();

  // cond-specific fields
  final _busRouteController = TextEditingController();

  bool _isLoading = false;
  String? _conductorId; 

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _regIdController.dispose();
    _emailController.dispose();
    _genderController.dispose();
    _userTypeController.dispose();
    _pickupCityController.dispose();
    _pickupLocationController.dispose();
    _busNumberController.dispose();
    _busRouteController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (widget.role == 'student') {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          final userData = docSnapshot.data()!;

          _nameController.text = userData['name'] ?? '';
          _phoneController.text = userData['contactNumber'] ?? '';
          _busNumberController.text = userData['busNumber'] ?? '';
          _regIdController.text = userData['regId'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _genderController.text = userData['gender'] ?? '';
          _userTypeController.text = userData['userType'] ?? '';
          _pickupCityController.text = userData['pickupCity'] ?? '';
          _pickupLocationController.text = userData['pickupLocation'] ?? '';
        }
      } else if (widget.role == 'conductor') {
        // find the conductorId by matching firebaseUid
        final querySnapshot = await FirebaseFirestore.instance
            .collection('conductors')
            .where('firebaseUid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          _conductorId = querySnapshot.docs.first.id; //store the conductorId

          _nameController.text = userData['name'] ?? '';
          _phoneController.text = userData['phoneNumber'] ?? '';
          _busNumberController.text = userData['busNumber'] ?? '';
          _busRouteController.text = userData['busRoute'] ?? '';
        } else {
          throw Exception('Conductor profile not found');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
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

      // create a map for common fields
      final Map<String, dynamic> updateData = {
        'name': _nameController.text,
        'busNumber': _busNumberController.text,
      };

      if (widget.role == 'student') {
        updateData.addAll({
          'regId': _regIdController.text,
          'email': _emailController.text,
          'contactNumber': _phoneController.text,
          'gender': _genderController.text,
          'userType': _userTypeController.text,
          'pickupCity': _pickupCityController.text,
          'pickupLocation': _pickupLocationController.text,
        });

        await user.updateDisplayName(_nameController.text);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updateData);
      } else if (widget.role == 'conductor') {
        if (_conductorId == null) {
          throw Exception('Conductor ID not found');
        }

        updateData.addAll({
          'phoneNumber': _phoneController.text,
          'busRoute': _busRouteController.text,
        });

        await user.updateDisplayName(_nameController.text);
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(_conductorId)
            .update(updateData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
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
        title: const Text('Edit Profile'),
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
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: widget.role == 'conductor' ? 'Phone Number' : 'Contact Number',
                      border: const OutlineInputBorder(),
                      prefixText: widget.role == 'conductor' ? '+91 ' : null,
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.length != 10) {
                        return 'Please enter a valid 10-digit number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _busNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Bus Number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your bus number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  if (widget.role == 'student') ...[
                    TextFormField(
                      controller: _regIdController,
                      decoration: const InputDecoration(
                        labelText: 'Emp ID/Reg No',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      value: _genderController.text.isEmpty ? null : _genderController.text,
                      items: ['Male', 'Female', 'Other']
                          .map((gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _genderController.text = value;
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your gender';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'User Type',
                        border: OutlineInputBorder(),
                      ),
                      value: _userTypeController.text.isEmpty ? null : _userTypeController.text,
                      items: ['Student', 'Faculty']
                          .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _userTypeController.text = value;
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your user type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _pickupCityController,
                      decoration: const InputDecoration(
                        labelText: 'Pickup City',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your pickup city';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _pickupLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Location',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your pickup location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (widget.role == 'conductor') ...[
                    TextFormField(
                      controller: _busRouteController,
                      decoration: const InputDecoration(
                        labelText: 'Bus Route',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Campus - City Center - Mall Road',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your bus route';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Update Profile',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}