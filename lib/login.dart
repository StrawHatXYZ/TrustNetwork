import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'contacts_service.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  _PhoneLoginScreenState createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
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
  bool _isLoading = false;

  // Add these color constants at the beginning of the class
  final Color primaryColor = const Color(0xFFF4845F);
  final Color blackColor = Colors.black;
  final Color whiteColor = Colors.white;

  // Add these variables for the timer
  int _remainingSeconds = 120; // 2 minutes
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    initializeFirebase();
    // Remove the checkCurrentUser() call from here
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

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

  void _startResendTimer() {
    _remainingSeconds = 120;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
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
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  _buildLogo(),
                  const SizedBox(height: 32),
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
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
    return Stack(
      children: [
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: 'XXXXXXXXXX',
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
            prefixText: '+91 ',
            prefixStyle: TextStyle(
              color: blackColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    return Column(
      children: [
        // Instructions text at the top
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Enter verification code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: blackColor,
            ),
          ),
        ),
        // OTP input boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            6,
            (index) => SizedBox(
              width: 50,
              height: 60,
              child: TextFormField(
                autofocus: index == 0, // Automatically focus first box
                onChanged: (value) {
                  // Handle forward movement and OTP update
                  if (value.length == 1) {
                    // Update OTP controller
                    if (_otpController.text.length <= index) {
                      _otpController.text += value;
                    } else {
                      String newOtp = _otpController.text;
                      newOtp = newOtp.substring(0, index) + value + 
                              (index + 1 < newOtp.length ? newOtp.substring(index + 1) : '');
                      _otpController.text = newOtp;
                    }

                    // Move to next field if not last box
                    if (index < 5) {
                      FocusScope.of(context).nextFocus();
                    }
                  }
                  
                  // Handle backspace
                  if (value.isEmpty && index > 0) {
                    // Update OTP controller
                    if (_otpController.text.length > index) {
                      _otpController.text = _otpController.text.substring(0, index) + 
                                          _otpController.text.substring(index + 1);
                    }
                    // Move focus to previous field
                    FocusScope.of(context).previousFocus();
                  }
                },
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: whiteColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: blackColor,
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(1),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                // Add these to improve input behavior
                showCursor: false,
                maxLength: 1,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              ),
            ),
          ),
        ),
        
        // Updated timer section
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            children: [
              Text(
                'Didn\'t receive the code?',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNameInput() {
    // For existing users, show welcome back message
    if (_nameExists) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Welcome back, ${_nameController.text}!',
          style: TextStyle(
            fontSize: 18,
            color: blackColor,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // For new users, show name input field
    return TextFormField(
      controller: _nameController,
      keyboardType: TextInputType.text,
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
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleActionButtonPress,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: primaryColor.withOpacity(0.6),
      ),
      child: _isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(whiteColor),
              ),
            )
          : Text(
              _getActionButtonText(),
              style: TextStyle(fontSize: 18, color: whiteColor),
            ),
    );
  }

  String _getActionButtonText() {
    if (!_otpSent) return 'Send OTP';
    if (!_phoneVerified) return 'Verify OTP';
    return _nameExists ? 'Continue' : 'Complete Registration';
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
    if (_remainingSeconds == 0) {
      _verifyPhoneNumber();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait ${(_remainingSeconds ~/ 60)}:${(_remainingSeconds % 60).toString().padLeft(2, '0')} before requesting another OTP'
          ),
        ),
      );
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
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91 ${_phoneController.text}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
          setState(() {
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _otpSent = true;
            _verificationId = verificationId;
            _isLoading = false;
          });
          _startResendTimer(); // Start the timer when OTP is sent
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          setState(() {
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithPhoneNumber() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text,
      );
      
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        // First set phone as verified to show name input
        setState(() {
          _phoneVerified = true;
        });

        // Then check if user exists
        final userData = await FirebaseFirestore.instance
            .collection('registered_users')
            .doc(user.uid)
            .get();

        setState(() {
          _nameExists = userData.exists && userData.data()?['name'] != null;
          if (_nameExists) {
            _nameController.text = userData.data()!['name'];
          } else {
            _nameController.clear();
          }
          _isLoading = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _nameExists 
                    ? 'Welcome back! Please tap Continue to proceed.'
                    : 'Please enter your name to complete registration.'
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify OTP: ${e.toString()}')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserName() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // For existing users, handle differently
      if (_nameExists) {
        await _storeUserDataLocally(_phoneController.text, _nameController.text);
        
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
        return;
      }

      // Validate name input
      if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Store user data
      await _storeUserData(user.uid, _phoneController.text, _nameController.text);
      await _storeUserDataLocally(_phoneController.text, _nameController.text);
      
      // Navigate to home page
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save name: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _storeUserData(String userId, String phoneNumber, String name) async {
    try {
      final timestamp = FieldValue.serverTimestamp();
      
      // Update registered_users collection with the exact structure shown
      await FirebaseFirestore.instance.collection('registered_users').doc(userId).set({
        'createdAt': timestamp,
        'name': name,
        'phoneNumber': phoneNumber,
        'updatedAt': timestamp,
      });

      // Update profiles collection with all required fields
      await FirebaseFirestore.instance.collection('profiles').doc(userId).set({
        'name': name,
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'phone_mobile': phoneNumber,
        'address': '',
        'company': '',
        'date_of_birth': null,
        'discord': '',
        'email_personal': '',
        'email_work': '',
        'job_title': '',
        'linkedin': '',
        'phone_home': '',
        'skills': [],
        'telegram': '',
        'website': '',
        'userId': userId, // Adding userId for reference
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
