import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderId;
  final String content;
  final String attachedCert;
  final String userSignature;
  final String verified;
  final DateTime timestamp;

  Message({
    required this.senderId,
    required this.content,
    required this.attachedCert,
    this.verified = "Verifying",
    required this.userSignature,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'content': content,
    'attachedCert': attachedCert,
    'verified': verified,
    'userSignature': userSignature,
    'timestamp': Timestamp.fromDate(timestamp),
  };

  factory Message.fromMap(Map<String, dynamic> data) => Message(
    senderId: data['senderId'],
    content: data['content'],
    attachedCert: data['attachedCert'],
    verified: data['verified'],
    userSignature: data['userSignature'],
    timestamp: (data['timestamp'] as Timestamp).toDate(),
  );
}

