import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ContactService {
  static const String _contactsKey = 'contacts';
  static bool? _hasPermission;
  static bool _isInitialized = false;

  // Check permission without requesting
  static Future<bool> checkPermissionStatus() async {
    try {
      // If we already know the permission status, return it
      if (_hasPermission != null) {
        return _hasPermission!;
      }
      // If we don't know, request it
      _hasPermission = await FlutterContacts.requestPermission();
      _isInitialized = true;
      return _hasPermission ?? false;
    } catch (e) {
      print('Error checking permission status: $e');
      return false;
    }
  }

  // Request permission only once
  static Future<bool> requestInitialPermission() async {
    try {
      // Only request if we haven't initialized
      if (!_isInitialized) {
        _hasPermission = await FlutterContacts.requestPermission();
        _isInitialized = true;
      }
      return _hasPermission ?? false;
    } catch (e) {
      print('Error requesting permissions: $e');
      _hasPermission = false;
      return false;
    }
  }

  // Safe method to get contacts
  static Future<List<Contact>> getContacts() async {
    try {
      // If we're not initialized or don't have permission, request it once
      if (!_isInitialized || _hasPermission != true) {
        bool hasPermission = await requestInitialPermission();
        if (!hasPermission) {
          return [];
        }
      }
      _hasPermission = true;
      return await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Contacts fetch timed out');
          return [];
        },
      );
    } catch (e) {
      print('Error getting contacts: $e');
      return [];
    }
  }

  static Future<List<Contact>> _fetchAndStoreDeviceContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: true);
      await _storeContactsLocally(contacts);
      return contacts;
    } else {
      throw Exception('Contact permission denied');
    }
  }

  static Future<void> _storeContactsLocally(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = jsonEncode(contacts.map((contact) => _contactToJson(contact)).toList());
    await prefs.setString(_contactsKey, contactsJson);
    print('Contacts stored locally. JSON length: ${contactsJson.length}');
    
    // Verify storage
    final storedJson = prefs.getString(_contactsKey);
    if (storedJson == contactsJson) {
      print('Contacts successfully stored in SharedPreferences');
    } else {
      print('Error: Stored contacts do not match the original data');
    }
  }

  static Map<String, dynamic> _contactToJson(Contact contact) {
    final json = contact.toJson();
    // Remove photo and thumbnail from JSON as they can't be easily serialized
    json.remove('photo');
    json.remove('thumbnail');
    return json;
  }

  static Future<void> refreshContacts() async {
    await _fetchAndStoreDeviceContacts();
  }

  static Future<void> clearStoredContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contactsKey);
  }

  static Future<String?> getNameByPhoneNumber(String phoneNumber) async {
    final contacts = await getContacts();
    final cleanedPhoneNumber = _cleanPhoneNumber(phoneNumber);

    for (final contact in contacts) {
      for (final phone in contact.phones) {
        if (_cleanPhoneNumber(phone.number) == cleanedPhoneNumber) {
          return contact.displayName;
        }
      }
    }

    return null; // Return null if no matching contact is found
  }

  static String _cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'\D'), '');
  }

  static Future<void> updateContact(Contact updatedContact) async {
    try {
        final firestore = FirebaseFirestore.instance;
        final userId = await getCurrentUserId();
        
        // Check if document exists first
        final docRef = firestore
            .collection('registered_users')
            .doc(userId)
            .collection('contacts')
            .doc(updatedContact.id);
            
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
            throw Exception('Contact does not exist in Firebase');
        }

        // Proceed with update since document exists
        final contactData = _contactToJson(updatedContact);
        await docRef.set({
            ...contactData,
            'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
            
        print('Contact updated successfully in Firebase');
    } catch (e) {
        print('Error updating contact in Firebase: $e');
        throw Exception('Failed to update contact in Firebase: $e');
    }
  }

  static Future<Contact> getContact(String id) async {
    if (await FlutterContacts.requestPermission()) {
      final contact = await FlutterContacts.getContact(id);
      if (contact == null) {
        throw Exception('Contact not found');
      }
      return contact;
    } else {
      throw Exception('Permission denied');
    }
  }

  static Future<void> storeContactsInFirebase(String userId) async {
    try {
      final contacts = await getContacts();
      final firestore = FirebaseFirestore.instance;
      final contactsCollection = firestore
          .collection('registered_users')
          .doc(userId)
          .collection('contacts');
          
      // First, get existing contacts from Firebase
      final existingContacts = await contactsCollection.get();
      final existingContactsMap = {
        for (var doc in existingContacts.docs)
          _getContactPhoneNumber(doc.data()): doc.id
      };

      final batch = firestore.batch();
      int updatedCount = 0;

      for (final contact in contacts) {
        // Skip contacts without phone numbers
        if (contact.phones.isEmpty) continue;
        
        final contactPhone = contact.phones.first.number;
        final contactData = _contactToJson(contact);
        
        // Check if a contact with this phone number already exists
        bool isDuplicate = existingContactsMap.keys.any((existingPhone) => 
          arePhoneNumbersEqual(existingPhone, contactPhone));
        
        if (!isDuplicate) {
          final docRef = contactsCollection.doc(contact.id);
          batch.set(docRef, { 
            ...contactData,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          updatedCount++;
        }
      }

      // Only commit if there are new contacts
      if (updatedCount > 0) {
        await batch.commit();
        print('Added $updatedCount new contacts to Firebase');
      } else {
        print('No new contacts to store in Firebase');
      }
    } catch (e) {
      print('Error storing contacts in Firebase: $e');
      throw Exception('Failed to store contacts in Firebase: $e');
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

  // Helper method to get phone number from contact data
  static String _getContactPhoneNumber(Map<String, dynamic> contactData) {
    try {
      final phones = contactData['phones'] as List<dynamic>;
      if (phones.isNotEmpty) {
        final phone = phones.first['number'] as String;
        return _normalizePhoneNumber(phone);
      }
    } catch (e) {
      print('Error getting phone number from contact data: $e');
    }
    return '';
  }

  static Future<List<Contact>> naturalSearch(String query) async {
    try {
      final userId = await getCurrentUserId();
      print("Query in natural search");
      print(userId);
      final response = await http.get(Uri.parse('https://valut-backend.onrender.com/search/$userId?search=$query'));
      if (response.statusCode == 200) {
        print("Contacts in natural search");
        print(response.body);
        final List<dynamic> contactsJson = jsonDecode(response.body);

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
        
        return transformedContacts
            .map((contactData) => Contact.fromJson(Map<String, dynamic>.from(contactData)))
            .whereType<Contact>()
            .toList();  
      } else {
        throw Exception('Failed to fetch contacts from API');
      }
    } catch (e) {
      print('Error fetching contacts from API: $e');
      throw Exception('Failed to fetch contacts from API: $e');
    }
  }

  // Optional: Add a method to fetch contacts from Firebase
  static Future<List<Contact>> getContactsFromFirebase(String userId) async {
    try {
      final response = await http.get(Uri.parse('https://valut-backend.onrender.com/contactsDB/$userId'));
      if (response.statusCode == 200) {
        print("Contacts in firebase");
        print(response.body);
        final List<dynamic> contactsJson = jsonDecode(response.body);

        //length of contactsJson
        print("Length of contactsJson: ${contactsJson.length}");
        // Convert each map to a Contact object and filter out any null values
        return contactsJson
            .map((contactData) => Contact.fromJson(Map<String, dynamic>.from(contactData)))
            .whereType<Contact>()
            .toList();
      } else {
        throw Exception('Failed to fetch contacts from Firebase');
      }
    } catch (e) {
      print('Error fetching contacts from Firebase: $e');
      throw Exception('Failed to fetch contacts from Firebase: $e');
    }
  }

  //extension contacts 
static Future<List<dynamic>> extensionContacts(String userId) async {
   try {
    // get the data from api
    final response = await http.get(Uri.parse('https://valut-backend.onrender.com/contacts/$userId'));
    if (response.statusCode == 200) {
      print("Contacts in extension");
      print(response.body);
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch contacts from API');
    }
   } catch(e) {
    print('Error fetching contacts from API: $e');
    throw Exception('Failed to fetch contacts from API: $e');
   }
}

  static Future<String> getCurrentUserId() async {
    // If using Firebase Auth:
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
        return user.uid;
    }
    throw Exception('No user logged in');
  }

  static Future<void> initializeContactsInFirebase() async {
    if (_hasPermission != true) {
      return;
    }

    try {
      final userId = await getCurrentUserId();
      await FirebaseFirestore.instance
          .collection('registered_users')
          .doc(userId)
          .set({
        'lastContactSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  // Add this helper method to normalize phone numbers for comparison
  static String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    
    // If the number starts with country code (e.g., '91' for India),
    // remove it to standardize comparison
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }
    return digitsOnly;
  }

  static Future<List<Contact>> getRegisteredContacts(List<Contact> contacts) async {
    if (_hasPermission != true) {
      return [];
    }

    print("Contacts in getRegisteredContacts");
    print(contacts);

    try {
      final firestore = FirebaseFirestore.instance;
      final registeredUsers = await firestore
          .collection('registered_users')
          .get();

      print("Registered Users");
      print(registeredUsers.docs[0].data());
      
      return contacts.where((contact) {
        if (contact.phones.isEmpty) return false;
        print("Contact Phone Number");
        print(contact.phones.first.number);
        return registeredUsers.docs.any((doc) => 
          _normalizePhoneNumber(doc.data()['phoneNumber']) == _normalizePhoneNumber(contact.phones.first.number));
      }).toList();
    } catch (e) {
      print('Error in getRegisteredContacts: $e');
      return [];
    }
  }

  // Reset permission cache
  static Future<void> resetPermissionCache() async {
    _hasPermission = null;
    _isInitialized = false;
  }
}