import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class NetworkService {
  static const String _networkKey = 'user_network';

  static Future<List<String>> loadUserNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_networkKey) ?? [];
  }

  static Future<void> saveUserNetwork(List<String> network) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_networkKey, network);
  }

  static Future<void> addToNetwork(Contact contact) async {
    if (contact.phones.isNotEmpty) {
      String phoneNumber = contact.phones.first.number;
      String contactInfo = '${contact.displayName}: $phoneNumber';
      List<String> network = await loadUserNetwork();
      network.add(contactInfo);
      await saveUserNetwork(network);
    }
  }

  static Future<void> removeFromNetwork(int index) async {
    List<String> network = await loadUserNetwork();
    network.removeAt(index);
    await saveUserNetwork(network);
  }

  static Future<void> clearUserNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_networkKey, []);
  }
}