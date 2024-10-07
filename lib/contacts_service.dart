import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
}