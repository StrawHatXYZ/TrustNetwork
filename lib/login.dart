import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  _PhoneLoginScreenState createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController(text: '+91 ');
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _otpSent = false;
  bool _phoneVerified = false;
  String _verificationId = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _initialized = false;
  bool _error = false;
  DateTime? _lastOtpSentTime;
  bool _nameExists = false;

  // Add these color constants at the beginning of the class
  final Color primaryColor = const Color(0xFFF4845F);
  final Color blackColor = Colors.black;
  final Color whiteColor = Colors.white;

  @override
  void initState() {
    super.initState();
    initializeFirebase();
    // Remove the checkCurrentUser() call from here
  }

  // Remove or comment out the checkCurrentUser method entirely

  void initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      setState(() {
        _initialized = true;
      });
    } catch(e) {
      setState(() {
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if(_error) {
      return _buildErrorScreen();
    }

    if(!_initialized) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              _buildLogo(),
              const SizedBox(height: 48),
              _buildTitle(),
              const SizedBox(height: 24),
              if (!_otpSent) _buildPhoneInput(),
              if (_otpSent && !_phoneVerified) ...[
                const SizedBox(height: 16),
                _buildOtpInput(),
              ],
              if (_phoneVerified) ...[
                const SizedBox(height: 16),
                _buildNameInput(),
              ],
              const SizedBox(height: 24),
              _buildActionButton(),
              if (_otpSent && !_phoneVerified) _buildResendButton(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return const Scaffold(
      body: Center(
        child: Text('Error initializing Firebase'),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildLogo() {
    return Icon(
      Icons.phone_android,
      size: 80,
      color: primaryColor,
    );
  }

  Widget _buildTitle() {
    return Text(
      'Login with Phone',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: blackColor),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '+91 XXXXXXXXXX',
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12.0, right: 8.0),
              child: Text('🇮🇳', style: TextStyle(fontSize: 24)),
            ),
            Icon(Icons.phone, color: primaryColor),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: whiteColor,
        labelStyle: TextStyle(color: blackColor),
      ),
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildOtpInput() {
    return TextFormField(
      controller: _otpController,
      decoration: InputDecoration(
        labelText: 'OTP',
        hintText: 'Enter the 6-digit OTP',
        prefixIcon: Icon(Icons.lock, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: whiteColor,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }

  Widget _buildNameInput() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Your Name',
        hintText: 'Enter your name',
        prefixIcon: Icon(Icons.person, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: whiteColor,
      ),
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton(
      onPressed: _handleActionButtonPress,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        _getActionButtonText(),
        style: TextStyle(fontSize: 18, color: whiteColor),
      ),
    );
  }

  String _getActionButtonText() {
    if (!_otpSent) return 'Send OTP';
    if (!_phoneVerified) return 'Verify OTP';
    if (_nameExists) return 'Continue';
    return 'Complete Registration';
  }

  Widget _buildResendButton() {
    return TextButton(
      onPressed: _handleResendOtp,
      child: Text('Resend OTP', style: TextStyle(color: primaryColor)),
    );
  }

  void _handleActionButtonPress() {
    if (!_otpSent) {
      if (_canSendOtp()) {
        _verifyPhoneNumber();
        _lastOtpSentTime = DateTime.now();
      } else {
        _showOtpCooldownMessage();
      }
    } else if (!_phoneVerified) {
      _signInWithPhoneNumber();
    } else {
      _saveUserName();
    }
  }

  void _handleResendOtp() {
    if (_canSendOtp()) {
      _verifyPhoneNumber();
      _lastOtpSentTime = DateTime.now();
    } else {
      _showOtpCooldownMessage();
    }
  }

  bool _canSendOtp() {
    return _lastOtpSentTime == null ||
        DateTime.now().difference(_lastOtpSentTime!) > const Duration(minutes: 2);
  }

  void _showOtpCooldownMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please wait before requesting another OTP'),
      ),
    );
  }

  Future<void> _verifyPhoneNumber() async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneController.text,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);

          // Navigate to the next screen or update UI
        },
        verificationFailed: (FirebaseAuthException e) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _otpSent = true;
            _verificationId = verificationId;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _signInWithPhoneNumber() async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text,
      );
      await _auth.signInWithCredential(credential);
      
      // Check if user's name already exists
      final user = _auth.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('registered_users')
            .doc(user.uid)
            .get();
        
        if (userData.exists && userData.data()?['name'] != null) {
          setState(() {
            _nameExists = true;
            _nameController.text = userData.data()!['name'];
          });
        }
      }
      
      setState(() {
        _phoneVerified = true;
      });
      
      if (_nameExists) {
        _saveUserName();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone verified. Please enter your name.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to verify OTP: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveUserName() async {
    if (!_nameExists && _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _storeUserData(user.uid, _phoneController.text, _nameController.text);
        await _storeUserDataLocally(_phoneController.text, _nameController.text);
        // Navigate to the home page only after storing user data
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save name: ${e.toString()}')),
      );
    }
  }

  Future<void> _storeUserData(String userId, String phoneNumber, String name) async {
    try {
      await FirebaseFirestore.instance.collection('registered_users').doc(userId).set({
        'phoneNumber': phoneNumber,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('User data stored successfully in Firestore');
    } catch (e) {
      print('Error storing user data in Firestore: $e');
      throw e;
    }
  }

  Future<void> _storeUserDataLocally(String phoneNumber, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', phoneNumber);
      await prefs.setString('user_name', name);
      print('User data stored successfully in local storage');
    } catch (e) {
      print('Error storing user data in local storage: $e');
      throw e;
    }
  }
}
