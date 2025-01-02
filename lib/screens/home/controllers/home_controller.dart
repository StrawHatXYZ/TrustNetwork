import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/post_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/contacts_service.dart';
import '../components/filter_dialog.dart';
import '../components/new_post_sheet.dart';
import '../../../providers/user_provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class HomeController extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();
  final PostService _postService = PostService();
  final ContactService _contactService = ContactService();
  final ChatService _chatService = ChatService();

  int _currentIndex = 0;
  String _userName = '';
  String _userId = '';
  List<Map<String, dynamic>> _posts = [];
  List<Contact> _contacts = [];
  List<Contact> _registeredContacts = [];
  bool _isLoading = true;
  bool _isPostsLoading = true;

  // Getters
  int get currentIndex => _currentIndex;
  String get userName => _userName;
  String get userId => _userId;
  List<Map<String, dynamic>> get posts => _posts;
  List<Contact> get contacts => _contacts;
  List<Contact> get registeredContacts => _registeredContacts;
  bool get isLoading => _isLoading;
  bool get isPostsLoading => _isPostsLoading;

  Future<void> initialize(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load essential data first
      await _loadUserData(context);
      await _loadPosts();
      
      // Request contact permissions only once during app initialization
      await _initializeContacts();
    } catch (e) {
      print('Error during initialization: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserData(BuildContext context) async {
    await context.read<UserProvider>().loadUserData();
    _userName = context.read<UserProvider>().userName;
    _userId = context.read<UserProvider>().userId;
    notifyListeners();
  }

  Future<void> _loadPosts() async {
    _isPostsLoading = true;
    notifyListeners();
    
    try {
      _posts = await _postService.getPosts();
    } catch (e) {
      print('Error loading posts: $e');
    } finally {
      _isPostsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadRegisteredContacts() async {
    try {
      _registeredContacts = await ContactService.getRegisteredContacts(_contacts);
      notifyListeners();
    } catch (e) {
      print('Error loading registered contacts: $e');
      _registeredContacts = [];
      notifyListeners();
    }
  }

  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> refreshPosts() async {
    await _initializeContacts();
    await _loadPosts();
    notifyListeners();
  }

  void performSearch(String query) {
    switch (_currentIndex) {
      case 0:
        _handlePostSearch(query);
        break;
      case 1:
        // Handled by ContactsPage
        notifyListeners();
        break;
      case 2:
        // Handle chat search
        break;
    }
  }

  void _handlePostSearch(String query) {
    if (query.isEmpty) {
      _loadPosts();
    } else {
      _posts = _posts.where((post) =>
        post['content'].toString().toLowerCase().contains(query.toLowerCase()) ||
        post['username'].toString().toLowerCase().contains(query.toLowerCase())
      ).toList();
      notifyListeners();
    }
  }

  Future<void> createChatRoom(Contact contact, String postAuthorId) async {
    try {
      await _chatService.createOrJoinChatRoom(contact, postAuthorId);
    } catch (e) {
      print('Error creating chat room: $e');
    }
  }

  void showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        onApplyFilters: (location, title, company, skills) {
          _applyFilters(location, title, company, skills);
        },
      ),
    );
  }

  void showNewPostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NewPostSheet(
        onPost: (content, jobTitle, company, location, skills) async {
          await _postService.createPost(
            content,
            _userName,
             jobTitle,
            company,
           location,
           skills,
          );
          await _loadPosts();
        },
      ),
    );
  }

  void _applyFilters(String location, String title, String company, String skills) {
    List<String> filterTerms = [];
    
    if (location.isNotEmpty) filterTerms.add('location:$location');
    if (title.isNotEmpty) filterTerms.add('title:$title');
    if (company.isNotEmpty) filterTerms.add('company:$company');
    if (skills.isNotEmpty) filterTerms.add('skills:$skills');
    
    String combinedQuery = filterTerms.join(' ');
    searchController.text = combinedQuery;
    performSearch(combinedQuery);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeContacts() async {
    try {
      // Initialize with empty lists
      _contacts = [];
      _registeredContacts = [];
      notifyListeners();

      // Request permission and initialize contacts
      bool hasPermission = await ContactService.requestInitialPermission();
      if (hasPermission) {
        
        // Store in Firebase
        print("stored contacts in firebase");
        await ContactService.storeContactsInFirebase(userId);
        _contacts = await ContactService.getContactsFromFirebase(userId);
        print("got contacts from firebase");
        if (_contacts.isNotEmpty) {
          _registeredContacts = await ContactService.getRegisteredContacts(_contacts);
        }
      }
      
      notifyListeners();
    } catch (e) {
      print('Contact initialization error: $e');
      _contacts = [];
      _registeredContacts = [];
      notifyListeners();
    }
  }
}