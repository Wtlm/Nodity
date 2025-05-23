import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Nodity/backend/model/conversation.dart';
import 'package:Nodity/backend/service/cert_service.dart';

import '../model/message.dart';

class ConversationService {
  final _db = FirebaseFirestore.instance;
  final _currentUserId = FirebaseAuth.instance.currentUser!.uid;

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
          updatedAt: DateTime.now(),
          unreadCount: {newUserId: 0, otherUid: 0},
        );

        await _db.collection('chatRooms').doc(roomId).set(newChatRoom.toMap());
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessageList() async {
    final snapshot =
        await _db
            .collection('chatRooms')
            .where('participants', arrayContains: _currentUserId)
            .orderBy('updatedAt', descending: true)
            .get();

    List<Map<String, dynamic>> chatRoom = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants']);
      final otherUserId = participants.firstWhere((id) => id != _currentUserId);

      // Fetch the other user's profile
      final userSnap =
          await _db
              .collection('users')
              .doc(otherUserId)
              .get();
      final userData = userSnap.data();

      chatRoom.add({
        'roomId': doc.id,
        'name': userData?['name'] ?? 'Unknown',
        'image':
            (userData?['imageUrl']?.isNotEmpty ?? false)
                ? userData!['imageUrl']
                : null,
        'message': data['lastMessage']?['content'] ?? '',
        'time': _formatTime(data['updatedAt']),
        'unread': data['unreadCount']?[_currentUserId] ?? 0,
      });
    }
    return chatRoom;
  }

  String _formatTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} hour';
    return '${diff.inDays} day';
  }

  Future<void> sendMessage(String roomId, String senderId, String content) async {
    final userSignature = CertService.signMessage(senderId, content);
    final userDoc = await _db.collection('users').doc(senderId).get();
    final certId = userDoc['certId'];

    final message = Message(
      senderId: senderId,
      content: content,
      attachedCert: certId,
      userSignature: await userSignature,
      verified: null,
      timestamp: DateTime.now(),
    );

    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .add(message.toMap());
  }

  Stream<QuerySnapshot> messageStream(String roomId, {int limit = 20}) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true) // newest first
        .limit(limit)
        .snapshots();
  }

  // Fetch more messages older than lastDoc for pagination
  Future<List<QueryDocumentSnapshot>> fetchMoreMessages(String roomId, QueryDocumentSnapshot lastDoc, {int limit = 20}) async {
    final snapshot = await _db
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
