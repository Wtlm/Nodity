import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import './root_cert_service.dart';
import '../model/cert.dart';

class CertService {
  final _db = FirebaseFirestore.instance;
  final _secureStorage = const FlutterSecureStorage();

  /// Generate a new certificate for a user
  Future<String> generateCert(String userId, String userPassword) async {
    final certDocRef = _db.collection('certificates').doc();
    final certId = certDocRef.id;
    final issuedTime = DateTime.now();
    final expiresTime = issuedTime.add(const Duration(days: 365));
    final nonce = crypto.AesGcm.with256bits().newNonce();

    // Generate RSA key pair
    final keyGen =
        RSAKeyGenerator()..init(
          ParametersWithRandom(
            RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
            RootCertService.secureRandom(),
          ),
        );

    final pair = keyGen.generateKeyPair();
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;

    // Save private key locally
    await _secureStorage.write(
      key: 'private_key_$userId',
      value: base64Encode(RootCertService.encodePrivateKey(privateKey)),
    );

    // Derive encryption key from user's password
    final aesKey = await _deriveKeyFromPassword(userPassword, nonce);

    // Encrypt private key for backup
    final plainPrivateKey = RootCertService.encodePrivateKey(privateKey);
    final encryptedPrivateKey = await aesGcmEncrypt(
      plainPrivateKey,
      aesKey,
      nonce,
    );

    // Store encrypted backup
    await _db.collection('usersPrivateKey').doc(userId).set({
      'encryptedKey': base64Encode(encryptedPrivateKey['cipherText']),
      'nonce': base64Encode(encryptedPrivateKey['nonce']),
      'mac': base64Encode(encryptedPrivateKey['mac']),
    });

    // Construct certificate content
    final certContent = {
      'version': 1,
      'serialNumber': certId,
      'signatureAlgorithm': 'SHA256withRSA',
      'issuer': 'Nodity CA',
      'subject': userId,
      'publicKey': base64Encode(RootCertService.encodePublicKey(publicKey)),
      'issuedAt': issuedTime.toIso8601String(),
      'expiresAt': expiresTime.toIso8601String(),
    };

    // Sign certificate with root's private key
    final rootSignCert = await RootCertService.signUserCert(certContent);

    // Store in Firestore
    final cert = Cert(
      certId: certId,
      ownerId: userId,
      certData: {'certificate': certContent, 'rootSignature': rootSignCert},
      issuedAt: issuedTime,
      expiresAt: expiresTime,
    );

    await certDocRef.set(cert.toJson());
    print('✓ Certificate generated: $certId');
    return certId;
  }

  /// Sign a message with user's private key
  static Future<String> signMessage(String senderId, String messageText) async {
    // Load private key from secure storage
    final base64PrivateKey = await const FlutterSecureStorage().read(
      key: 'private_key_$senderId',
    );

    if (base64PrivateKey == null) {
      throw Exception('Private key not found for user: $senderId');
    }

    final privateKey = RootCertService.parsePrivateKeyFromASN1(
      base64Decode(base64PrivateKey),
    );

    // Sign using RSA-SHA256 with PKCS#1 v1.5 padding
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final messageBytes = Uint8List.fromList(utf8.encode(messageText));
    final signature = signer.generateSignature(messageBytes);

    return base64Encode(signature.bytes);
  }

