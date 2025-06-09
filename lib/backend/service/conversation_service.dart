import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/conversation.dart';
import './cert_service.dart';

import '../model/message.dart';

class ConversationService {
  final _db = FirebaseFirestore.instance;

  Future<void> createChatRoom(String newUserId) async {
    final usersSnapshot = await _db.collection('users').get();
    final otherUserIds =
        usersSnapshot.docs
            .map((doc) => doc.id)
            .where((uid) => uid != newUserId)
            .toList();

    for (final otherUid in otherUserIds) {
      final roomQuery =
          await _db
              .collection('chatRooms')
              .where('participants', arrayContains: newUserId)
              .get();

      final exists = roomQuery.docs.any((doc) {
        final participants = List<String>.from(doc['participants']);
        return participants.contains(otherUid) &&
            participants.contains(newUserId);
      });

      if (!exists) {
        final roomId = _db.collection('chatRooms').doc().id;

        final newChatRoom = ChatRoom(
          roomId: roomId,
          participants: [newUserId, otherUid],
          lastMessage: null,
          updatedAt: null,
          unreadCount: {newUserId: 0, otherUid: 0},
        );

        await _db.collection('chatRooms').doc(roomId).set(newChatRoom.toMap());
      }
    }
  }

  Stream<List<Map<String, dynamic>>> chatRoomsStream(String currentUserId) {
    return _db
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> chatRoom = [];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final participants = List<String>.from(data['participants']);
            final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
            );

            // Fetch the other user's profile
            final userSnap =
                await _db.collection('users').doc(otherUserId).get();
            final userData = userSnap.data();

            chatRoom.add({
              'roomId': doc.id,
              'name': userData?['name'] ?? 'Unknown',
              'image':
                  (userData?['imageUrl']?.isNotEmpty ?? false)
                      ? userData!['imageUrl']
                      : '',
              'online': userData?['online'] ?? false,
              'lastMessage': data['lastMessage']?['content'] ?? '',
              'time':
                  data['updatedAt'] != null
                      ? _formatTime(data['updatedAt'])
                      : '',
              'unread': data['unreadCount']?[currentUserId] ?? 0,
            });
          }
          return chatRoom;
        });
  }

  String _formatTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} hour';
    return '${diff.inDays} day';
  }

  Future<void> sendMessage(
    String roomId,
    String senderId,
    String content,
  ) async {
    print("Sending message in room: $roomId from user: $senderId");
    final userSignature = CertService.signMessage(senderId, content);
    final userDoc = await _db.collection('users').doc(senderId).get();
    final certId = userDoc['certId'];
    final chatRoomDoc = await _db.collection('chatRooms').doc(roomId).get();
    final participants = List<String>.from(chatRoomDoc['participants']);

    final message = Message(
      senderId: senderId,
      content: content,
      attachedCert: certId,
      userSignature: await userSignature,
      verified: "Verifying",
      timestamp: DateTime.now(),
    );

    await _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .add(message.toMap());

    // Increment unread count for other participants
    Map<String, dynamic> unreadUpdates = {};
    for (var participant in participants) {
      if (participant == senderId) {
        unreadUpdates['unreadCount.$participant'] = 0;
      } else {
        unreadUpdates['unreadCount.$participant'] = FieldValue.increment(1);
      }
    }

    await _db.collection('chatRooms').doc(roomId).update({
      'lastMessage': message.toMap(),
      'updatedAt': message.timestamp,
        ...unreadUpdates,
    });
  }

  Stream<QuerySnapshot> messageStream(String roomId, {int limit = 20}) {
    return _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true) // newest first
        .limit(limit)
        .snapshots();
  }

  // Fetch more messages older than lastDoc for pagination
  Future<List<QueryDocumentSnapshot>> fetchMoreMessages(
    String roomId,
    QueryDocumentSnapshot lastDoc, {
    int limit = 20,
  }) async {
    final snapshot =
        await _db
            .collection('rooms')
            .doc(roomId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .startAfterDocument(lastDoc)
            .limit(limit)
            .get();

    return snapshot.docs;
  }
}
