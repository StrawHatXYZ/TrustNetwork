import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class ContactService {
  static const String _contactsKey = 'contacts';

  static Future<List<Contact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString(_contactsKey);

    if (contactsJson != null) {
      print('Contacts found in local storage');
      try {
        final List<dynamic> decodedContacts = jsonDecode(contactsJson);
        return decodedContacts.map((json) => Contact.fromJson(json)).toList();
      } catch (e) {
        print('Error decoding contacts: $e');
        return await _fetchAndStoreDeviceContacts();
      }
    } else {
      print('No contacts in local storage, fetching from device');
      return await _fetchAndStoreDeviceContacts();
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
    final contacts = await getContacts();
    final index = contacts.indexWhere((c) => c.id == updatedContact.id);

    print('Before update: ${contacts[index]}');

    if (index != -1) {
      contacts[index] = updatedContact;
      print('After update: ${contacts[index]}');
      
      await _storeContactsLocally(contacts);
      
      // Verify if the contact was actually stored
      final storedContacts = await getContacts();
      final storedUpdatedContact = storedContacts.firstWhere((c) => c.id == updatedContact.id);
      print('Stored updated contact: $storedUpdatedContact');
      
      if (storedUpdatedContact.displayName == updatedContact.displayName) {
        print('Contact updated and stored successfully');
      } else {
        print('Contact update may not have been stored properly');
      }
    } else {
      throw Exception('Contact not found');
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
}
