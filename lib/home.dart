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
  List<Contact> friendContacts = [];
  String _userName = 'John Doe'; // Add this line

  // Update loading state variables to be more specific
  bool _isLoading = true;
  bool _isPostsLoading = true;
  bool _isContactsLoading = true;
  bool _isRegisteredContactsLoading = true;  // Add this line

  @override
  void initState() {
    super.initState();
    // Call async work without awaiting
    ContactService.initializeContactsInFirebase().then((_) {
      _loadAllData();
    });
  }

  // Update _loadAllData method
  Future<void> _loadAllData() async {
    try {
      await Future.wait([
        _loadContacts(),
        _loadPosts(),
        _loadUserName(),
        _loadRegisteredContacts(),
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

      // Get current user's phone number
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('registered_users')
          .doc(currentUser.uid)
          .get();

      // final currentUserPhone = currentUserDoc.data()?['phoneNumber']?.replaceAll(RegExp(r'\D'), '');

      // Get existing friends
      final friendsDoc = await FirebaseFirestore.instance.collection('Network').doc(currentUser.uid).get();
      List<String> friendIds = [];
      if (friendsDoc.exists) {
        friendIds = List<String>.from(friendsDoc.data()?['friends'] ?? []);
      }

      for (var contact in contacts) {
        for (var user in registeredUsers.docs) {
          if (contact.phones.isNotEmpty) {
            String contactPhone = contact.phones.first.number.replaceAll(RegExp(r'\D'), '');
            String userPhone = user.data()['phoneNumber'].replaceAll(RegExp(r'\D'), '');
            
            if (contactPhone == userPhone && !friendIds.contains(user.id) && user.id != currentUser.uid) {
              // Automatically add to network
              await _addMutualConnection(currentUser.uid, user.id);
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
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

  Future<void> _addMutualConnection(String userId1, String userId2) async {
    final batch = FirebaseFirestore.instance.batch();
    final networkCollection = FirebaseFirestore.instance.collection('Network');

    final user1Ref = networkCollection.doc(userId1);
    final user2Ref = networkCollection.doc(userId2);

    // Create or update both users' network documents
    final user1Doc = await user1Ref.get();
    final user2Doc = await user2Ref.get();

    if (!user1Doc.exists) {
      batch.set(user1Ref, {'friends': [userId2]});
    } else {
      batch.update(user1Ref, {
        'friends': FieldValue.arrayUnion([userId2])
      });
    }

    if (!user2Doc.exists) {
      batch.set(user2Ref, {'friends': [userId1]});
    } else {
      batch.update(user2Ref, {
        'friends': FieldValue.arrayUnion([userId1])
      });
    }

    await batch.commit();
  }

  // Future<void> _loadFriendContacts() async {
  //   try {
  //     final friends = await FriendService.getFriendContacts();
  //     setState(() {
  //       friendContacts = friends;
  //     });
  //   } catch (e) {
  //     print('Error loading friend contacts: $e');
  //   }
  // }

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
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _performSearch('');
                          });
                        },
                      ),
                    if (_currentIndex == 1)
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {
                          _showFilterDialog(context);
                        },
                      ),
                  ],
                ),
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
      body: RefreshIndicator(
        color: const Color(0xFFF4845F),
        onRefresh: _loadPosts,
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Recent Posts',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
            ),
            if (_isPostsLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
                  ),
                ),
              )
            else if (posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No posts yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPostCard(posts[index]),
                  childCount: posts.length,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewPostBottomSheet(context, username),
        backgroundColor: const Color(0xFFF4845F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Post', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    bool isCurrentUserPost = currentUser?.uid == post['user_id'];

    List<Contact> matchingContacts = [];
    if (!isCurrentUserPost) {
      // Get matching contacts that are registered in the app
      matchingContacts = contacts.where((contact) {
        // Skip if contact has no organization info
        if (contact.organizations.isEmpty) return false;
        
        // Check if content words match the contact's title
        String title = contact.organizations.first.title?.toLowerCase() ?? '';
        List<String> contentWords = post['content'].toString().toLowerCase().split(' ');
        bool hasMatchingTitle = contentWords.any((word) => title.contains(word));
        
        // Only return true if contact is registered in the app
        return hasMatchingTitle && registeredContacts.any((regContact) => 
          contact.phones.any((phone) => 
            regContact.phones.any((regPhone) => 
              arePhoneNumbersEqual(phone.number, regPhone.number)
            )
          )
        );
      }).toList();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF4845F),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    backgroundImage: post['avatar_url'] != null
                        ? NetworkImage(post['avatar_url'] as String)
                        : null,
                    child: post['avatar_url'] == null
                        ? Text(
                            (post['username'] as String? ?? '?')[0],
                            style: const TextStyle(
                              fontSize: 20,
                              color: Color(0xFFF4845F),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['username'] as String? ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(post['timestamp']),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              post['content'] as String? ?? '',
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          if (!isCurrentUserPost && matchingContacts.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Found ${matchingContacts.length} related contact${matchingContacts.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF4845F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showMatchingContacts(
                              matchingContacts,
                              post['user_id'] as String,
                            );
                          },
                          icon: const Icon(Icons.people, size: 18),
                          label: const Text('Connect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF4845F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
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

      // Create a Set of unique participant IDs
      final Set<String> uniqueParticipants = {
        currentUser.uid,
        contactUserId,
        postAuthorId,
      };

      // If we don't have exactly 3 unique participants, show error
      if (uniqueParticipants.length != 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot create chat room with duplicate participants')),
        );
        return;
      }

      // Convert Set back to List for Firestore
      final List<String> participants = uniqueParticipants.toList();

      // Check if a chat room already exists with these participants
      final existingRoomQuery = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .get();

      String? existingRoomId;

      // Check each room for exact participant match
      for (var doc in existingRoomQuery.docs) {
        List<dynamic> roomParticipants = doc['participants'];
        if (roomParticipants.length == participants.length &&
            roomParticipants.toSet().containsAll(participants)) {
          existingRoomId = doc.id;
          break;
        }
      }

      String roomId;
      if (existingRoomId != null) {
        roomId = existingRoomId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joining existing chat room with ${contact.displayName}')),
        );
      } else {
        // Create new room ID from sorted participant IDs
        roomId = participants.join('_');
        
        // Create the chat room document
        await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).set({
          'participants': participants,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New chat room created with ${contact.displayName}')),
        );
      }

      // Navigate to the chat room
      Navigator.of(context).push(
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

  void _removeContact(Contact contact) {
    setState(() {
      registeredContacts.removeWhere((item) => item.id == contact.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${contact.displayName} removed from suggestions")),
    );
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

  Future<void> _loadRegisteredContacts() async {
    setState(() => _isRegisteredContactsLoading = true);
    try {
      final registeredUsers = await FirebaseFirestore.instance
          .collection('registered_users')
          .get();
      
      // Filter contacts to only include those registered in the app
      registeredContacts = contacts.where((contact) {
        return contact.phones.any((phone) {
          return registeredUsers.docs.any((userDoc) {
            String userPhone = userDoc.data()['phoneNumber'] ?? '';
            return arePhoneNumbersEqual(phone.number, userPhone);
          });
        });
      }).toList();

      if (mounted) {
        setState(() {
          _isRegisteredContactsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading registered contacts: $e');
      if (mounted) {
        setState(() => _isRegisteredContactsLoading = false);
      }
    }
  }

  void _showFilterDialog(BuildContext context) {
    String location = '';
    String title = '';
    String company = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Contacts',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Filter Fields
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterSection(
                            'Location',
                            'Search by location',
                            Icons.location_on_outlined,
                            (value) => setState(() => location = value),
                          ),
                          const SizedBox(height: 24),
                          _buildFilterSection(
                            'Job Title',
                            'Search by job title',
                            Icons.work_outline,
                            (value) => setState(() => title = value),
                          ),
                          const SizedBox(height: 24),
                          _buildFilterSection(
                            'Company',
                            'Search by company name',
                            Icons.business_outlined,
                            (value) => setState(() => company = value),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _performSearch('');
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFFF4845F)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Clear All',
                              style: TextStyle(color: Color(0xFFF4845F)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _applyFilters(location, title, company);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF4845F),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Apply Filters',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection(
    String label,
    String hint,
    IconData icon,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3142),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(icon, color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _applyFilters(String location, String title, String company) {
    // Build filter query in a consistent format
    List<String> filterTerms = [];
    
    if (location.isNotEmpty) filterTerms.add('location:$location');
    if (title.isNotEmpty) filterTerms.add('title:$title');
    if (company.isNotEmpty) filterTerms.add('company:$company');
    
    // If no filters are set, clear the search
    if (filterTerms.isEmpty) {
      _performSearch('');
      return;
    }
    
    // Join all filter terms with spaces to create a single search query
    String combinedQuery = filterTerms.join(' ');
    
    // Update the search controller text and perform search
    setState(() {
      _searchController.text = combinedQuery;
      _performSearch(combinedQuery);
    });
  }
}
