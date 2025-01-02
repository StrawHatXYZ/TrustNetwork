import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trust/services/chat_service.dart';
class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final List<Contact> contacts;
  final List<Contact> registeredContacts;
  final Function(Contact, String) onConnect;

  const PostCard({
    required this.post,
    required this.contacts,
    required this.registeredContacts,
    required this.onConnect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    print('Building PostCard with content: ${post['content']}');
    final currentUser = FirebaseAuth.instance.currentUser;
    bool isCurrentUserPost = currentUser?.uid == post['user_id'];

    final matchingContacts = _getMatchingContacts(isCurrentUserPost);

    // print(post);
    // print("got post");
    // print(contacts);
    // print("got contacts");

    print(matchingContacts);
    print("got matching contacts");

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
          _buildHeader(),
          _buildContent(),
          if (matchingContacts.isNotEmpty)
            _buildConnectSection(context, matchingContacts),
        ],
      ),
    );
  }

  List<Contact> _getMatchingContacts(bool isCurrentUserPost) {
    // print('Starting _getMatchingContacts for post: ${post['content']}');

    // print('Processing post: ${post['content']} from company: ${post['company']} with title: ${post['job_title']}');

    return contacts.where((contact) {
      // print('\nChecking contact: ${contact.displayName}');
      
      // Skip if contact has no organizations
      if (contact.organizations.isEmpty) {
        // print('- Skipping: No organizations');
        return false;
      }
      
      // Get company names and normalize them
      String contactCompany = contact.organizations.first.company?.toLowerCase().trim() ?? '';
      String postCompany = (post['company'] ?? '').toString().toLowerCase().trim();
      
      // Get job titles and normalize them
      String contactTitle = contact.organizations.first.title?.toLowerCase().trim() ?? '';
      String postTitle = (post['job_title'] ?? '').toString().toLowerCase().trim();
      
        // print('- Contact company: "$contactCompany"');
        // print('- Post company: "$postCompany"');
        // print('- Contact title: "$contactTitle"');
        // print('- Post title: "$postTitle"');
      
      // Skip if no company information
      if (contactCompany.isEmpty || postCompany.isEmpty) {
        // print('- Skipping: Missing company info');
        return false;
      }
      
      // Check for company match
      bool hasMatchingCompany = contactCompany.contains(postCompany) || 
                               postCompany.contains(contactCompany);
      
      // Check for title match (if available)
      // bool hasMatchingTitle = true; // Default to true if no title to match
      // if (contactTitle.isNotEmpty && postTitle.isNotEmpty) {
      //   hasMatchingTitle = contactTitle.contains(postTitle) || 
      //                     postTitle.contains(contactTitle);
      // }
      
      bool isRegistered = registeredContacts.contains(contact);
      
      // print('- Matching results:');
      // print('  Company match: $hasMatchingCompany');
      // print('  Title match: $hasMatchingTitle');
      // print('  Is registered: $isRegistered');
      
      return hasMatchingCompany && isRegistered;
    }).toList();
  }

  Widget _buildHeader() {
    return Padding(
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
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Text(
        post['content'] as String? ?? '',
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildConnectSection(BuildContext context, List<Contact> matchingContacts) {
    return Container(
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
                  onPressed: () => _showMatchingContacts(context, matchingContacts),
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
    );
  }

  void _showMatchingContacts(BuildContext context, List<Contact> matchingContacts) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUserPost = currentUser?.uid == post['user_id'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Matching Contacts'),
          content: SingleChildScrollView(
            child: ListBody(
              children: matchingContacts.map((contact) => 
                ListTile(
                  title: Text(contact.displayName),
                  subtitle: Text(contact.organizations.isNotEmpty 
                    ? contact.organizations.first.title ?? 'No title' 
                    : 'No title'),
                  onTap: () async {
                    Navigator.pop(context);
                    ChatService().createOrJoinChatRoom(contact, post['user_id']);
                  },
                )
              ).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

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
}