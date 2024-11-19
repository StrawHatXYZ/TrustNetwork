import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contacts_service.dart';
import 'friend_service.dart'; // Add this import
import 'contact_detail_screen.dart';
import 'screens/contact_view_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_room_screen.dart';

class ContactsPage extends StatefulWidget {
  final String searchQuery;
  const ContactsPage({Key? key, this.searchQuery = ''}) : super(key: key);

  @override
  _ContactsPageState createState() => _ContactsPageState();
}


class _ContactsPageState extends State<ContactsPage> {
  List<Contact>? deviceContacts;
  List<Contact>? filteredContacts;
  List<Contact> networkContacts = [];
  String currentSearchQuery = '';
  bool isLoadingNetwork = true;
  StreamSubscription<QuerySnapshot>? _registeredUsersSubscription;
  Timer? _refreshTimer;
  bool isFilterSearch = false;
  Map<String, String> activeFilters = {
    'title': '',
    'company': '',
    'location': '',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startListeningToRegisteredUsers();
    _startAutoRefresh();
  }

  void _startListeningToRegisteredUsers() {
    _registeredUsersSubscription = FirebaseFirestore.instance
        .collection('registered_users')
        .snapshots()
        .listen((snapshot) async {
      // Reload network contacts whenever registered users change
      await _loadNetworkContacts();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    
    setState(() {
      isLoadingNetwork = true;
    });

    try {
      // Load device contacts first
      await _loadContacts();
      // Then load network contacts
      await _loadNetworkContacts();

      
    } catch (e) {
      print('Error loading initial data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingNetwork = false;
        });
      }
    }
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await ContactService.getContacts();

      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      if (mounted) {
        setState(() {
          deviceContacts = contacts;
          _updateFilteredContacts();
          
          if (deviceContacts!.isNotEmpty) {
            // print('DEBUG: First contact: ${deviceContacts![0].displayName}');
          }
        });
      }
    } catch (e) {
      print('DEBUG: Error loading contacts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load contacts: $e')),
      );
    }
  }

  Future<void> _loadNetworkContacts() async {
    if (!mounted) return;
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          networkContacts = [];
          _updateFilteredContacts();
        });
        return;
      }

      // Use FriendService to get network contacts
      final contacts = await FriendService.getFriendContacts();

      if (mounted) {
        setState(() {
          networkContacts = contacts;
          _updateFilteredContacts();
        });
      }

    } catch (e) {
      print('DEBUG: Error loading network contacts: $e');
      if (mounted) {
        setState(() {
          networkContacts = [];
          _updateFilteredContacts();
        });
      }
    }
  }

  void _updateFilteredContacts() {
    if (deviceContacts == null) return;
    
    // Map to store unique contacts by normalized phone number
    Map<String, Contact> uniqueContacts = {};
    
    // Process network contacts first (priority)
    for (var contact in networkContacts) {
      if (contact.phones.isNotEmpty) {
        String phone = contact.phones.first.number.replaceAll(RegExp(r'\D'), '');
        if (phone.length >= 10) {
          String normalizedPhone = phone.substring(phone.length - 10);
          uniqueContacts[normalizedPhone] = contact;
        }
      }
    }
    
    // Process device contacts
    for (var contact in deviceContacts!) {
      if (contact.phones.isNotEmpty) {
        String phone = contact.phones.first.number.replaceAll(RegExp(r'\D'), '');
        if (phone.length >= 10) {
          String normalizedPhone = phone.substring(phone.length - 10);
          if (!uniqueContacts.containsKey(normalizedPhone)) {
            uniqueContacts[normalizedPhone] = contact;
          }
        }
      }
    }
    
    setState(() {
      filteredContacts = uniqueContacts.values.toList();
      _sortContacts();
    });
  }

  // Future<void> _refreshContacts() async {
  //   await ContactService.refreshContacts();
  //   await _loadContacts();
  //   await _loadNetworkContacts();
  // }

  void filterContacts(String query) {
    if (deviceContacts == null) return;
    
    setState(() {
      currentSearchQuery = query;
      
      if (query.isEmpty) {
        _updateFilteredContacts();
        return;
      }

      // Check if the query contains filter labels
      if (query.contains(':')) {
        Map<String, String> parsedFilters = _parseFilterQuery(query);
        if (parsedFilters.isNotEmpty) {
          activeFilters = parsedFilters;
          _applyFilterSearch();
        }
      } else {
        // Regular search
        activeFilters.clear();
        _applyNormalSearch(query);
      }

      _sortContacts();
    });
  }

  Map<String, String> _parseFilterQuery(String query) {
    Map<String, String> filters = {};
    
    // Split the query by spaces
    List<String> parts = query.split(' ');
    
    for (String part in parts) {
      if (part.contains(':')) {
        List<String> filterPart = part.split(':');
        if (filterPart.length == 2) {
          String key = filterPart[0].toLowerCase();
          String value = filterPart[1].trim();
          
          // Only add if it's a valid filter key
          if (['title', 'company', 'location'].contains(key)) {
            filters[key] = value;
          }
        }
      }
    }
    
    return filters;
  }

  void _applyFilterSearch() {
    Set<Contact> matchingContacts = {};
    
    // Process all contacts (both network and device)
    List<Contact> allContacts = [...networkContacts];
    if (deviceContacts != null) {
      allContacts.addAll(deviceContacts!);
    }
    
    for (var contact in allContacts) {
      if (_contactMatchesFilters(contact, activeFilters)) {
        matchingContacts.add(contact);
      }
    }
    
    filteredContacts = matchingContacts.toList();
  }

  bool _contactMatchesFilters(Contact contact, Map<String, String> filters) {
    for (var entry in filters.entries) {
      String filterValue = entry.value.toLowerCase();
      
      switch (entry.key) {
        case 'title':
          bool hasMatchingTitle = contact.organizations.any((org) =>
            (org.title?.toLowerCase() ?? '').contains(filterValue));
          if (!hasMatchingTitle) return false;
          break;
          
        case 'company':
          bool hasMatchingCompany = contact.organizations.any((org) =>
            (org.company?.toLowerCase() ?? '').contains(filterValue));
          if (!hasMatchingCompany) return false;
          break;
          
        case 'location':
          bool hasMatchingLocation = contact.addresses.any((address) =>
            (address.street?.toLowerCase() ?? '').contains(filterValue) ||
            (address.city?.toLowerCase() ?? '').contains(filterValue) ||
            (address.state?.toLowerCase() ?? '').contains(filterValue) ||
            (address.country?.toLowerCase() ?? '').contains(filterValue));
          if (!hasMatchingLocation) return false;
          break;
      }
    }
    
    return true;
  }

  void _applyNormalSearch(String query) {
    String normalizedQuery = query.toLowerCase();

    // Create a set to track unique contacts
    Set<Contact> uniqueFilteredContacts = {};

    // First add matching network contacts (to maintain priority)
    uniqueFilteredContacts.addAll(
      networkContacts.where((contact) => _contactMatchesNormalSearch(contact, normalizedQuery))
    );

    // Then add matching device contacts
    uniqueFilteredContacts.addAll(
      deviceContacts!.where((contact) => 
        !networkContacts.contains(contact) && 
        _contactMatchesNormalSearch(contact, normalizedQuery))
    );

    // Update filteredContacts with unique results
    filteredContacts = uniqueFilteredContacts.toList();
  }

  bool _contactMatchesNormalSearch(Contact contact, String query) {
    // Check display name
    if (contact.displayName.toLowerCase().contains(query)) {
      return true;
    }

    // Check phone numbers
    if (contact.phones.any((phone) => 
      phone.number.replaceAll(RegExp(r'\D'), '').contains(query))) {
      return true;
    }

    // Check organizations (title and company)
    for (var org in contact.organizations) {
      if ((org.title?.toLowerCase().contains(query) ?? false) ||
          (org.company?.toLowerCase().contains(query) ?? false)) {
        return true;
      }
    }

    // Check addresses
    for (var address in contact.addresses) {
      if ((address.street?.toLowerCase().contains(query) ?? false) ||
          (address.city?.toLowerCase().contains(query) ?? false) ||
          (address.state?.toLowerCase().contains(query) ?? false) ||
          (address.country?.toLowerCase().contains(query) ?? false)) {
        return true;
      }
    }

    // Check email addresses
    if (contact.emails.any((email) => 
      email.address.toLowerCase().contains(query))) {
      return true;
    }

    return false;
  }

  void _sortContacts() {
    // Sort friend contacts
    networkContacts.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    
    // Sort device contacts
    deviceContacts?.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    
    // Sort filtered contacts while maintaining the order (friends first, then device contacts)
    filteredContacts?.sort((a, b) {
      bool aIsFriend = networkContacts.contains(a);
      bool bIsFriend = networkContacts.contains(b);
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
          child: RefreshIndicator(
            onRefresh: refreshContacts,
            color: const Color(0xFFF4845F),
            child: ListView.builder(
              itemCount: _getItemCount(),
              cacheExtent: 100,
              itemBuilder: (context, index) => _buildListItem(index),
            ),
          ),
        ),
      ],
    );
  }

  int _getItemCount() {
    if (currentSearchQuery.isNotEmpty && filteredContacts != null) {
      return filteredContacts!.length + 1;
    }

    return (networkContacts.isEmpty ? 1 : networkContacts.length + 1) + 
           (deviceContacts == null ? 1 : deviceContacts!.length + 1);
  }

  Widget _buildListItem(int index) {
    if (currentSearchQuery.isNotEmpty && filteredContacts != null) {
      if (index == 0) {
        return _buildSectionHeader('Search Results (${filteredContacts!.length})');
      }
      return _buildContactTile(filteredContacts![index - 1]);
    }

    final networkSection = networkContacts.isEmpty ? 1 : networkContacts.length + 1;
    
    if (index == 0) {
      return _buildSectionHeader('Network (${networkContacts.length})');
    }
    
    if (index < networkSection) {
      if (isLoadingNetwork && networkContacts.isEmpty) {
        return _buildLoadingIndicator();
      }
      if (networkContacts.isEmpty) {
        return _buildEmptyNetworkMessage();
      }
      return _buildContactTile(networkContacts[index - 1]);
    }
    
    if (index == networkSection) {
      return _buildSectionHeader('All Contacts (${deviceContacts?.length ?? 0})');
    }
    
    if (deviceContacts == null) {
      return _buildLoadingIndicator();
    }

    // Simply use the device contacts without filtering
    final deviceContactIndex = index - networkSection - 1;
    if (deviceContactIndex >= (deviceContacts?.length ?? 0)) {
      return const SizedBox(); // Return empty widget if index is out of bounds
    }
    
    return _buildContactTile(deviceContacts![deviceContactIndex]);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
        ),
      ),
    );
  }

  Widget _buildEmptyNetworkMessage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text(
          'No network contacts found',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildContactTile(Contact contact) {
    bool isFriend = networkContacts.contains(contact);
    
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
        trailing: isFriend ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.phone, color: Color(0xFFF4845F)),
              onPressed: () {
                if (contact.phones.isNotEmpty) {
                  final phoneNumber = contact.phones.first.number;
                  FriendService.makePhoneCall(phoneNumber);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No phone number available')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.chat, color: Color(0xFFF4845F)),
              onPressed: () async {
                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please sign in to chat')),
                    );
                    return;
                  }

                  // Get the contact's user ID from registered_users collection
                  final contactSnapshot = await FirebaseFirestore.instance
                      .collection('registered_users')
                      .get();

                  final contactDoc = contactSnapshot.docs.firstWhere(
                    (doc) {
                      final storedPhone = doc['phoneNumber'];
                      return contact.phones.any((phone) => 
                        arePhoneNumbersEqual(phone.number, storedPhone));
                    },
                    orElse: () => throw Exception('Contact not found in registered users'),
                  );

                  final contactUserId = contactDoc.id;
                  final contactPhone = contact.phones.first.number;
                  final currentUserDoc = await FirebaseFirestore.instance
                      .collection('registered_users')
                      .doc(currentUser.uid)
                      .get();
                  final currentUserPhone = currentUserDoc.data()?['phoneNumber'] ?? '';

                  // Check if chat room exists
                  final existingRoomQuery = await FirebaseFirestore.instance
                      .collection('chat_rooms')
                      .where('participants', arrayContainsAny: [currentUser.uid, contactUserId])
                      .get();

                  String roomId = '';
                  bool roomExists = false;

                  for (var doc in existingRoomQuery.docs) {
                    List<dynamic> participants = doc['participants'];
                    if (participants.contains(currentUser.uid) &&
                        participants.contains(contactUserId)) {
                      roomId = doc.id;
                      roomExists = true;
                      break;
                    }
                  }

                  if (!roomExists) {
                    // Create new chat room with participant details
                    roomId = '${currentUser.uid}_$contactUserId'
                        .split('_')
                        .toSet()
                        .toList()
                        .join('_');

                    final prefs = await SharedPreferences.getInstance();
                    final name = prefs.getString('user_name');
                    
                    await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).set({
                      'participants': [currentUser.uid, contactUserId],
                      'participantDetails': {
                        currentUser.uid: {
                          'phoneNumber': currentUserPhone,
                          'displayName': name ?? '',
                        },
                        contactUserId: {
                          'phoneNumber': contactPhone,
                          'displayName': contact.displayName,
                        },
                      },
                      'createdAt': FieldValue.serverTimestamp(),
                      'lastMessage': null,
                      'lastMessageTimestamp': FieldValue.serverTimestamp(),
                    });
                  }

                  if (!mounted) return;
                  
                  // Navigate to chat room
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatRoomScreen(
                        roomId: roomId,
                        contactName: contact.displayName,
                        participantNames: '',
                      ),
                    ),
                  );

                } catch (e) {
                  print('Error creating/joining chat room: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to open chat: ${e.toString()}')),
                  );
                }
              },
            ),
          ],
        ) : null,
        onTap: () => _onContactTap(contact),
      ),
    );
  }

  bool arePhoneNumbersEqual(String phone1, String phone2) {
    // Remove all non-digit characters
    String cleanPhone1 = phone1.replaceAll(RegExp(r'\D'), '');
    String cleanPhone2 = phone2.replaceAll(RegExp(r'\D'), '');

    // If one number has a country code and the other doesn't, compare the shorter one to the end of the longer one
    if (cleanPhone1.length != cleanPhone2.length) {
      String shorterNumber = cleanPhone1.length < cleanPhone2.length ? cleanPhone1 : cleanPhone2;
      String longerNumber = cleanPhone1.length > cleanPhone2.length ? cleanPhone1 : cleanPhone2;
      return longerNumber.endsWith(shorterNumber);
    }

    // If they're the same length, compare them directly
    return cleanPhone1 == cleanPhone2;
  }

  void _onContactTap(Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactViewScreen(
          contact: contact,
          onContactUpdated: (updatedContact) => refreshContacts(),
        ),
      ),
    );
  }

  Future<void> refreshContacts() async {
    try {
      setState(() {
        isLoadingNetwork = true;
      });

      // First load device contacts
      await _loadContacts();
      // Then load network contacts
      await _loadNetworkContacts();
      
    } catch (e) {
      print('Error refreshing contacts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh contacts: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingNetwork = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(ContactsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update search when searchQuery changes from parent
    if (widget.searchQuery != currentSearchQuery) {
      setState(() {
        currentSearchQuery = widget.searchQuery;
        filterContacts(widget.searchQuery);
      });
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && 
          (deviceContacts == null || 
           deviceContacts!.isEmpty || 
           networkContacts.isEmpty)) {
        refreshContacts();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _registeredUsersSubscription?.cancel();
    super.dispose();
  }

  // Add this method to update active filters
  void updateActiveFilters({
    String? title,
    String? company,
    String? location,
  }) {
    setState(() {
      if (title != null) activeFilters['title'] = title;
      if (company != null) activeFilters['company'] = company;
      if (location != null) activeFilters['location'] = location;
      
      // Apply filters
      _applyFilterSearch();
    });
  }

  // Add this method to clear filters
  void clearFilters() {
    setState(() {
      activeFilters = {
        'title': '',
        'company': '',
        'location': '',
      };
      _updateFilteredContacts(); // Reset to original list
    });
  }
}

// Add this new widget at the bottom of the file
class ContactViewSheet extends StatelessWidget {
  final Contact contact;
  final VoidCallback onEditPressed;

  const ContactViewSheet({
    Key? key,
    required this.contact,
    required this.onEditPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF4845F),
            radius: 40,
            child: Text(
              contact.displayName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            contact.displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            contact.phones.isNotEmpty ? contact.phones.first.number : 'No phone number',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.phone, color: Color(0xFFF4845F), size: 32),
                onPressed: () {
                  // Add phone call functionality
                },
              ),
              IconButton(
                icon: const Icon(Icons.message, color: Color(0xFFF4845F), size: 32),
                onPressed: () {
                  // Add message functionality
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFFF4845F), size: 32),
                onPressed: onEditPressed,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
