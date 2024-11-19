import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

  

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String contactName;
  final String participantNames;

  const ChatRoomScreen({Key? key, required this.roomId, required this.contactName, required this.participantNames}) : super(key: key);

  @override
  _ChatRoomScreenState createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, String> _userNames = {};
  bool _isLoadingUsers = true;
  String _currentUserName = 'Unknown User';
  String _participantPhoneNumber = '';
  final List<Map<String, dynamic>> _pendingMessages = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadUserNames();
    _loadParticipantDetails();
  }

  void _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserName = prefs.getString('user_name') ?? 'Unknown User';
      // Add current user to userNames map
      if (_auth.currentUser != null) {
        _userNames[_auth.currentUser!.uid] = _currentUserName;
      }
    });
  }

  void _loadUserNames() async {
    try {
      _firestore.collection('registered_users').snapshots().listen((snapshot) {
        setState(() {
          for (var doc in snapshot.docs) {
            _userNames[doc.id] = doc.data()['name'] ?? 'Unknown User';
          }
          _isLoadingUsers = false;
        });
      });
    } catch (e) {
      print('Error loading user names: $e');
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  void _loadParticipantDetails() async {
    try {
      final roomDoc = await _firestore
          .collection('chat_rooms')
          .doc(widget.roomId)
          .get();
      
      if (!roomDoc.exists) return;

      final data = roomDoc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      final participantDetails = data['participantDetails'] as Map<String, dynamic>;

      // Get the other participant's ID (not current user)
      final otherParticipantId = participants.firstWhere(
        (id) => id != _auth.currentUser?.uid,
        orElse: () => '',
      );

      if (otherParticipantId.isNotEmpty) {
        setState(() {
          _participantPhoneNumber = participantDetails[otherParticipantId]['phoneNumber'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading participant details: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final messageText = _messageController.text.trim();
    final localTimestamp = Timestamp.now();
    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}'; // Create unique ID

    // Create the message locally
    final newMessage = {
      'text': messageText,
      'senderId': user.uid,
      'senderName': _currentUserName,
      'timestamp': localTimestamp,
      'isPending': true,
      'messageId': messageId, // Add unique ID to pending message
    };

    setState(() {
      _pendingMessages.add(newMessage);
      _messageController.clear();
    });

    try {
      // Sync with Firebase in the background
      final timestamp = FieldValue.serverTimestamp();
      
      await _firestore
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': user.uid,
        'senderName': _currentUserName,
        'timestamp': timestamp,
        'messageId': messageId, // Add same ID to Firebase message
      });

      // Update chat room's last message
      await _firestore
          .collection('chat_rooms')
          .doc(widget.roomId)
          .update({
        'lastMessage': messageText,
        'lastMessageTimestamp': timestamp,
        'lastMessageSender': user.uid,
        'lastMessageSenderName': _currentUserName,
      });

      // Remove from pending messages after successful sync
      setState(() {
        _pendingMessages.removeWhere((msg) => msg['messageId'] == messageId);
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.white,
        elevation: 1, // Subtle elevation
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                widget.contactName[0].toUpperCase(),
                style: TextStyle(color: Colors.blue.shade700),
              ),
              radius: 18,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.contactName,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_participantPhoneNumber.isNotEmpty)
                    Text(
                      _participantPhoneNumber,
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
      body: Container(
        color: Colors.grey[50], // Lighter background
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chat_rooms')
                    .doc(widget.roomId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || _isLoadingUsers) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    reverse: true,
                    itemCount: messages.length + _pendingMessages.length,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemBuilder: (context, index) {
                      if (index < _pendingMessages.length) {
                        final pendingMessage = _pendingMessages[_pendingMessages.length - 1 - index];
                        
                        // Check if this message already exists in Firebase messages
                        final messageExists = messages.any((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['messageId'] == pendingMessage['messageId'];
                        });

                        // Skip rendering if message already exists in Firebase
                        if (messageExists) {
                          return SizedBox.shrink();
                        }

                        final isMe = pendingMessage['senderId'] == _auth.currentUser?.uid;
                        final timestamp = pendingMessage['timestamp'] as Timestamp;
                        final timeString = DateFormat('h:mm a').format(timestamp.toDate());
                        final senderName = pendingMessage['senderName'];

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            margin: EdgeInsets.only(
                              bottom: 6,
                              left: isMe ? 48 : 0,
                              right: isMe ? 0 : 48,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isMe 
                                ? Color(0xFFFF7F50)
                                : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                                bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe && widget.participantNames.contains(','))
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      senderName,
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                Text(
                                  pendingMessage['text'] as String,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 15,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      timeString,
                                      style: TextStyle(
                                        color: isMe 
                                          ? Colors.white.withOpacity(0.9)
                                          : Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all,
                                        size: 14,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Handle Firebase messages
                      final message = messages[index - _pendingMessages.length].data() as Map<String, dynamic>;
                      final senderId = message['senderId'] as String;
                      final isMe = senderId == _auth.currentUser?.uid;
                      final timestamp = message['timestamp'] as Timestamp?;
                      final timeString = timestamp != null
                          ? DateFormat('h:mm a').format(timestamp.toDate())
                          : '';
                      final senderName = message['senderName'] ?? _userNames[senderId] ?? 'Unknown User';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: EdgeInsets.only(
                            bottom: 6,
                            left: isMe ? 48 : 0,
                            right: isMe ? 0 : 48,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe 
                              ? Color(0xFFFF7F50)
                              : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                              bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe && widget.participantNames.contains(','))
                                Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    senderName,
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              Text(
                                message['text'] as String,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                  height: 1.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeString,
                                    style: TextStyle(
                                      color: isMe 
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: RawKeyboardListener(
                      focusNode: _focusNode,
                      onKey: (RawKeyEvent event) {
                        if (event.isKeyPressed(LogicalKeyboardKey.enter) && 
                            !HardwareKeyboard.instance.isShiftPressed) {
                          _sendMessage();
                          _messageController.clear();
                          _focusNode.unfocus();
                        }
                      },
                      child: TextField(
                        controller: _messageController,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: Color(0xFFFF7F50),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, size: 20),
                      color: Colors.white,
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
