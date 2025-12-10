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
    print(
      'Signature first 20 bytes (hex): ${signatureBytes.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
    );

    // Compute hash for comparison with server logs
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(contentBytes));
    print(
      'SHA-256 hash (hex): ${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
    );

    final rootSnap = await _db.collection('rootCert').doc('rootCA').get();

    try {
      if (!rootSnap.exists) {
        throw Exception('Root certificate not found');
      }
    } catch (e) {
      print('Error fetching root cert: $e');
      return false;
    }

    final rootCertData = rootSnap.data()!['rootCertData'];
    final rootPubKeyBase64 = rootCertData['publicKey'] as String;
    print(
      'Root public key from Firebase (first 100 chars): ${rootPubKeyBase64.substring(0, 100)}',
    );

    final rootPubKey = RootCertService.parsePublicKeyFromASN1(
      base64Decode(rootPubKeyBase64),
    );

    print('Client root modulus bitLength: ${rootPubKey.modulus!.bitLength}');
    print(
      "Client root modulus hex: "
      "${rootPubKey.modulus!.toRadixString(16).substring(0, 100)}",
    );
    print('Client root exponent: ${rootPubKey.exponent}');

    // Try manual RSA verification to debug
    try {
      // Step 1: RSA "decrypt" the signature with public key
      final sigInt = _bytesToBigInt(signatureBytes);
      final decrypted = sigInt.modPow(
        rootPubKey.exponent!,
        rootPubKey.modulus!,
      );
      final decryptedBytes = _bigIntToBytes(decrypted, 256);

      print(
        'Decrypted signature (first 50 hex): ${decryptedBytes.take(50).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      );

      // Step 2: Check PKCS#1 v1.5 padding (should start with 0x00 0x01 0xFF...0xFF 0x00)
      if (decryptedBytes[0] != 0x00 || decryptedBytes[1] != 0x01) {
        print(
          'Invalid PKCS#1 v1.5 padding: first bytes are ${decryptedBytes[0].toRadixString(16)} ${decryptedBytes[1].toRadixString(16)}',
        );
      }

      // Find the 0x00 separator
      int separatorIndex = -1;
      for (int i = 2; i < decryptedBytes.length; i++) {
        if (decryptedBytes[i] == 0x00) {
          separatorIndex = i;
          break;
        }
        if (decryptedBytes[i] != 0xFF) {
          print(
            'Invalid padding byte at index $i: ${decryptedBytes[i].toRadixString(16)}',
          );
          break;
        }
      }

      if (separatorIndex > 0) {
        final digestInfo = decryptedBytes.sublist(separatorIndex + 1);
        print(
          'DigestInfo (hex): ${digestInfo.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
        );
        print('DigestInfo length: ${digestInfo.length}');

        // The DigestInfo should contain the hash at the end (32 bytes for SHA-256)
        if (digestInfo.length >= 32) {
          final extractedHash = digestInfo.sublist(digestInfo.length - 32);
          print(
            'Extracted hash (hex): ${extractedHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
          );
          print(
            'Expected hash (hex): ${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
          );

          // Compare hashes
          bool hashMatch = true;
          for (int i = 0; i < 32; i++) {
            if (extractedHash[i] != hash[i]) {
              hashMatch = false;
              break;
            }
          }
          print('Hash comparison: ${hashMatch ? "MATCH" : "MISMATCH"}');
        }
      }

      // Also try the standard Signer
      final verifier = Signer('SHA-256/RSA');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(rootPubKey));
      final isValid = verifier.verifySignature(
        Uint8List.fromList(contentBytes),
        RSASignature(signatureBytes),
      );
      print('PointyCastle Signer result: $isValid');
      print('=== END CLIENT VERIFICATION ===');
      return isValid;
    } catch (e) {
      print('Cert verification failed: $e');
      print('=== END CLIENT VERIFICATION ===');
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

  // Helper function to convert bytes to BigInt
  static BigInt _bytesToBigInt(List<int> bytes) {
    BigInt result = BigInt.zero;
    for (int byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  // Helper function to convert BigInt to bytes with specified length
  static Uint8List _bigIntToBytes(BigInt number, int length) {
    final bytes = Uint8List(length);
    BigInt temp = number;
    for (int i = length - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xFF)).toInt();
      temp = temp >> 8;
    }
    return bytes;
  }
}