  /// Verify a user's certificate
  Future<bool> verifyUserCert(String certId) async {
    try {
      // Fetch certificate
      final certDoc = await _db.collection('certificates').doc(certId).get();

      if (!certDoc.exists) {
        print('✗ Certificate not found: $certId');
        return false;
      }

      final certData = certDoc.data()!;
      final certContentRaw = certData['certData']['certificate'];
      final rootSignatureBase64 = certData['certData']['rootSignature'];

      // Check time validity
      final issuedAt = certContentRaw['issuedAt'] as String?;
      final expiresAt = certContentRaw['expiresAt'] as String?;

      if (issuedAt != null && expiresAt != null) {
        if (!isCertValidByTime(issuedAt: issuedAt, expiresAt: expiresAt)) {
          print('✗ Certificate expired or not yet valid');
          return false;
        }
      }

      // Reconstruct cert content in canonical order
      final certContent = LinkedHashMap<String, dynamic>();
      certContent['version'] = certContentRaw['version'];
      certContent['serialNumber'] = certContentRaw['serialNumber'];
      certContent['signatureAlgorithm'] = certContentRaw['signatureAlgorithm'];
      certContent['issuer'] = certContentRaw['issuer'];
      certContent['subject'] = certContentRaw['subject'];
      certContent['publicKey'] = certContentRaw['publicKey'];
      certContent['issuedAt'] = certContentRaw['issuedAt'];
      certContent['expiresAt'] = certContentRaw['expiresAt'];

      // Convert to canonical JSON
      final canonicalJson = RootCertService.canonicalJsonEncode(certContent);
      final contentBytes = utf8.encode(canonicalJson);
      final signatureBytes = base64Decode(rootSignatureBase64);

      print('\n=== CERTIFICATE VERIFICATION ===');
      print('Certificate ID: $certId');
      print('Canonical JSON: $canonicalJson');

      // Compute hash
      final digest = SHA256Digest();
      final hash = digest.process(Uint8List.fromList(contentBytes));
      final hashHex =
          hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      print('SHA-256 hash: $hashHex');

      // Fetch root certificate
      final rootDoc = await _db.collection('rootCert').doc('rootCA').get();

      if (!rootDoc.exists) {
        print('✗ Root certificate not found');
        return false;
      }

      final rootData = rootDoc.data();
      if (rootData == null || rootData['rootCertData'] == null) {
        print('✗ Invalid root certificate data');
        return false;
      }

      final rootCertData = rootData['rootCertData'];
      final rootPubKey = RootCertService.parsePublicKeyFromASN1(
        base64Decode(rootCertData['publicKey']),
      );

      // Verify signature using RSA-SHA256
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(rootPubKey));

      final isValid = verifier.verifySignature(
        Uint8List.fromList(contentBytes),
        RSASignature(signatureBytes),
      );

      print('Verification result: ${isValid ? "✓ VALID" : "✗ INVALID"}');
      print('=== END VERIFICATION ===\n');

      return isValid;
    } catch (e) {
      print('✗ Verification error: $e');
      return false;
    }
  }

  /// Verify a user's signature on a message
  Future<bool> verifyUserSignature({
    required String certId,
    required String messageText,
    required String signatureBase64,
  }) async {
    try {
      // Fetch certificate to get public key
      final certDoc = await _db.collection('certificates').doc(certId).get();

      if (!certDoc.exists) {
        print('✗ Certificate not found: $certId');
        return false;
      }

      final certContent = certDoc.data()!['certData']['certificate'];
      final pubKey = RootCertService.parsePublicKeyFromASN1(
        base64Decode(certContent['publicKey']),
      );

      // Verify signature
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(pubKey));

      final messageBytes = Uint8List.fromList(utf8.encode(messageText));
      final signatureBytes = base64Decode(signatureBase64);

      final isValid = verifier.verifySignature(
        messageBytes,
        RSASignature(signatureBytes),
      );

      print('Message signature: ${isValid ? "✓ VALID" : "✗ INVALID"}');
      return isValid;
    } catch (e) {
      print('✗ Signature verification error: $e');
      return false;
    }
  }

  /// Check if certificate is valid by time
  bool isCertValidByTime({
    required String issuedAt,
    required String expiresAt,
  }) {
    try {
      final issued = DateTime.parse(issuedAt);
      final expiry = DateTime.parse(expiresAt);
      final now = DateTime.now();

      return now.isAfter(issued) && now.isBefore(expiry);
    } catch (e) {
      print('✗ Date parsing error: $e');
      return false;
    }
  }

  /// Fetch and store private key from Firestore backup
  Future<void> fetchAndStorePrivateKey(String userId, String password) async {
    final userPrivateKey =
        await _db.collection('usersPrivateKey').doc(userId).get();

    if (!userPrivateKey.exists) {
      throw Exception('Private key backup not found');
    }

    final keyData = userPrivateKey.data()!;
    final encryptedKey = base64Decode(keyData['encryptedKey']);
    final nonce = base64Decode(keyData['nonce']);
    final mac = base64Decode(keyData['mac']);

    final aesKey = await _deriveKeyFromPassword(password, nonce);
    final decryptedKey = await aesGcmDecrypt(encryptedKey, aesKey, nonce, mac);

    await _secureStorage.write(
      key: 'private_key_$userId',
      value: base64Encode(decryptedKey),
    );

    print('✓ Private key restored from backup');
  }

  // === HELPER METHODS ===

  static Future<crypto.SecretKey> _deriveKeyFromPassword(
    String password,
    List<int> salt,
  ) async {
    final pbkdf2 = crypto.Pbkdf2(
      macAlgorithm: crypto.Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: crypto.SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static Future<Map<String, dynamic>> aesGcmEncrypt(
    List<int> plainBytes,
    crypto.SecretKey key,
    List<int> nonce,
  ) async {
    final algorithm = crypto.AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      plainBytes,
      secretKey: key,
      nonce: nonce,
    );

    return {
      'cipherText': secretBox.cipherText,
      'nonce': secretBox.nonce,
      'mac': secretBox.mac.bytes,
    };
  }

  static Future<List<int>> aesGcmDecrypt(
    List<int> cipherBytes,
    crypto.SecretKey key,
    List<int> nonce,
    List<int> mac,
  ) async {
    final algorithm = crypto.AesGcm.with256bits();
    final secretBox = crypto.SecretBox(
      cipherBytes,
      nonce: nonce,
      mac: crypto.Mac(mac),
    );

    return algorithm.decrypt(secretBox, secretKey: key);
  }
}
