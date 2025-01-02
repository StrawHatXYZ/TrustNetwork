import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  String _userName = '';
  String _userPhone = '';
  String _userId = '';
  bool _isLoading = true;

  String get userName => _userName;
  String get userPhone => _userPhone;
  String get userId => _userId;
  bool get isLoading => _isLoading;

  Future<void> loadUserData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('registered_users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        _userName = userDoc.data()?['name'] ?? '';
        _userPhone = userDoc.data()?['phoneNumber'] ?? '';
        _userId = user.uid;

        // Save to SharedPreferences for offline access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _userName);
        await prefs.setString('user_phone', _userPhone);
        await prefs.setString('user_id', _userId);
      } else {
        // Try to get from SharedPreferences if Firestore fails
        final prefs = await SharedPreferences.getInstance();
        _userName = prefs.getString('user_name') ?? '';
        _userPhone = prefs.getString('user_phone') ?? '';
        _userId = prefs.getString('user_id') ?? '';
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserData({String? name, String? phone}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final updates = <String, dynamic>{};
      if (name != null) {
        _userName = name;
        updates['name'] = name;
      }
      if (phone != null) {
        _userPhone = phone;
        updates['phoneNumber'] = phone;
      }

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('registered_users')
            .doc(user.uid)
            .update(updates);

        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        if (name != null) await prefs.setString('user_name', name);
        if (phone != null) await prefs.setString('user_phone', phone);

        notifyListeners();
      }
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }

  void clearUserData() async {
    _userName = '';
    _userPhone = '';
    _userId = '';
    
    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_id');
    
    notifyListeners();
  }
}