import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pointycastle/export.dart';
import '../model/signed_sms.dart';
import './cert_service.dart';

/// Service for handling SMS reading, signing, and verification
/// Uses platform channels to communicate with native Android code
class SmsService {
  static const MethodChannel _channel = MethodChannel('com.nodity/sms');
  static const EventChannel _smsReceivedChannel = EventChannel(
    'com.nodity/sms_received',
  );

  final _db = FirebaseFirestore.instance;
  final CertService _certService = CertService();

  StreamSubscription? _smsSubscription;
  final StreamController<SmsMessage> _incomingSmsController =
      StreamController.broadcast();

  /// Stream of incoming SMS messages
  Stream<SmsMessage> get incomingSmsStream => _incomingSmsController.stream;

  /// Initialize the SMS service and start listening for incoming SMS
  Future<void> initialize() async {
    _smsSubscription = _smsReceivedChannel.receiveBroadcastStream().listen((
      dynamic event,
    ) {
      if (event is Map) {
        final sms = SmsMessage.fromMap(Map<String, dynamic>.from(event));
        _incomingSmsController.add(sms);
      }
    });
  }

  /// Dispose resources
  void dispose() {
    _smsSubscription?.cancel();
    _incomingSmsController.close();
  }

  /// Check if SMS permissions are granted
  Future<bool> hasPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermissions');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking SMS permissions: ${e.message}');
      return false;
    }
  }

  /// Request SMS permissions from the user
  Future<bool> requestPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error requesting SMS permissions: ${e.message}');
      return false;
    }
  }

  /// Read recent SMS messages from inbox
  Future<List<SmsMessage>> readInboxMessages({int limit = 50}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getInboxMessages',
        {'limit': limit},
      );

      if (result == null) return [];

      return result
          .map((e) => SmsMessage.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } on PlatformException catch (e) {
      print('Error reading inbox messages: ${e.message}');
      return [];
    }
  }

  /// Read recent sent SMS messages
  Future<List<SmsMessage>> readSentMessages({int limit = 50}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getSentMessages',
        {'limit': limit},
      );

      if (result == null) return [];

      return result
          .map((e) => SmsMessage.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } on PlatformException catch (e) {
      print('Error reading sent messages: ${e.message}');
      return [];
    }
  }

  /// Compute SHA-256 hash of a message
  static String computeMessageHash(String message) {
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(utf8.encode(message)));
    return base64Encode(hash);
  }

  /// Sign and store an outgoing SMS
  /// Call this after the user sends an SMS
  Future<SignedSms?> signAndStoreSms({
    required String senderId,
    required String senderPhoneNumber,
    required String receiverPhoneNumber,
    required String messageContent,
  }) async {
    try {
      // Get user's certificate
      final userDoc = await _db.collection('users').doc(senderId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      final certId = userDoc.data()!['certId'] as String;

      // Compute message hash
      final messageHash = computeMessageHash(messageContent);

      // Sign the message content
      final signature = await CertService.signMessage(senderId, messageContent);

      // Create signed SMS record
      final docRef = _db.collection('signedSms').doc();
      final signedSms = SignedSms(
        id: docRef.id,
        senderPhoneNumber: _normalizePhoneNumber(senderPhoneNumber),
        receiverPhoneNumber: _normalizePhoneNumber(receiverPhoneNumber),
        messageHash: messageHash,
        signature: signature,
        certId: certId,
        senderId: senderId,
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(
          const Duration(days: 7),
        ), // Auto-expire after 7 days
      );

      // Store in Firestore
      await docRef.set(signedSms.toMap());

      print('SMS signed and stored: ${signedSms.id}');
      return signedSms;
    } catch (e) {
      print('Error signing SMS: $e');
      return null;
    }
  }

  /// Verify a received SMS against the backend
  Future<SmsVerificationResult> verifyReceivedSms({
    required String senderPhoneNumber,
    required String messageContent,
  }) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(senderPhoneNumber);
      final messageHash = computeMessageHash(messageContent);

      // Query for matching signed SMS records
      // Note: Using equality filters only to avoid needing composite index
      // Then sort client-side
      final querySnapshot =
          await _db
              .collection('signedSms')
              .where('senderPhoneNumber', isEqualTo: normalizedPhone)
              .where('messageHash', isEqualTo: messageHash)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return SmsVerificationResult.notFound();
      }

      // Sort by timestamp descending and get the most recent
      final docs = querySnapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = (a.data()['timestamp'] as Timestamp).toDate();
        final bTime = (b.data()['timestamp'] as Timestamp).toDate();
        return bTime.compareTo(aTime); // Descending
      });

      final signedSms = SignedSms.fromMap(docs.first.data());

      // Check if expired
      if (signedSms.expiresAt != null &&
          DateTime.now().isAfter(signedSms.expiresAt!)) {
        return SmsVerificationResult.expired();
      }

      // Verify the certificate
      final certValid = await _certService.verifyUserCert(signedSms.certId);
      if (!certValid) {
        return SmsVerificationResult.invalid(
          'Certificate is invalid or expired',
        );
      }

      // Verify the certificate's phone number matches sender
      final certDoc =
          await _db.collection('certificates').doc(signedSms.certId).get();
      if (!certDoc.exists) {
        return SmsVerificationResult.invalid('Certificate not found');
      }

      // Get user info to check phone number
      final userDoc =
          await _db.collection('users').doc(signedSms.senderId).get();
      if (!userDoc.exists) {
        return SmsVerificationResult.invalid('User not found');
      }

      final userData = userDoc.data()!;
      final userPhone = _normalizePhoneNumber(userData['phone'] ?? '');

      // Check if certificate's user phone matches SMS sender
      if (userPhone != normalizedPhone) {
        return SmsVerificationResult.phoneMismatch();
      }

      // Verify the signature
      final signatureValid = await _certService.verifyUserSignature(
        certId: signedSms.certId,
        messageText: messageContent,
        signatureBase64: signedSms.signature,
      );

      if (!signatureValid) {
        return SmsVerificationResult.invalid('Signature verification failed');
      }

      // All checks passed!
      return SmsVerificationResult.valid(
        senderName: userData['name'] ?? 'Unknown',
        certId: signedSms.certId,
        signedAt: signedSms.timestamp,
      );
    } catch (e) {
      print('Error verifying SMS: $e');
      return SmsVerificationResult.invalid('Verification error: $e');
    }
  }

  /// Normalize phone number to a standard format (remove spaces, dashes, country code variations)
  static String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters except leading +
    String normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Handle Vietnam phone numbers as example
    // +84xxxxxxxxx -> 0xxxxxxxxx (local format)
    // Or keep international format, depending on your needs

    // For now, just keep last 10 digits if number is longer
    if (normalized.length > 10) {
      // Remove country code, keep local number
      if (normalized.startsWith('+84')) {
        normalized = '0${normalized.substring(3)}';
      } else if (normalized.startsWith('84')) {
        normalized = '0${normalized.substring(2)}';
      }
    }

    return normalized;
  }

  /// Get all signed SMS records for a user (for viewing history)
  Future<List<SignedSms>> getSignedSmsHistory(String userId) async {
    // Query without orderBy to avoid needing composite index
    // Sort client-side instead
    final snapshot =
        await _db
            .collection('signedSms')
            .where('senderId', isEqualTo: userId)
            .get();

    final records =
        snapshot.docs.map((doc) => SignedSms.fromMap(doc.data())).toList();

    // Sort by timestamp descending (newest first)
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Return max 100 records
    return records.take(100).toList();
  }

  /// Delete expired signed SMS records (maintenance function)
  Future<int> cleanupExpiredRecords() async {
    final now = Timestamp.fromDate(DateTime.now());
    final expiredDocs =
        await _db
            .collection('signedSms')
            .where('expiresAt', isLessThan: now)
            .get();

    final batch = _db.batch();
    for (final doc in expiredDocs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    return expiredDocs.docs.length;
  }

  /// Listen for outgoing SMS and automatically sign them
  /// This monitors the sent messages folder for new entries
  Future<void> monitorOutgoingSms({
    required String userId,
    required String userPhoneNumber,
  }) async {
    try {
      // Get the current latest sent message timestamp
      final sentMessages = await readSentMessages(limit: 1);
      DateTime? lastChecked =
          sentMessages.isNotEmpty
              ? sentMessages.first.timestamp
              : DateTime.now();

      // Poll for new sent messages periodically
      Timer.periodic(const Duration(seconds: 5), (timer) async {
        try {
          final newSentMessages = await readSentMessages(limit: 10);

          for (final sms in newSentMessages) {
            if (sms.timestamp.isAfter(lastChecked!)) {
              // New outgoing SMS detected, sign it
              await signAndStoreSms(
                senderId: userId,
                senderPhoneNumber: userPhoneNumber,
                receiverPhoneNumber: sms.address,
                messageContent: sms.body,
              );
              lastChecked = sms.timestamp;
            }
          }
        } catch (e) {
          print('Error monitoring outgoing SMS: $e');
        }
      });
    } catch (e) {
      print('Error starting SMS monitor: $e');
    }
  }
}
