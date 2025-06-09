import 'package:cloud_firestore/cloud_firestore.dart';

import 'message.dart';

  class ChatRoom {
  final String roomId;
  final List<String> participants; // [uid1, uid2]
  final Message? lastMessage;
  final DateTime? updatedAt;
  final Map<String, int> unreadCount;

  ChatRoom({
    required this.roomId,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadCount,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> data) => ChatRoom(
    roomId: data['roomId'],
    participants: List<String>.from(data['participants']),
    updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    unreadCount: Map<String, int>.from(data['unreadCount']),
    lastMessage: data['lastMessage'] != null
        ? Message.fromMap(data['lastMessage'])
        : null,
  );

  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'participants': participants,
    'lastMessage': lastMessage?.toMap(),
    'updatedAt': updatedAt,
    'unreadCount': unreadCount,
  };
}
