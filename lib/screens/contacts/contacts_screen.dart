import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust/screens/chats/chat_room_screen.dart';
import 'contact_view_screen.dart';
import '../../services/contacts_service.dart';
import '../../services/friend_service.dart';
import 'package:app_settings/app_settings.dart';

class ContactsPage extends StatefulWidget {
  final String searchQuery;
  const ContactsPage({Key? key, this.searchQuery = ''}) : super(key: key);

  @override
  _ContactsPageState createState() => _ContactsPageState();
}


class _ContactsPageState extends State<ContactsPage> with WidgetsBindingObserver {
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
  late bool isPermissionDenied;
  bool isNaturalSearchLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeContacts();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _registeredUsersSubscription?.cancel();
    super.dispose();
  }

  // Add this method to detect when app returns from settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check permission again when app resumes
      _checkAndLoadContacts();
    }
  }

  Future<void> _checkAndLoadContacts() async {
    if (!mounted) return;

    try {
      // Reset permission cache in ContactService
      await ContactService.resetPermissionCache();
        
            bool hasPermission = await ContactService.checkPermissionStatus();
          if (hasPermission) {
        setState(() {
          isPermissionDenied = false;
          isLoadingNetwork = true;
        });
        
        await _loadInitialData();
      } else {
        setState(() {
          isPermissionDenied = true;
          deviceContacts = [];
          networkContacts = [];
          filteredContacts = [];
        });
      }
    } catch (e) {
      print('Error checking contacts permission: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingNetwork = false;
        });
      }
    }
  }

  Future<void> _initializeContacts() async {
    if (!mounted) return;

    try {
      // Check existing permission status without requesting
      bool hasPermission = await ContactService.checkPermissionStatus();
      
      setState(() {
        isPermissionDenied = !hasPermission;
        isLoadingNetwork = !isPermissionDenied;
      });

      // If we have permission, load the contacts
      if (hasPermission) {
        await _loadInitialData();
      }
    } catch (e) {
      print('Error checking contacts permission: $e');
      setState(() {
        isPermissionDenied = true;
        isLoadingNetwork = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    
    setState(() {
      isLoadingNetwork = true;
    });

    try {
      // Check permission first, before ANY contact operations
      bool hasPermission = await ContactService.checkPermissionStatus();
      if (!hasPermission) {
        setState(() {
          deviceContacts = [];
          networkContacts = [];
          filteredContacts = [];
          isLoadingNetwork = false;
        });
        return;
      }

      // Only proceed with loading if we have permission
      await Future.wait([
        _loadContacts(),
        _loadNetworkContacts(),
      ]);
    } catch (e) {
      print('Error loading initial data: $e');
      setState(() {
        deviceContacts = [];
        networkContacts = [];
        filteredContacts = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingNetwork = false;
        });
      }
    }
  }

  Future<void> _loadContacts() async {
    if (!mounted) return;

    try {
      bool hasPermission = await ContactService.checkPermissionStatus();
      
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            deviceContacts = [];
            _updateFilteredContacts();
          });
        }
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get both regular contacts and extension contacts
      final contacts = await ContactService.getContactsFromFirebase(currentUser.uid);
      final extensionContacts = await ContactService.extensionContacts(currentUser.uid);

      // Convert extension contacts to Contact objects
      List<Contact> formattedExtensionContacts = extensionContacts.map((extContact) {
        // Split the name into components
        String fullName = extContact['Name'] ?? '';
        List<String> nameParts = fullName.split(' ');
        String firstName = nameParts.isNotEmpty ? nameParts.first : '';
        String lastName = nameParts.length > 1 ? nameParts.last : '';
        String middleName = nameParts.length > 2 ? nameParts.sublist(1, nameParts.length - 1).join(' ') : '';

        return Contact(
          displayName: fullName,
          name: Name(
            first: firstName,
            last: lastName,
            middle: middleName,
            prefix: '',
            suffix: '',
            nickname: '',
            firstPhonetic: '',
            lastPhonetic: '',
            middlePhonetic: '',
          ),
          phones: [
            Phone(
              extContact['Phone 1 - Value'] ?? '',
              normalizedNumber: extContact['Phone 1 - Value'] ?? '',
              label: PhoneLabel.mobile,
              customLabel: '',
              isPrimary: false,
            )
          ],
          emails: extContact['E-mail 1 - Value']?.isNotEmpty == true 
            ? [Email(extContact['E-mail 1 - Value']!)]
            : [],
          organizations: [
            Organization(
              company: extContact['Organization 1 - Name'] ?? '',
              title: extContact['Organization 1 - Title'] ?? '',
            )
          ],
          addresses: extContact['Location']?.isNotEmpty == true
            ? [Address(extContact['Location'] ?? '')]
            : [],
          isStarred: false,
          thumbnail: null,
          photo: null,
          websites: [],
          socialMedias: [],
          events: [],
          notes: [],
          accounts: [],
          groups: [],
        );
      }).toList();

      // Merge contacts and extension contacts
      List<Contact> mergedContacts = [...contacts, ...formattedExtensionContacts];

      // Remove duplicates based on phone number
      Map<String, Contact> uniqueContacts = {};
      for (var contact in mergedContacts) {
        if (contact.phones.isNotEmpty) {
          String phone = contact.phones.first.number.replaceAll(RegExp(r'\D'), '');
          if (phone.length >= 10) {
            String normalizedPhone = phone.substring(phone.length - 10);
            uniqueContacts[normalizedPhone] = contact;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          deviceContacts = uniqueContacts.values.toList();
          _updateFilteredContacts();
        });
      }
    } catch (e) {
      print('DEBUG: Error loading contacts: $e');
      if (mounted) {
        setState(() {
          deviceContacts = [];
          _updateFilteredContacts();
        });
      }
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

      print("Getting Contacts Second Time Friend Contacts");

      print(contacts);
      print(contacts[0].organizations);
      //iterate through the contacts and print the organizations
      for (var contact in contacts) {
        print(contact.organizations);
      }
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

  Future<void> filterContacts(String query, {bool isNaturalSearch = false}) async {
    print("Filtering Contacts");
    print(isNaturalSearch);
    if (deviceContacts == null) return;

    // Handle empty query
    if (query.isEmpty) {
      setState(() {
        currentSearchQuery = '';
        activeFilters.clear();
        _updateFilteredContacts();
        isNaturalSearchLoading = false;
      });
      return;
    }

    if (isNaturalSearch) {
      setState(() {
        isNaturalSearchLoading = true;
        currentSearchQuery = query;
      });

      try {
        final contactsNatural = await ContactService.naturalSearch(query);
        print("Contacts Natural in filterContacts");
        print(contactsNatural);
        
        if (mounted) {
          setState(() {
            filteredContacts = contactsNatural.toList();
            _sortContacts();
            isNaturalSearchLoading = false;
          });
        }
      } catch (e) {
        print('Error in natural search: $e');
        if (mounted) {
          setState(() {
            filteredContacts = [];
            isNaturalSearchLoading = false;
          });
        }
      }
      return;
    }
    
    setState(() {
      currentSearchQuery = query;
      
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

  Widget _buildPermissionDeniedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_accounts,
              size: 80,
              color: Color(0xFFF4845F),
            ),
            const SizedBox(height: 24),
            const Text(
              'Contacts Permission Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'To see your contacts and connect with friends, please allow access to your contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                // Request permission only when user explicitly asks
                bool hasPermission = await ContactService.requestInitialPermission();
                if (hasPermission) {
                  setState(() {
                    isPermissionDenied = false;
                  });
                  _initializeContacts();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please enable contacts access in settings'),
                        action: SnackBarAction(
                          label: 'Open Settings',
                          onPressed: () async {
                            await AppSettings.openAppSettings();
                          },
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4845F),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Allow Access',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to show the search dialog
  void _showNaturalSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Text(
                      'Natural Search',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Search Input
                TextField(
                  onChanged: (value) => searchQuery = value,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Try "title:manager" or "company:tech"...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF4845F), width: 2),
                    ),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFF4845F)),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Search Tips
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (searchQuery.isNotEmpty) {
                          filterContacts(searchQuery, isNaturalSearch: true);
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4845F),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchTip(String prefix, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            prefix,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.blue,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isPermissionDenied) {
      return _buildPermissionDeniedState();
    }

    return Column(
      children: [
        // Padding(
        //   padding: const EdgeInsets.all(8.0),
        //   child: Row(
        //     children: [
              // Expanded(
              //   child: ElevatedButton.icon(
              //     onPressed: _showNaturalSearchDialog,
              //     icon: const Icon(Icons.search),
              //     label: const Text('Natural Search'),
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: const Color(0xFFF4845F),
              //       foregroundColor: Colors.white,
              //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //     ),
              //   ),
              // ),
              // // Add clear button if there's an active search
              // if (currentSearchQuery.isNotEmpty || activeFilters.values.any((v) => v.isNotEmpty))
              //   IconButton(
              //     onPressed: clearSearch,
              //     icon: const Icon(Icons.clear),
              //     tooltip: 'Clear search',
              //     color: const Color(0xFFF4845F),
              //   ),
        //     ],
        //   ),
        // ),
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
      
      // Show loading indicator when natural search is in progress
      if (isNaturalSearchLoading) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
            ),
          ),
        );
      }
      
      return _buildContactTile(
        filteredContacts![index - 1], 
        isNetworkSection: networkContacts.contains(filteredContacts![index - 1])
      );
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
      return _buildContactTile(networkContacts[index - 1], isNetworkSection: true);
    }
    
    if (index == networkSection) {
      return _buildSectionHeader('Contacts (${deviceContacts?.length ?? 0})');
    }
    
    if (deviceContacts == null) {
      return _buildLoadingIndicator();
    }

    final deviceContactIndex = index - networkSection - 1;
    if (deviceContactIndex >= (deviceContacts?.length ?? 0)) {
      return const SizedBox();
    }
    
    return _buildContactTile(deviceContacts![deviceContactIndex], isNetworkSection: false);
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

  Widget _buildContactTile(Contact contact, {required bool isNetworkSection}) {
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
        trailing: isNetworkSection ? Row(
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

                  print("Contact Snapshot dfsdfds");
                  print(contact);
                  print(contact.phones[0].number);

                  final contactDoc = contactSnapshot.docs.firstWhere(
                    (doc) {
                      print(doc.data());
                      final storedPhone = doc.data()['phoneNumber'];
                      print("Stored Phone");
                      print(storedPhone);
                      if (storedPhone == null) {
                        return false;
                      }
                      return contact.phones.any((phone) => 
                        arePhoneNumbersEqual(phone.number, storedPhone));
                    },
                    orElse: () => throw Exception('Contact not found in registered users'),
                  );

                  print("Contact Doc");
                  print(contactDoc.data());

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
    print("Clean Phone 1");
    print(cleanPhone1);
    print("Clean Phone 2");
    print(cleanPhone2);
    // If they're the same length, compare them directly
    return cleanPhone1 == cleanPhone2;
  }

  void _onContactTap(Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactViewScreen(
          contact: contact,
          onContactUpdated: (updatedContact) async {
            // First refresh contacts as befo
            // Additionally reload network contacts specifically
            await refreshContacts();
          },
        ),
      ),
    );
  }

  Future<void> refreshContacts() async {
    if (!mounted) return;

    try {
      setState(() {
        isLoadingNetwork = true;
      });

      bool hasPermission = await ContactService.checkPermissionStatus();
      if (!hasPermission) {
        setState(() {
          deviceContacts = [];
          _updateFilteredContacts();
          isLoadingNetwork = false;
        });
        return;
      }

      await _loadContacts();
      await _loadNetworkContacts();
      
    } catch (e) {
      print('Error refreshing contacts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load contacts')),
        );
      }
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
      });

      // Cancel any existing timer
      _debounceTimer?.cancel();

      // If it's a sentence (contains spaces), wait for user to finish typing
      if (widget.searchQuery.contains(' ')) {
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            filterContacts(widget.searchQuery, isNaturalSearch: true);
          }
        });
      } else {
        // For single words, search immediately
        filterContacts(widget.searchQuery);
      }
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        // Check permission before refresh
        bool hasPermission = await ContactService.checkPermissionStatus();
        if (!hasPermission) {
          print('No permission for auto-refresh');
          return;
        }

        if (mounted && (deviceContacts == null || deviceContacts!.isEmpty)) {
          refreshContacts();
        }
      } catch (e) {
        print('Auto refresh error: $e');
      }
    });
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

  // Add this new method to explicitly clear search
  void clearSearch() {
    setState(() {
      currentSearchQuery = '';
      activeFilters.clear();
      _updateFilteredContacts();
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