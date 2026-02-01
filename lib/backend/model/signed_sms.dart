import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing signed SMS records in Firestore
/// Used for verifying SMS authenticity between sender and receiver
class SignedSms {
  final String id;
  final String senderPhoneNumber;
  final String receiverPhoneNumber;
  final String messageHash; // SHA-256 hash of the message content
  final String signature; // RSA signature of the message hash
  final String certId; // Certificate ID used for signing
  final String senderId; // User ID of the sender
  final DateTime timestamp;
  final DateTime? expiresAt; // Optional: auto-expire old records

  SignedSms({
    required this.id,
    required this.senderPhoneNumber,
    required this.receiverPhoneNumber,
    required this.messageHash,
    required this.signature,
    required this.certId,
    required this.senderId,
    required this.timestamp,
    this.expiresAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderPhoneNumber': senderPhoneNumber,
    'receiverPhoneNumber': receiverPhoneNumber,
    'messageHash': messageHash,
    'signature': signature,
    'certId': certId,
    'senderId': senderId,
    'timestamp': Timestamp.fromDate(timestamp),
    'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
  };

  factory SignedSms.fromMap(Map<String, dynamic> data) => SignedSms(
    id: data['id'] ?? '',
    senderPhoneNumber: data['senderPhoneNumber'] ?? '',
    receiverPhoneNumber: data['receiverPhoneNumber'] ?? '',
    messageHash: data['messageHash'] ?? '',
    signature: data['signature'] ?? '',
    certId: data['certId'] ?? '',
    senderId: data['senderId'] ?? '',
    timestamp: (data['timestamp'] as Timestamp).toDate(),
    expiresAt:
        data['expiresAt'] != null
            ? (data['expiresAt'] as Timestamp).toDate()
            : null,
  );

  @override
  String toString() =>
      'SignedSms(from: $senderPhoneNumber, to: $receiverPhoneNumber, hash: ${messageHash.substring(0, 16)}...)';
}

/// Result of SMS verification
class SmsVerificationResult {
  final bool isVerified;
  final String status; // "Valid" or "Invalid"
  final String? senderName;
  final String? certId;
  final DateTime? signedAt;
  final String? errorMessage;

  SmsVerificationResult({
    required this.isVerified,
    required this.status,
    this.senderName,
    this.certId,
    this.signedAt,
    this.errorMessage,
  });

  factory SmsVerificationResult.valid({
    required String senderName,
    required String certId,
    required DateTime signedAt,
  }) => SmsVerificationResult(
    isVerified: true,
    status: "Valid",
    senderName: senderName,
    certId: certId,
    signedAt: signedAt,
  );

  factory SmsVerificationResult.invalid(String reason) => SmsVerificationResult(
    isVerified: false,
    status: "Invalid",
    errorMessage: reason,
  );

  /// All these now return "Invalid" status
  factory SmsVerificationResult.notFound() => SmsVerificationResult(
    isVerified: false,
    status: "Invalid", // Changed from "Not Found"
    errorMessage: "No signed record found for this SMS",
  );

  factory SmsVerificationResult.phoneMismatch() => SmsVerificationResult(
    isVerified: false,
    status: "Invalid", // Changed from "Phone Mismatch"
    errorMessage: "Sender phone number doesn't match certificate",
  );

  factory SmsVerificationResult.expired() => SmsVerificationResult(
    isVerified: false,
    status: "Invalid", // Changed from "Expired"
    errorMessage: "The signature record has expired",
  );
}

/// Model representing an SMS message (incoming or outgoing)
class SmsMessage {
  final String address; // Phone number
  final String body;
  final DateTime timestamp;
  final SmsType type;
  final int? threadId;

  SmsMessage({
    required this.address,
    required this.body,
    required this.timestamp,
    required this.type,
    this.threadId,
  });

  factory SmsMessage.fromMap(Map<String, dynamic> data) => SmsMessage(
    address: data['address'] ?? '',
    body: data['body'] ?? '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(data['date'] ?? 0),
    type: SmsType.fromInt(data['type'] ?? 1),
    threadId: data['thread_id'],
  );
}

enum SmsType {
  inbox(1),
  sent(2),
  draft(3),
  outbox(4),
  failed(5),
  queued(6);

  final int value;
  const SmsType(this.value);

  static SmsType fromInt(int value) {
    return SmsType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SmsType.inbox,
    );
  }
}
