import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trust/login.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  final TextEditingController _newSkillController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneMobileController = TextEditingController();
  final TextEditingController _phoneHomeController = TextEditingController();
  final TextEditingController _emailPersonalController = TextEditingController();
  final TextEditingController _emailWorkController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _discordController = TextEditingController();
  final TextEditingController _telegramController = TextEditingController();
  final TextEditingController _linkedinController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  List<String> _skills = [];
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    print('User: $user');
    if (user != null) {
      try {
        print('Loading profile data for user: ${user.uid}');
        final docSnapshot = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          print('Profile data: $data');

          setState(() {
            _nameController.text = data['name'] ?? '';
            _selectedDate = data['date_of_birth'] != null
                ? (data['date_of_birth'] as Timestamp).toDate()
                : null;
            _dobController.text = _selectedDate != null
                ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                : '';
            _phoneMobileController.text = user.phoneNumber ?? '';
            _phoneHomeController.text = data['phone_home'] ?? '';
            _emailPersonalController.text = data['email_personal'] ?? '';
            _emailWorkController.text = data['email_work'] ?? '';
            _addressController.text = data['address'] ?? '';
            _companyController.text = data['company'] ?? '';
            _jobTitleController.text = data['job_title'] ?? '';
            _discordController.text = data['discord'] ?? '';
            _telegramController.text = data['telegram'] ?? '';
            _linkedinController.text = data['linkedin'] ?? '';
            _websiteController.text = data['website'] ?? '';
            _skills = List<String>.from(data['skills'] ?? []);
          });
        }
      } catch (e) {
        print('Error loading profile data: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile data: $e')));
      }
    }
  }

  Future<void> _saveProfileData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // Create a batch to perform multiple operations
        final batch = FirebaseFirestore.instance.batch();
        
        // Reference to profile document
        final profileRef = FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid);
        
        // Reference to registered_users document
        final userRef = FirebaseFirestore.instance
            .collection('registered_users')
            .doc(user.uid);
        
        // Update profile document
        batch.set(profileRef, {
          'name': _nameController.text,
          'date_of_birth': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
          'phone_mobile': _phoneMobileController.text,
          'phone_home': _phoneHomeController.text,
          'email_personal': _emailPersonalController.text,
          'email_work': _emailWorkController.text,
          'address': _addressController.text,
          'company': _companyController.text,
          'job_title': _jobTitleController.text,
          'discord': _discordController.text,
          'telegram': _telegramController.text,
          'linkedin': _linkedinController.text,
          'website': _websiteController.text,
          'skills': _skills,
        }, SetOptions(merge: true));
        
        // Update name in registered_users document
        batch.update(userRef, {'name': _nameController.text});
        
        // Commit the batch
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        print('Error saving profile data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile Page'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFFF4845F)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            color: const Color(0xFFF4845F),
            onPressed: _showQRScanner,
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            color: const Color(0xFFF4845F),
            onPressed: () async {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  _saveProfileData();
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(_getAvatarUrl()),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _isEditing
                                ? TextField(
                                    controller: _nameController,
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      border: OutlineInputBorder(),
                                    ),
                                  )
                                : Text(_nameController.text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date of Birth Card
              _buildSectionCard('Date of Birth', [
                _isEditing
                    ? InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dobController.text),
                              const Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20, color: Color(0xFFF4845F)),
                          const SizedBox(width: 8),
                          Text(
                            _dobController.text.isNotEmpty
                                ? _dobController.text
                                : 'Date of Birth not set',
                            style: TextStyle(
                              color: _dobController.text.isNotEmpty 
                                  ? const Color.fromARGB(255, 33, 31, 31) 
                                  : const Color.fromARGB(255, 54, 51, 50),
                              fontStyle: _dobController.text.isNotEmpty 
                                  ? FontStyle.normal 
                                  : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
              ]),
              
              // Contact Information
              _buildSectionCard('Contact Information', [
                _buildInfoRow(Icons.phone, 'Phone (Mobile)', _phoneMobileController),
                _buildInfoRow(Icons.phone, 'Phone (Home)', _phoneHomeController),
                _buildInfoRow(Icons.email, 'Email (Personal)', _emailPersonalController),
                _buildInfoRow(Icons.email, 'Email (Work)', _emailWorkController),
              ]),
              
              // Skills
              _buildSectionCard('Skills', [
                if (_skills.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0,horizontal:12),
                    child: Text(
                      _isEditing ? 'Add your skills below' : 'No skills added yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skills.map((skill) => Chip(
                      label: Text(skill),
                      deleteIcon: _isEditing ? const Icon(Icons.close, size: 18) : null,
                      onDeleted: _isEditing ? () {
                        setState(() {
                          _skills.remove(skill);
                        });
                      } : null,
                    )).toList(),
                  ),
                if (_isEditing) 
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newSkillController,
                            decoration: const InputDecoration(
                              hintText: 'Add new skill',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            if (_newSkillController.text.isNotEmpty) {
                              setState(() {
                                _skills.add(_newSkillController.text);
                                _newSkillController.clear();
                              });
                            }
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),
                  ),
              ]),
              
              // Address
              _buildSectionCard('Address', [
                _buildInfoRow(Icons.location_on, 'Address', _addressController),
              ]),
              
              // Company
              _buildSectionCard('Company', [
                _buildInfoRow(Icons.business, 'Company', _companyController),
                _buildInfoRow(Icons.work, 'Job Title', _jobTitleController),
              ]),
              
              // Social Media
              _buildSectionCard('Social Media', [
                _buildInfoRow(Icons.discord, 'Discord', _discordController),
                _buildInfoRow(Icons.telegram, 'Telegram', _telegramController),
                _buildInfoRow(Icons.work, 'LinkedIn', _linkedinController),
                _buildInfoRow(Icons.language, 'Website', _websiteController),
              ]),

              // Logout Button
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        // Navigate to login page and remove all previous routes
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    } catch (e) {
                      print('Error signing out: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error signing out: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4845F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFF4845F)),
          const SizedBox(width: 8),
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: controller,
                    decoration: InputDecoration(labelText: label),
                  )
                : Text('$label: ${controller.text}'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    _nameController.dispose();
    _dobController.dispose();
    _phoneMobileController.dispose();
    _phoneHomeController.dispose();
    _emailPersonalController.dispose();
    _emailWorkController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _discordController.dispose();
    _telegramController.dispose();
    _linkedinController.dispose();
    _websiteController.dispose();
    _newSkillController.dispose();
    super.dispose();
  }

  String _getAvatarUrl() {
    return 'https://ui-avatars.com/api/?background=0D8ABC&color=fff&name=${Uri.encodeComponent(_nameController.text)}&rounded=true';
  }

  Future<void> _onQRCodeScanned(String qrData) async {
    try {
      final data = jsonDecode(qrData);
      if (data['type'] != 'auth') {
        throw Exception('Invalid QR code type');
      }
      
      final sessionId = data['sessionId'];
      print("SessionId: $sessionId");
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      await FirebaseFirestore.instance
          .collection('authSessions')
          .doc(sessionId)
          .set({
        'status': 'authenticated',
        'userId': user.uid,
        'lastUpdated': FieldValue.serverTimestamp(),
        'authenticatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully authenticated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e')),
        );
      }
    }
  }

  void _showQRScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Scan QR Code', style: TextStyle(color: Colors.black)),
              centerTitle: true,
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? qrData = barcodes.first.rawValue;
                    print("QR Data: $qrData");
                    if (qrData != null) {
                      Future.delayed(Duration.zero, () {
                        if (mounted) {
                          Navigator.pop(context);
                          _onQRCodeScanned(qrData);
                        }
                      });
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}