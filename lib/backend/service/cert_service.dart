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
  final _secureStorage = FlutterSecureStorage();

  Future<String> generateCert(String userId, String userPassword) async {
    final certDocRef = _db.collection('certificates').doc();
    final certId = certDocRef.id;
    final issuedTime = DateTime.now();
    final expiresTime = issuedTime.add(const Duration(days: 365));
    final nonce = crypto.AesGcm.with256bits().newNonce();

    //Generate RSA key pair
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

    // Derive encryption key from user's password (salt = nonce)
    final aesKey = await _deriveKeyFromPassword(userPassword, nonce);

    // Encrypt private key
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

    //Construct base certificate data (without signature)
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

    //Sign certData with root's private key (RSA-SHA256)
    final rootSignCert = await RootCertService.signUserCert(certContent);

    //Store in Firestore
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
    // Load from secure storage
    final base64PrivateKey = await FlutterSecureStorage().read(
      key: 'private_key_$senderId',
    );
    if (base64PrivateKey == null) throw Exception('Private key not found');

    final privateKey = RootCertService.parsePrivateKeyFromASN1(
      base64Decode(base64PrivateKey),
    );

    // Use to sign
    final signer = Signer('SHA-256/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature =
        signer.generateSignature(Uint8List.fromList(utf8.encode(messageText)))
            as RSASignature;
    return base64Encode(signature.bytes);
  }

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

    // Encrypt
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

    // Decrypt
    final secretBox = crypto.SecretBox(
      cipherBytes,
      nonce: nonce,
      mac: crypto.Mac(mac),
    );

    return algorithm.decrypt(secretBox, secretKey: key);
  }

  Future<void> fetchAndStorePrivateKey(String userId, String password) async {
    final userPrivateKey =
        await FirebaseFirestore.instance
            .collection('usersPrivateKey')
            .doc(userId)
            .get();

    if (!userPrivateKey.exists) {
      throw Exception("Private key not found.");
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

  Future<bool> verifyUserCert(String certId) async {
    final certDoc = await _db.collection('certificates').doc(certId).get();
    try {
      if (!certDoc.exists) {
        print('Certificate not found: $certId');
        return false;
      }
    } catch (e) {
      print('Error fetching certificate: $e');
      return false;
    }
    // if (!certDoc.exists) return false;

    final certData = certDoc.data()!;

    final certContentRaw = certData['certData']['certificate'];
    final certContent = LinkedHashMap<String, dynamic>();
    certContent['version'] = certContentRaw['version'];
    certContent['serialNumber'] = certContentRaw['serialNumber'];
    certContent['signatureAlgorithm'] = certContentRaw['signatureAlgorithm'];
    certContent['issuer'] = certContentRaw['issuer'];
    certContent['subject'] = certContentRaw['subject'];
    certContent['publicKey'] = certContentRaw['publicKey'];
    certContent['issuedAt'] = certContentRaw['issuedAt'];
    certContent['expiresAt'] = certContentRaw['expiresAt'];

    final rootSignatureBase64 = certData['certData']['rootSignature'];
    final issuedAt = certContent['issuedAt'];
    final expiresAt = certContent['expiresAt'];

    if (issuedAt != null && expiresAt != null) {
      final isValid = isCertValidByTime(
        issuedAt: issuedAt,
        expiresAt: expiresAt,
      );

      if (!isValid) {
        return false;
      }
    }
    final canonicalJson = RootCertService.canonicalJsonEncode(certContent);
    final contentBytes = utf8.encode(canonicalJson);
    final signatureBytes = base64Decode(rootSignatureBase64);

    print('=== CLIENT VERIFICATION ===');
    print('Canonical JSON: $canonicalJson');
    print('Content bytes length: ${contentBytes.length}');
    print('Signature bytes length: ${signatureBytes.length}');

    // Compute hash for comparison with server logs
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(contentBytes));
    print(
      'SHA-256 hash (hex): ${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
    );

    final rootSnap = await _db.collection('rootCert').limit(1).get();

    try {
      if (rootSnap.docs.isEmpty) {
        throw Exception('Root certificate not found');
      }
    } catch (e) {
      print('Error fetching root cert: $e');
      return false;
    }

    final rootCertData = rootSnap.docs.first.data()['rootCertData'];
    final rootPubKey = RootCertService.parsePublicKeyFromASN1(
      base64Decode(rootCertData['publicKey']),
    );

    print('Client root modulus bitLength: ${rootPubKey.modulus!.bitLength}');
    print(
      "Client root modulus hex: "
      "${rootPubKey.modulus!.toRadixString(16).substring(0, 100)}",
    );

    // Use Signer('SHA-256/RSA') which handles PKCS#1 v1.5 verification
    // This matches what node-forge privateKey.sign(md) produces
    final verifier = Signer('SHA-256/RSA');
    verifier.init(false, PublicKeyParameter<RSAPublicKey>(rootPubKey));

    try {
      // Verify the signature - Signer will hash the content and verify PKCS#1 padding
      final isValid = verifier.verifySignature(
        Uint8List.fromList(contentBytes),
        RSASignature(signatureBytes),
      );
      print('Certificate verification result: $isValid');
      print('=== END CLIENT VERIFICATION ===');
      return isValid;
    } catch (e) {
      print('Cert verification failed: $e');
      return false;
    }
  }

  Future<bool> verifyUserSignature({
    required String certId,
    required String messageText,
    required String signatureBase64,
  }) async {
    final certDoc = await _db.collection('certificates').doc(certId).get();
    if (!certDoc.exists) return false;

    final certContent = certDoc.data()!['certData']['certificate'];
    final pubKey = RootCertService.parsePublicKeyFromASN1(
      base64Decode(certContent['publicKey']),
    );

    final verifier = Signer('SHA-256/RSA')
      ..init(false, PublicKeyParameter<RSAPublicKey>(pubKey));

    try {
      // Verify the signature
      final isValid = verifier.verifySignature(
        Uint8List.fromList(utf8.encode(messageText)),
        RSASignature(base64Decode(signatureBase64)),
      );
      print('Signature verification result: $isValid');
      return isValid;
    } catch (e) {
      print('Signature verification failed: $e');
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

      final isValid = now.isAfter(issued) && now.isBefore(expiry);

      print('Issued at: $issued');
      print('Expires at: $expiry');
      print('Now: $now');
      print('Certificate valid: $isValid');

      return isValid;
    } catch (e) {
      print('Error parsing date: $e');
      return false;
    }
  }
}
