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

  Future<String> generateCert(String userId, String userPassword) async {
    final certDocRef = _db.collection('certificates').doc();
    final certId = certDocRef.id;
    final issuedTime = DateTime.now();
    final expiresTime = issuedTime.add(const Duration(days: 365));
    final nonce = crypto.AesGcm.with256bits().newNonce();

    // Generate RSA key pair
    final keyGen = RSAKeyGenerator()
      ..init(
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

    // Encrypt and backup private key
    final aesKey = await _deriveKeyFromPassword(userPassword, nonce);
    final encryptedPrivateKey = await aesGcmEncrypt(
      RootCertService.encodePrivateKey(privateKey),
      aesKey,
      nonce,
    );

    await _db.collection('usersPrivateKey').doc(userId).set({
      'encryptedKey': base64Encode(encryptedPrivateKey['cipherText']),
      'nonce': base64Encode(encryptedPrivateKey['nonce']),
      'mac': base64Encode(encryptedPrivateKey['mac']),
    });

    // Create certificate content (sorted keys)
    final certContent = SplayTreeMap<String, dynamic>();
    certContent['expiresAt'] = expiresTime.toIso8601String();
    certContent['issuedAt'] = issuedTime.toIso8601String();
    certContent['issuer'] = 'Nodity CA';
    certContent['publicKey'] =
        base64Encode(RootCertService.encodePublicKey(publicKey));
    certContent['serialNumber'] = certId;
    certContent['signatureAlgorithm'] = 'SHA256withRSA';
    certContent['subject'] = userId;
    certContent['version'] = 1;

    // Get root signature
    final rootSignCert = await RootCertService.signUserCert(certContent);

    // Store certificate
    final cert = Cert(
      certId: certId,
      ownerId: userId,
      certData: {'certificate': certContent, 'rootSignature': rootSignCert},
      issuedAt: issuedTime,
      expiresAt: expiresTime,
    );

    await certDocRef.set(cert.toJson());
    return certId;
  }

  static Future<String> signMessage(String senderId, String messageText) async {
    final base64PrivateKey = await const FlutterSecureStorage().read(
      key: 'private_key_$senderId',
    );

    if (base64PrivateKey == null) {
      throw Exception('Private key not found');
    }

    final privateKey = RootCertService.parsePrivateKeyFromASN1(
      base64Decode(base64PrivateKey),
    );

    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final messageBytes = Uint8List.fromList(utf8.encode(messageText));
    final signature = signer.generateSignature(messageBytes);

    return base64Encode(signature.bytes);
  }

  Future<bool> verifyUserCert(String certId) async {
    try {
      // Get certificate
      final certDoc = await _db.collection('certificates').doc(certId).get();
      if (!certDoc.exists) return false;

      final certData = certDoc.data()!;
      final certContentRaw = certData['certData']['certificate'];
      final rootSignatureBase64 = certData['certData']['rootSignature'];

      // Check expiry
      final expiresAt = DateTime.parse(certContentRaw['expiresAt']);
      if (DateTime.now().isAfter(expiresAt)) return false;

      // Create canonical JSON (sorted keys)
      final certContent = SplayTreeMap<String, dynamic>.from(certContentRaw);
      final canonicalJson = jsonEncode(certContent);

      // Get root public key
      final rootDoc = await _db.collection('rootCert').doc('rootCA').get();
      if (!rootDoc.exists) return false;

      final rootCertData = rootDoc.data()!['rootCertData'];
      final rootPubKey = RootCertService.parsePublicKeyFromASN1(
        base64Decode(rootCertData['publicKey']),
      );

      // Verify signature
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(rootPubKey));

      final contentBytes = Uint8List.fromList(utf8.encode(canonicalJson));
      final signatureBytes = base64Decode(rootSignatureBase64);

      final isValid = verifier.verifySignature(
        contentBytes,
        RSASignature(signatureBytes),
      );

      print(isValid ? '✓ Certificate valid' : '✗ Certificate invalid');
      return isValid;
    } catch (e) {
      print('✗ Verification error: $e');
      return false;
    }
  }

  Future<bool> verifyUserSignature({
    required String certId,
    required String messageText,
    required String signatureBase64,
  }) async {
    try {
      final certDoc = await _db.collection('certificates').doc(certId).get();
      if (!certDoc.exists) return false;

      final certContent = certDoc.data()!['certData']['certificate'];
      final pubKey = RootCertService.parsePublicKeyFromASN1(
        base64Decode(certContent['publicKey']),
      );

      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(pubKey));

      final messageBytes = Uint8List.fromList(utf8.encode(messageText));
      final signatureBytes = base64Decode(signatureBase64);

      return verifier.verifySignature(
        messageBytes,
        RSASignature(signatureBytes),
      );
    } catch (e) {
      return false;
    }
  }

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
      return false;
    }
  }

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
  }

  // Crypto helpers
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
