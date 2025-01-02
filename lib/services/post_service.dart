import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getPosts() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error loading posts: $e');
      return [];
    }
  }

  Future<void> createPost(String content, String username, String jobTitle, String company, String location, String skills) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to post');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? userName = prefs.getString('user_name');
      String? userPhone = prefs.getString('user_phone');

      // If userName or userPhone is null, fetch from Firestore
      if (userName == null || userPhone == null) {
        final userDoc = await _firestore
            .collection('registered_users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          userName = userData?['name'] ?? 'Unknown';
          userPhone = userData?['phoneNumber'] ?? '';

          // Save to SharedPreferences for future use
          await prefs.setString('user_name', userName ?? '');
          await prefs.setString('user_phone', userPhone ?? '');
        }
      }

      final initials = userName != null && userName.isNotEmpty
          ? userName.trim().split(' ').map((name) => name[0]).join('').toUpperCase()
          : '';

      await _firestore.collection('posts').add({
        'username': userName,
        'content': content,
        'phone': userPhone,
        'user_id': user.uid,
        'job_title': jobTitle,
        'company': company,
        'location': location,
        'skills': skills,
        'avatar_url': 'https://ui-avatars.com/api/?background=0D8ABC&color=fff&name=$initials&rounded=true',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }
}