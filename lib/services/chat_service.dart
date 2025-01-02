import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../utils/phone_utils.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createOrJoinChatRoom(Contact contact, String postAuthorId) async {
    print('createOrJoinChatRoom');
    print('contact: $contact');
    print('postAuthorId: $postAuthorId');
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No user logged in');
    }

    // Get the contact's user ID
    final contactSnapshot = await _firestore
        .collection('registered_users')
        .get();

    final contactDoc = contactSnapshot.docs.firstWhere(
      (doc) {
        final storedPhone = doc['phoneNumber'];
        return contact.phones.any((phone) => 
          PhoneUtils.arePhoneNumbersEqual(phone.number, storedPhone)
        );
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

    print('uniqueParticipants: $uniqueParticipants');
    final List<String> participants = uniqueParticipants.toList();

    // Check for existing chat room
    final existingRoomQuery = await _firestore
        .collection('chat_rooms')
        .get();

    String? existingRoomId;

    for (var doc in existingRoomQuery.docs) {
      List<dynamic> roomParticipants = doc['participants'];
      if (roomParticipants.length == participants.length &&
          roomParticipants.toSet().containsAll(participants)) {
        existingRoomId = doc.id;
        break;
      }
    }

    if (existingRoomId != null) {
      print('existingRoomId: $existingRoomId');
      return existingRoomId;
    }

    // Create new room ID and document
    final roomId = participants.join('_');
    await _firestore.collection('chat_rooms').doc(roomId).set({
      'participants': participants,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });

    print('roomId: $roomId');

    return roomId;
  }
}