import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class FriendService {
  static Future<List<Contact>> getFriendContacts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('No user logged in');
    }

    // Get the current user's friends
    final networkDoc = await FirebaseFirestore.instance
        .collection('Network')
        .doc(currentUser.uid)
        .get();

    if (!networkDoc.exists) {
      return [];
    }

    final friendIds = List<String>.from(networkDoc.data()?['friends'] ?? []);

    // Get the registered users' data
    final registeredUsersSnapshot = await FirebaseFirestore.instance
        .collection('registered_users')
        .where(FieldPath.documentId, whereIn: friendIds)
        .get();

    // Get all contacts
    final contacts = await FlutterContacts.getContacts(
        withProperties: true, withPhoto: true);

    // Match friends with contacts
    List<Contact> friendContacts = [];

    for (var userDoc in registeredUsersSnapshot.docs) {
      final userData = userDoc.data();
      final userPhone = userData['phoneNumber'];

      final matchingContact = contacts.firstWhere(
        (contact) => contact.phones.any((phone) => 
          arePhoneNumbersEqual(phone.number, userPhone)
        ),
        orElse: () => Contact(
          displayName: userData['displayName'] ?? 'Unknown',
          phones: [Phone(userPhone)],
        ),
      );

      friendContacts.add(matchingContact);
    }

    return friendContacts;
  }

  static bool arePhoneNumbersEqual(String phone1, String phone2) {
    String cleanPhone1 = phone1.replaceAll(RegExp(r'\D'), '');
    String cleanPhone2 = phone2.replaceAll(RegExp(r'\D'), '');

    if (cleanPhone1.length != cleanPhone2.length) {
      String shorterNumber = cleanPhone1.length < cleanPhone2.length ? cleanPhone1 : cleanPhone2;
      String longerNumber = cleanPhone1.length > cleanPhone2.length ? cleanPhone1 : cleanPhone2;
      return longerNumber.endsWith(shorterNumber);
    }

    return cleanPhone1 == cleanPhone2;
  }
}