import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'contacts_service.dart';
import 'friend_service.dart'; // Add this import
import 'contact_detail_screen.dart';

class ContactsPage extends StatefulWidget {
  final String searchQuery;
  const ContactsPage({super.key, this.searchQuery = ''});

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact>? deviceContacts;
  List<Contact>? filteredContacts;
  List<Contact> friendContacts = [];
  String currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadFriendContacts();
  }

  @override
  void didUpdateWidget(ContactsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != currentSearchQuery) {
      currentSearchQuery = widget.searchQuery;
      filterContacts(currentSearchQuery);
    }
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await ContactService.getContacts();
      print('Raw contacts loaded: ${contacts.length}');

      final userId = FirebaseAuth.instance.currentUser?.uid;
      print('User ID: $userId');
        
      // Add this line to store contacts in Firebase
      await ContactService.storeContactsInFirebase(userId!); // Replace with actual user ID
      
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

  // Future<void> _refreshContacts() async {
  //   await ContactService.refreshContacts();
  //   await _loadContacts();
  //   await _loadFriendContacts();
  // }

  void filterContacts(String query) {
    if (deviceContacts == null) return;
    
    setState(() {
      if (query.isEmpty) {
        _updateFilteredContacts();
        return;
      }

      // Filter friend contacts
      List<Contact> filteredFriendContacts = friendContacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || phone.contains(searchLower);
      }).toList();

      // Filter device contacts
      List<Contact> filteredDeviceContacts = deviceContacts!.where((contact) {
        final name = contact.displayName.toLowerCase();
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || phone.contains(searchLower);
      }).toList();

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
    return Column(
      children: [
        Expanded(
          child: filteredContacts == null
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
                  ))
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
            style: const TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        ...contacts.map((contact) => _buildContactTile(contact)).toList(),
      ],
    );
  }

  Widget _buildContactTile(Contact contact) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          contact.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          contact.phones.isNotEmpty ? contact.phones.first.number : 'No phone number',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF4845F),
          radius: 24,
          child: Text(
            contact.displayName[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _navigateToContactDetail(contact),
      ),
    );
  }

  void _navigateToContactDetail(Contact contact) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ContactDetailScreen(
          contact: contact,
          onContactUpdated: (Contact updatedContact) {
            setState(() {
              int index = deviceContacts!.indexWhere((c) => c.id == updatedContact.id);
              if (index != -1) {
                deviceContacts![index] = updatedContact;
              }
              _updateFilteredContacts();
            });
          },
        ),
      ),
    );

    if (result == true) {
      await _loadContacts();
      await _loadFriendContacts();
    }
  }
}
