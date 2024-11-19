import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactService {
  static const String _contactsKey = 'contacts';

  static Future<List<Contact>> getContacts() async {
    try {
      final userId = await getCurrentUserId();
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('registered_users') 
          .doc(userId)
          .collection('contacts')
          .get();

      print('Fetching contacts from Firebase');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Contact.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error fetching contacts from Firebase: $e');
      throw Exception('Failed to fetch contacts from Firebase: $e');
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
          doc.id: doc.data()
      };

      final batch = firestore.batch();
      int updatedCount = 0;

      for (final contact in contacts) {
        final contactData = _contactToJson(contact);
        final docRef = contactsCollection.doc(contact.id);
        
        // Check if contact exists and if it's different from the current data
        final existingContact = existingContactsMap[contact.id];
        if (existingContact == null || !_areContactsEqual(existingContact, contactData)) {
          batch.set(docRef, {
            ...contactData,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          updatedCount++;
        }
      }

      // Only commit if there are changes
      if (updatedCount > 0) {
        await batch.commit();
        print('Updated $updatedCount contacts in Firebase');
      } else {
        print('No new or updated contacts to store in Firebase');
      }
    } catch (e) {
      print('Error storing contacts in Firebase: $e');
      throw Exception('Failed to store contacts in Firebase: $e');
    }
  }

  // Helper method to compare contacts
  static bool _areContactsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    // Remove lastUpdated field from comparison
    final aCompare = Map<String, dynamic>.from(a)..remove('lastUpdated');
    final bCompare = Map<String, dynamic>.from(b)..remove('lastUpdated');
    
    return const DeepCollectionEquality().equals(aCompare, bCompare);
  }

  // Optional: Add a method to fetch contacts from Firebase
  static Future<List<Contact>> getContactsFromFirebase(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Contact.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error fetching contacts from Firebase: $e');
      throw Exception('Failed to fetch contacts from Firebase: $e');
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
// ... existing code ...

static Future<bool> requestContactPermissions() async {
  try {
    // Request both read and write permissions
    final status = await FlutterContacts.requestPermission(readonly: true);
    if (!status) {
      print('Contacts permission denied');
      return false;
    }
    return true;
  } catch (e) {
    print('Error requesting contacts permission: $e');
    return false;
  }
}

static Future<void> initializeContactsInFirebase() async {
  // First check/request permissions
  final hasPermission = await requestContactPermissions();
  if (!hasPermission) {
    throw Exception('Contacts permission not granted');
  }

  try {
    final userId = await getCurrentUserId();
    final firestore = FirebaseFirestore.instance;
    
    final contactsRef = firestore
        .collection('registered_users')
        .doc(userId)
        .collection('contacts');

    // Get device contacts
    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );
    
    print('Found ${deviceContacts.length} contacts on device');
    
    // Get existing contacts from Firebase
    final existingContacts = await contactsRef.get();
    final existingContactsMap = Map.fromEntries(
      existingContacts.docs.map((doc) {
        final data = doc.data();
        return MapEntry(
          _normalizePhoneNumber(data['phones']?[0]?['number'] ?? ''),
          {
            'id': doc.id,
            'name': data['displayName'],
            'phone': data['phones']?[0]?['number'] ?? '',
          }
        );
      })
    );
    
    // Batch write for better performance
    final batch = firestore.batch();
    int newContactsCount = 0;
    
    for (final contact in deviceContacts) {
      if (contact.phones.isEmpty) continue;
      
      final normalizedPhone = _normalizePhoneNumber(contact.phones.first.number);
      final existing = existingContactsMap[normalizedPhone];
      
      // Skip if contact already exists with same name and phone
      if (existing != null && existing['name'] == contact.displayName) {
        continue;
      }
      
      // Prepare contact data
      final contactData = _contactToJson(contact);
      final docRef = contactsRef.doc(contact.id);
      
      batch.set(docRef, {
        ...contactData,
        'lastUpdated': FieldValue.serverTimestamp(),
        'initialSync': true,
      });
      
      newContactsCount++;
    }
    
    // Only commit if there are new contacts
    if (newContactsCount > 0) {
      await batch.commit();
      print('Successfully stored $newContactsCount new contacts in Firebase');
    } else {
      print('No new contacts to add');
    }
    
    // Update sync timestamp
    await firestore
        .collection('registered_users')
        .doc(userId)
        .set({
          'lastContactSync': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
          
  } catch (e) {
    print('Error initializing contacts in Firebase: $e');
    throw Exception('Failed to initialize contacts in Firebase: $e');
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
}