import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_room_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('Please log in to view chats'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Print the entire snapshot data
        print('Debug: Snapshot data: ${snapshot.data}');
        
        // Print individual documents in the snapshot
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            print('Document ID: ${doc.id}');
            print('Document data: ${doc.data()}');
          }
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No chats found'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chatRoom = snapshot.data!.docs[index];
            final participants = List<String>.from(chatRoom['participants']);
            final isGroupChat = participants.length > 2;

            if (isGroupChat) {
              return _buildGroupChatTile(context, chatRoom, currentUser!.uid);
            } else {
              return _buildOneOnOneChatTile(context, chatRoom, currentUser!.uid);
            }
          },
        );
      },
    );
  }

  Widget _buildGroupChatTile(BuildContext context, DocumentSnapshot chatRoom, String currentUserId) {
    final participants = List<String>.from(chatRoom['participants']);
    participants.remove(currentUserId);

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait(participants.map((userId) => 
        FirebaseFirestore.instance.collection('registered_users').doc(userId).get()
      )),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: Text('Loading...'));
        }

        final otherUsers = snapshot.data!;
        final memberNames = otherUsers
            .map((user) => user['name'] as String)
            .join(', ');

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.group, color: Colors.white),
          ),
          title: Text('Group Chat'),
          subtitle: Text(memberNames),
          trailing: chatRoom['lastMessageTimestamp'] != null
              ? Text(
                  _formatTimestamp(chatRoom['lastMessageTimestamp'] as Timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                )
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomScreen(
                  roomId: chatRoom.id,
                  contactName: 'Group Chat',
                  participantNames: memberNames,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOneOnOneChatTile(BuildContext context, DocumentSnapshot chatRoom, String currentUserId) {
    final participants = List<String>.from(chatRoom['participants']);
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => 'Unknown User',
    );

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('registered_users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const ListTile(title: Text('Loading...'));
        }

        final otherUserData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final otherUserName = otherUserData?['name'] ?? 'Unknown User';

        return ListTile(
          leading: CircleAvatar(
            child: Text(otherUserName[0]),
          ),
          title: Text(otherUserName),
          subtitle: Text(chatRoom['lastMessage'] ?? 'No messages yet'),
          trailing: chatRoom['lastMessageTimestamp'] != null
              ? Text(
                  _formatTimestamp(chatRoom['lastMessageTimestamp'] as Timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                )
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomScreen(
                  roomId: chatRoom.id,
                  contactName: otherUserName,
                  participantNames: otherUserName,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _launchURL() async {
    const url = 'https://console.firebase.google.com/project/_/firestore/indexes';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
