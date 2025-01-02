import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  double _getProfileCompletionPercentage() {
    int totalFields = 14; // Total number of profile fields
    int completedFields = 0;
    
    if (_nameController.text.isNotEmpty) completedFields++;
    if (_selectedDate != null) completedFields++;
    if (_phoneMobileController.text.isNotEmpty) completedFields++;
    if (_phoneHomeController.text.isNotEmpty) completedFields++;
    if (_emailPersonalController.text.isNotEmpty) completedFields++;
    if (_emailWorkController.text.isNotEmpty) completedFields++;
    if (_addressController.text.isNotEmpty) completedFields++;
    if (_companyController.text.isNotEmpty) completedFields++;
    if (_jobTitleController.text.isNotEmpty) completedFields++;
    if (_discordController.text.isNotEmpty) completedFields++;
    if (_telegramController.text.isNotEmpty) completedFields++;
    if (_linkedinController.text.isNotEmpty) completedFields++;
    if (_websiteController.text.isNotEmpty) completedFields++;
    if (_skills.isNotEmpty) completedFields++;
    
    return (completedFields / totalFields) * 100;
  }

  @override
  Widget build(BuildContext context) {
    double completionPercentage = _getProfileCompletionPercentage();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('Profile', 
          style: TextStyle(
            color: Colors.black, 
            fontSize: 24,
            fontWeight: FontWeight.w600
          )
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            color: const Color(0xFFF4845F),
            onPressed: _showQRScanner,
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            color: const Color(0xFFF4845F),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) _saveProfileData();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header with Completion Status
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF4845F),
                            width: 3,
                          ),
                        ),
                        child: CircularProgressIndicator(
                          value: completionPercentage / 100,
                          backgroundColor: Colors.grey[200],
                          color: const Color(0xFFF4845F),
                          strokeWidth: 3,
                        ),
                      ),
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(_getAvatarUrl()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _isEditing
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter your name',
                            border: UnderlineInputBorder(),
                          ),
                        ),
                      )
                    : Text(
                        _nameController.text,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4845F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${completionPercentage.toInt()}% Complete',
                      style: const TextStyle(
                        color: Color(0xFFF4845F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Basic Contact Information
                  _buildModernSectionCard(
                    'Contact Information',
                    const Icon(Icons.contact_phone_outlined, color: Color(0xFFF4845F)),
                    [
                      _buildModernInfoRow('Mobile Phone', _phoneMobileController, icon: Icons.phone_android),
                      _buildModernInfoRow('Home Phone', _phoneHomeController, icon: Icons.phone),
                      _buildModernInfoRow('Personal Email', _emailPersonalController, icon: Icons.email),
                      _buildModernInfoRow('Work Email', _emailWorkController, icon: Icons.email_outlined),
                      _buildModernInfoRow('Address', _addressController, icon: Icons.location_on),
                    ],
                  ),

                  // Skills Section
                  _buildSkillsSection(),

                  // Professional Information
                  _buildModernSectionCard(
                    'Professional',
                    const Icon(Icons.work_outline, color: Color(0xFFF4845F)),
                    [
                      _buildModernInfoRow('Company', _companyController, icon: Icons.business),
                      _buildModernInfoRow('Job Title', _jobTitleController, icon: Icons.work),
                    ],
                  ),

                  // Social Media Links
                  _buildModernSectionCard(
                    'Social Media',
                    const Icon(Icons.share_outlined, color: Color(0xFFF4845F)),
                    [
                      _buildModernInfoRow('LinkedIn', _linkedinController, 
                          icon: Icons.link,
                          prefix: 'linkedin.com/'),
                      _buildModernInfoRow('Discord', _discordController, 
                          icon: Icons.discord,
                          prefix: '@'),
                      _buildModernInfoRow('Telegram', _telegramController, 
                          icon: Icons.telegram,
                          prefix: '@'),
                      _buildModernInfoRow('Website', _websiteController, 
                          icon: Icons.language),
                    ],
                  ),

                  // Date of Birth
                  _buildModernSectionCard(
                    'Personal Information',
                    const Icon(Icons.person_outline, color: Color(0xFFF4845F)),
                    [
                      _buildModernInfoRow('Date of Birth', _dobController, 
                        onTap: () => _selectDate(context),
                        icon: Icons.calendar_today
                      ),
                    ],
                  ),

                  // Sign Out Button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
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
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSectionCard(String title, Icon icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(String label, TextEditingController controller, 
      {VoidCallback? onTap, IconData? icon, String? prefix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _isEditing
            ? InkWell(
                onTap: onTap,
                child: TextField(
                  controller: controller,
                  enabled: onTap == null,
                  decoration: InputDecoration(
                    prefixIcon: icon != null ? Icon(icon, color: Colors.grey[400]) : null,
                    prefixText: prefix,
                    prefixStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF4845F)),
                    ),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.grey[400], size: 20),
                      const SizedBox(width: 12),
                    ],
                    if (prefix != null && controller.text.isNotEmpty)
                      Text(
                        prefix,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    Text(
                      controller.text.isEmpty ? 'Not set' : controller.text,
                      style: TextStyle(
                        fontSize: 16,
                        color: controller.text.isEmpty ? Colors.grey : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.psychology_outlined, color: Color(0xFFF4845F)),
                SizedBox(width: 12),
                Text(
                  'Skills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_skills.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[400]),
                        const SizedBox(width: 12),
                        Text(
                          _isEditing ? 'Add your skills below' : 'No skills added yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_skills.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skills.map((skill) => Chip(
                      label: Text(skill),
                      backgroundColor: const Color(0xFFF4845F).withOpacity(0.1),
                      labelStyle: const TextStyle(
                        color: Color(0xFFF4845F),
                        fontWeight: FontWeight.w500,
                      ),
                      deleteIcon: _isEditing ? const Icon(Icons.close, size: 18) : null,
                      onDeleted: _isEditing ? () {
                        setState(() => _skills.remove(skill));
                      } : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    )).toList(),
                  ),
                if (_isEditing) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newSkillController,
                          decoration: InputDecoration(
                            hintText: 'Add new skill',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFF4845F)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFFF4845F), size: 32),
                        onPressed: () {
                          if (_newSkillController.text.isNotEmpty) {
                            setState(() {
                              _skills.add(_newSkillController.text);
                              _newSkillController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
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