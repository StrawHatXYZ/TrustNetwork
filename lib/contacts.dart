import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'contacts_service.dart';
import 'friend_service.dart'; // Add this import

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact>? deviceContacts;
  List<Contact>? filteredContacts;
  List<Contact> friendContacts = []; // Add this line
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadFriendContacts(); // Add this line
    searchController.addListener(_filterContacts);
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await ContactService.getContacts();
      print('Raw contacts loaded: ${contacts.length}');
      setState(() {
        deviceContacts = contacts;
        _updateFilteredContacts();
        
        print('Loaded ${deviceContacts!.length} contacts');
        print('First 5 contacts:');
        for (var contact in deviceContacts!.take(5)) {
          print('Name: ${contact.displayName}, Phone: ${contact.phones.isNotEmpty ? contact.phones.first.number : 'No number'}');
        }
      });
    } catch (e) {
      print('Error loading contacts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load contacts: $e')),
      );
    }
  }

  Future<void> _loadFriendContacts() async {
    try {
      final friends = await FriendService.getFriendContacts();
      setState(() {
        friendContacts = friends;
        _updateFilteredContacts();
      });
      print('Loaded ${friendContacts.length} friend contacts');
    } catch (e) {
      print('Error loading friend contacts: $e');
    }
  }

  void _updateFilteredContacts() {
    filteredContacts = [...friendContacts, ...deviceContacts ?? []];
    _sortContacts();
  }

  Future<void> _refreshContacts() async {
    await ContactService.refreshContacts();
    await _loadContacts();
    await _loadFriendContacts();
  }

  @override
  void dispose() {
    searchController.removeListener(_filterContacts);
    searchController.dispose();
    super.dispose();
  }

  void _filterContacts() {
    if (deviceContacts == null) {
      print('deviceContacts is null');
      return;
    }
    
    final query = searchController.text.toLowerCase().trim();
    print('Filtering query: "$query"');
    
    setState(() {
      // Filter friend contacts
      List<Contact> filteredFriendContacts = friendContacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
        return name.contains(query) || phone.contains(query);
      }).toList();

      // Filter device contacts
      List<Contact> filteredDeviceContacts = deviceContacts!.where((contact) {
        final name = contact.displayName.toLowerCase();
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
        return name.contains(query) || phone.contains(query);
      }).toList();

      // Combine filtered contacts, keeping friends first
      filteredContacts = [...filteredFriendContacts, ...filteredDeviceContacts];
      _sortContacts();
    });
  }

  void _sortContacts() {
    // Sort friend contacts
    friendContacts.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    
    // Sort device contacts
    deviceContacts?.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    
    // Sort filtered contacts while maintaining the order (friends first, then device contacts)
    filteredContacts?.sort((a, b) {
      bool aIsFriend = friendContacts.contains(a);
      bool bIsFriend = friendContacts.contains(b);
      if (aIsFriend == bIsFriend) {
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      }
      return aIsFriend ? -1 : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshContacts,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: filteredContacts == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      if (filteredContacts!.any((contact) => friendContacts.contains(contact)))
                        _buildContactSection('Friends', filteredContacts!.where((contact) => friendContacts.contains(contact)).toList()),
                      if (filteredContacts!.any((contact) => !friendContacts.contains(contact)))
                        _buildContactSection('All Contacts', filteredContacts!.where((contact) => !friendContacts.contains(contact)).toList()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(String title, List<Contact> contacts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        ...contacts.map((contact) => _buildContactTile(contact)).toList(),
      ],
    );
  }

  Widget _buildContactTile(Contact contact) {
    return ListTile(
      title: Text(
        contact.displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        contact.phones.isNotEmpty ? contact.phones.first.number : 'No phone number',
        style: const TextStyle(color: Colors.grey),
      ),
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(
          contact.displayName[0].toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}