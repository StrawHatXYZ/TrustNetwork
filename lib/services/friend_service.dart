import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class FriendService {

  static Future<List<Contact>> getFriendContacts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('No user logged in');
    }
    final userId = currentUser.uid;
    

    final contacts = await http.get(Uri.parse('https://valut-backend.onrender.com/network/$userId'));
    if (contacts.statusCode == 200) {
      final List<dynamic> contactsJson = jsonDecode(contacts.body);
      
      // Transform the data to match Contact.fromJson expected format
      final transformedContacts = contactsJson.map((contactData) {
        // Transform organizations data
        if (contactData['organizations'] != null) {
          contactData['organizations'] = contactData['organizations'].map((org) => {
            'company': org['name'] ?? '',  // Map 'name' to 'company'
            'title': org['title'] ?? '',
            'label': org['label'] ?? '',
            // Add other required fields with default values
            'department': '',
            'jobDescription': '',
            'symbol': '',
            'phoneticName': '',
            'officeLocation': '',
          }).toList();
        }
        return contactData;
      }).toList();

      return transformedContacts.map((contactData) => 
        Contact.fromJson(Map<String, dynamic>.from(contactData))
      ).toList();
    } else {
      throw Exception('Failed to fetch contacts from Firebase');
    }
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

  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''),
    );
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }
}