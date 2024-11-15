import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust/profile_page.dart';
import 'contacts_service.dart';
import 'friend_service.dart';
import 'contacts.dart';
import 'chat_room_screen.dart';
import 'chat_list_screen.dart'; // Add this import
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {

  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> posts = [];
  final TextEditingController _searchController = TextEditingController();
  List<Contact> contacts = [];
  List<Contact> registeredContacts = [];
  List<Map<String, dynamic>> friendRequests = [];
  Map<String, bool> sentFriendRequests = {};
  List<Contact> friendContacts = [];
  String _userName = 'John Doe'; // Add this line

  // Update loading state variables to be more specific
  bool _isLoading = true;
  bool _isPostsLoading = true;
  bool _isContactsLoading = true;
  bool _isFriendRequestsLoading = true;
  bool _isRegisteredContactsLoading = true;  // Add this line

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Update _loadAllData method
  Future<void> _loadAllData() async {
    try {
      await Future.wait([
        _loadContacts(),
        _loadFriendRequests(),
        _loadFriendContacts(),
        _loadPosts(),
        _loadUserName(),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add this method
  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    setState(() {
      _userName = name ?? 'John Doe';
    });
  }

  // Update _loadContacts method
  Future<void> _loadContacts() async {
    setState(() => _isContactsLoading = true);
    try {
      final allContacts = await ContactService.getContacts();
      if (mounted) {
        setState(() {
          contacts = allContacts;
          _isContactsLoading = false;
        });
      }
      await _checkRegisteredContacts();
    } catch (e) {
      print('Error loading contacts: $e');
      if (mounted) {
        setState(() => _isContactsLoading = false);
      }
    }
  }

  Future<void> _checkRegisteredContacts() async {
    setState(() => _isRegisteredContactsLoading = true);
    try {
      final registeredUsers = await FirebaseFirestore.instance.collection('registered_users').get();
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) return;

      final friendsDoc = await FirebaseFirestore.instance.collection('Network').doc(currentUser.uid).get();
      List<String> friendIds = [];
      if (friendsDoc.exists) {
        friendIds = List<String>.from(friendsDoc.data()?['friends'] ?? []);
      }

      List<Contact> newRegisteredContacts = [];

      for (var contact in contacts) {
        for (var user in registeredUsers.docs) {
          if (contact.phones.isNotEmpty) {
            String contactPhone = contact.phones.first.number.replaceAll(RegExp(r'\D'), '');
            String userPhone = user.data()['phoneNumber'].replaceAll(RegExp(r'\D'), '');
            
            if (contactPhone == userPhone && !friendIds.contains(user.id) && user.id != currentUser.uid) {
              newRegisteredContacts.add(contact);
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          registeredContacts = newRegisteredContacts;
          _isRegisteredContactsLoading = false;
        });
      }
    } catch (e) {
      print('Error checking registered contacts: $e');
      if (mounted) {
        setState(() => _isRegisteredContactsLoading = false);
      }
    }
  }

  // Update _loadFriendRequests method
  Future<void> _loadFriendRequests() async {
    setState(() => _isFriendRequestsLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('recipientId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          friendRequests = snapshot.docs.map((doc) => doc.data()).toList();
          _isFriendRequestsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading friend requests: $e');
      if (mounted) {
        setState(() => _isFriendRequestsLoading = false);
      }
    }
  }

  Future<void> _loadFriendContacts() async {
    try {
      final friends = await FriendService.getFriendContacts();
      setState(() {
        friendContacts = friends;
      });
    } catch (e) {
      print('Error loading friend contacts: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _buildSearchBar(),
        automaticallyImplyLeading: false,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomePage(context, _userName),
          ContactsPage(searchQuery: _searchController.text),
          ChatListScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
        ],
        selectedItemColor: const Color(0xFFF4845F),
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _getSearchHint(),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFF4845F)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _performSearch('');
                          });
                        },
                      )
                    : null,
              ),
              onChanged: _performSearch,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF4845F), width: 2),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              backgroundImage: NetworkImage(
                'https://ui-avatars.com/api/?background=0D8ABC&color=fff&name=${Uri.encodeComponent(_userName)}&rounded=true'
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getSearchHint() {
    switch (_currentIndex) {
      case 0:
        return 'Search posts...';
      case 1:
        return 'Search contacts...';
      case 2:
        return 'Search chats...';
      default:
        return 'Search...';
    }
  }

  void _performSearch(String query) {
    switch (_currentIndex) {
      case 0:
        // Handle home page search
        setState(() {
          if (query.isEmpty) {
            _loadPosts();
          } else {
            posts = posts.where((post) =>
              post['content'].toString().toLowerCase().contains(query.toLowerCase()) ||
              post['username'].toString().toLowerCase().contains(query.toLowerCase())
            ).toList();
          }
        });
        break;
      case 1:
        // Just update the search query, ContactsPage will handle the filtering
        setState(() {}); // This will trigger a rebuild of ContactsPage with new search query
        break;
      case 2:
        // Handle chat search
        break;
    }
  }

  Widget _buildHomePage(BuildContext context, String username) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  if (_isFriendRequestsLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
                      )),
                    )
                  else if (friendRequests.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Friend Requests',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...friendRequests.map((request) => _buildFriendRequestCard(request)),
                  ],
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Suggested Contacts',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_isRegisteredContactsLoading)
                    const Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
                    ))
                  else
                    ...registeredContacts.map((contact) => _buildContactCard(contact)),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Posts',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_isPostsLoading)
                    const Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
                    ))
                  else
                    ...posts.map((post) => _buildPostCard(post)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewPostBottomSheet(context, username);
        },
        backgroundColor: const Color(0xFFF4845F),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Add this new method to build post cards
  Widget _buildPostCard(Map<String, dynamic> post) {
    List<String> contentWords = post['content'].toString().toLowerCase().split(' ');
    List<Contact> matchingContacts = [];

    for (var contact in contacts) {
      if (contact.organizations.isNotEmpty) {
        String title = contact.organizations.first.title?.toLowerCase() ?? '';
        if (contentWords.any((word) => title.contains(word))) {
          matchingContacts.add(contact);
        }
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: post['avatar_url'] != null 
                    ? NetworkImage(post['avatar_url'] as String) 
                    : null,
                  child: post['avatar_url'] == null 
                    ? Text((post['username'] as String? ?? '?')[0], style: const TextStyle(fontSize: 20))
                    : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Flexible(
                    child: Text(
                          post['username'] as String? ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),  
              ],
            ),
            const SizedBox(height: 8),
            Text(post['content'] as String? ?? ''),
            const SizedBox(height: 8),
            Text(
              _formatTimestamp(post['timestamp']),
              style: const TextStyle(color: Colors.grey),
            ),
            if (matchingContacts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Would you like to connect with contacts related to this post?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _showMatchingContacts(matchingContacts, post['user_id'] as String);
                    },
                    child: Text('Yes'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Maybe next time!')),
                      );
                    },
                    child: Text('No'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMatchingContacts(List<Contact> matchingContacts, String postAuthorId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Matching Contacts'),
          content: SingleChildScrollView(
            child: ListBody(
              children: matchingContacts.map((contact) => 
                ListTile(
                  title: Text(contact.displayName),
                  subtitle: Text(contact.organizations.isNotEmpty 
                    ? contact.organizations.first.title ?? 'No title' 
                    : 'No title'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _createChatRoom(contact, postAuthorId);
                  },
                )
              ).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _createChatRoom(Contact contact, String postAuthorId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Get the contact's user ID
      final contactSnapshot = await FirebaseFirestore.instance
          .collection('registered_users')
          .get();

      final contactDoc = contactSnapshot.docs.firstWhere(
        (doc) {
          final storedPhone = doc['phoneNumber'];
          return contact.phones.any((phone) => arePhoneNumbersEqual(phone.number, storedPhone));
        },
        orElse: () => throw Exception('Contact not found in registered users'),
      );

      final contactUserId = contactDoc.id;

      // Check if a chat room already exists with these participants
      final existingRoomQuery = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContainsAny: [currentUser.uid, contactUserId, postAuthorId])
          .get();

      String roomId = '';
      bool roomExists = false;

      for (var doc in existingRoomQuery.docs) {
        List<dynamic> participants = doc['participants'];
        if (participants.contains(currentUser.uid) &&
            participants.contains(contactUserId) &&
            participants.contains(postAuthorId)) {
          roomId = doc.id;
          roomExists = true;
          break;
        }
      }

      if (!roomExists) {
        // Create a unique room ID if no existing room was found
        roomId = '${currentUser.uid}_${contactUserId}_$postAuthorId'
            .split('_')
            .toSet()
            .toList()
            .join('_');

        // Create the chat room document
        await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).set({
          'participants': [currentUser.uid, contactUserId, postAuthorId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New chat room created with ${contact.displayName}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joining existing chat room with ${contact.displayName}')),
        );
      }

      // Navigate to the chat room
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(roomId: roomId, contactName: contact.displayName, participantNames:''),
        ),
      );

    } catch (e) {
      print('Error creating/joining chat room: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create/join chat room: ${e.toString()}')),
      );
    }
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

  // Update this method to handle Timestamp
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.parse(timestamp);
    } else {
      return 'Invalid timestamp';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // Add this method to create contact cards
  Widget _buildContactCard(Contact contact) {
    bool requestSent = sentFriendRequests[contact.id] ?? false;

    return Dismissible(
      key: Key(contact.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _removeContact(contact);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: contact.photo != null
                        ? MemoryImage(contact.photo!)
                        : null,
                    child: contact.photo == null
                        ? Text(contact.displayName[0], style: const TextStyle(fontSize: 20))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.displayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          contact.phones.isNotEmpty ? contact.phones.first.number : 'No phone number',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Do you want to add to your network?',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _removeContact(contact);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text('No', style: TextStyle(fontSize: 14, color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: requestSent ? null : () {
                      _addToContacts(contact);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: requestSent ? Colors.grey : const Color(0xFFF4845F),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      requestSent ? 'Friend request sent' : 'Add to network',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeContact(Contact contact) {
    setState(() {
      registeredContacts.removeWhere((item) => item.id == contact.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${contact.displayName} removed from suggestions")),
    );
  }

  void _addToContacts(Contact contact) {
    _sendFriendRequest(contact);
  }

  Future<void> _sendFriendRequest(Contact contact) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Get the recipient's user ID
      final recipientSnapshot = await FirebaseFirestore.instance
          .collection('registered_users')
          .get();

      final recipientDoc = recipientSnapshot.docs.firstWhere(
        (doc) {
          final storedPhone = doc['phoneNumber'];
          return contact.phones.any((phone) => arePhoneNumbersEqual(phone.number, storedPhone));
        },
        orElse: () => throw Exception('Recipient user not found'),
      );

      final recipientUserId = recipientDoc.id;

      // Check for existing friend request
      final existingRequestSnapshot = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('recipientId', isEqualTo: recipientUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequestSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Friend request already sent to ${contact.displayName}")),
        );
        return;
      }

      // If no existing request, create a new friend request document
      await FirebaseFirestore.instance.collection('friend_requests').add({
        'senderId': currentUser.uid,
        'senderPhone': currentUser.phoneNumber,
        'senderName': currentUser.displayName ?? 'Unknown',
        'recipientId': recipientUserId,
        'recipientPhone': contact.phones.first.number,
        'recipientName': contact.displayName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        sentFriendRequests[contact.id] = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Friend request sent to ${contact.displayName}")),
      );
    } catch (e) {
      print('Error sending friend request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send friend request: ${e.toString()}")),
      );
    }
  }

  Future<void> _addPost(BuildContext context, String username, String content) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post')),
      );
      return;
    }

    try {
      
        //get user name from shared preferences
      final prefs = await SharedPreferences.getInstance();
      String? userName = prefs.getString('user_name');
      String? userPhone = prefs.getString('user_phone');

      // If userName or userPhone is null, fetch from Firestore
      if (userName == null || userPhone == null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('registered_users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          userName = userData?['name'] ?? 'Unknown';
          userPhone = userData?['phoneNumber'] ?? '';

          // Save to SharedPreferences for future use
          await prefs.setString('user_name', userName!);
          await prefs.setString('user_phone', userPhone!);
        }
      }

      print('User Name: $userName');
      print('User Phone: $userPhone');

      // Get user initials from user name
      final initials = userName != null && userName.isNotEmpty
          ? userName.trim().split(' ').map((name) => name[0]).join('').toUpperCase()
          : '';
    
      await FirebaseFirestore.instance.collection('posts').add({
        'username': userName,
        'content': content,
        'phone': userPhone,
        'user_id': user.uid,
        'avatar_url': 'https://ui-avatars.com/api/?background=0D8ABC&color=fff&name=$initials&rounded=true',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Close the bottom sheet
      Navigator.pop(context);
      
      // Show success message
      _showSuccessMessage(context);

      // Refresh the posts
      _loadPosts();
    } catch (e) {
      // Handle any errors, e.g., show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add post: $e')),
      );
    }
  }

  // Add this new method to load posts
  Future<void> _loadPosts() async {
    setState(() => _isPostsLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (mounted) {
        setState(() {
          posts = snapshot.docs.map((doc) => doc.data()).toList();
          _isPostsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading posts: $e');
      if (mounted) {
        setState(() => _isPostsLoading = false);
      }
    }
  }

  void _showAddToContactsDialog(BuildContext context, Contact contact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add to Contacts'),
          content: Text('Do you want to add ${contact.displayName} to your contacts?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                // TODO: Implement add to contacts functionality
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${contact.displayName} added to your contacts")),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showNewPostBottomSheet(BuildContext context, String username) {
    String postContent = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  hintText: "What you need ?",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                maxLines: 5,
                onChanged: (value) => postContent = value,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _addPost(context, username, postContent);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4845F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Post', style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessMessage(BuildContext context) {
    OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.1,
        width: MediaQuery.of(context).size.width,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Post added successfully',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // Remove the overlay after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  Widget _buildFriendRequestCard(Map<String, dynamic> request) {
    print("Friend request data: in card");
    print(request);
    String senderName = request['senderName'] ?? 'Unknown';
    String senderPhone = request['senderPhone'] ?? '';

    print("Total contacts: ${contacts.length}");

    int contactsChecked = 0;
    bool found = false;
    for (var contact in contacts) {
      contactsChecked++;
      print("Checking contact $contactsChecked: ${contact.displayName} ${contact.phones}");
      if (contact.phones.isNotEmpty) {
        for (var phone in contact.phones) {
         //check if phone number is equal to sender phone number
           String cleanPhone1 = senderPhone.replaceAll(RegExp(r'\D'), '');
    String cleanPhone2 = phone.number.replaceAll(RegExp(r'\D'), '');
    print("Comparing $cleanPhone1 and $cleanPhone2");
    print("Clean numbers: $cleanPhone1 and $cleanPhone2");
    if (cleanPhone1 == cleanPhone2) {
      senderName = contact.displayName;
      found = true;
      break;
    }
      //if clean phone1 or clean phone2 length is 12 , find which one is 12, remove first 2 dight from that
      if (cleanPhone1.length == 12) {
        cleanPhone1 = cleanPhone1.substring(2);
      }
      if (cleanPhone2.length == 12) {
        cleanPhone2 = cleanPhone2.substring(2);
      }
      if (cleanPhone1 == cleanPhone2) {
        senderName = contact.displayName;
        found = true;
        break;
      }
        }
        if (found) break;

      }
    }

    print("Contacts checked: $contactsChecked");

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$senderName wants to be your friend',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              request['senderPhone'],
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _respondToFriendRequest(request, 'rejected'),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _respondToFriendRequest(request, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4845F),
                  ),
                  child: Text('Accept',style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respondToFriendRequest(Map<String, dynamic> request, String status) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: request['senderId'])
          .where('recipientId', isEqualTo: request['recipientId'])
          .where('status', isEqualTo: 'pending')
          .get();

      if (requestDoc.docs.isNotEmpty) {
        await requestDoc.docs.first.reference.update({'status': status});

        if (status == 'accepted') {
          print("Adding friend ${request['senderId']} and ${request['recipientId']}");
          // Add users to each other's friends list
          await _addFriend(request['senderId'], request['recipientId']);
        }

        setState(() {
          friendRequests.removeWhere((r) => 
            r['senderId'] == request['senderId'] && 
            r['recipientId'] == request['recipientId']
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Friend request ${status == 'accepted' ? 'accepted' : 'rejected'}")),
        );
      }
    } catch (e) {
      print('Error responding to friend request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to respond to friend request: ${e.toString()}")),
      );
    }
  }

  Future<void> _addFriend(String userId1, String userId2) async {
    final batch = FirebaseFirestore.instance.batch();
    print('Adding friend $userId1 and $userId2');

    // Reference to the 'Network' collection
    final networkCollection = FirebaseFirestore.instance.collection('Network');

    // Check if the 'Network' collection exists, if not, create it
    final networkCollectionExists = await networkCollection.limit(1).get();
    if (networkCollectionExists.docs.isEmpty) {
      // If the collection doesn't exist, create it by adding a dummy document
      await networkCollection.add({'dummy': true});
      // Then delete the dummy document
      await networkCollection.where('dummy', isEqualTo: true).get().then((snapshot) {
        for (DocumentSnapshot doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
    }

    final user1Ref = networkCollection.doc(userId1);
    final user2Ref = networkCollection.doc(userId2);

    // Check if documents exist and create them if they don't
    final user1Doc = await user1Ref.get();
    final user2Doc = await user2Ref.get();

    if (!user1Doc.exists) {
      batch.set(user1Ref, {'friends': []});
    }
    if (!user2Doc.exists) {
      batch.set(user2Ref, {'friends': []});
    }

    // Now update the friends arrays
    batch.update(user1Ref, {
      'friends': FieldValue.arrayUnion([userId2])
    });

    batch.update(user2Ref, {
      'friends': FieldValue.arrayUnion([userId1])
    });

    await batch.commit();
  }
}