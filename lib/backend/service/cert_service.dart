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

    // Sign using RSA with SHA-256 and PKCS#1 v1.5 padding
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final messageBytes = Uint8List.fromList(utf8.encode(messageText));
    final signature = signer.generateSignature(messageBytes);

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

    // Fetch root certificate by specific document ID
    final rootDoc = await _db.collection('rootCert').doc('rootCA').get();

    if (!rootDoc.exists) {
      print('Error: Root certificate document "rootCA" not found');
      return false;
    }

    final rootData = rootDoc.data();
    if (rootData == null || rootData['rootCertData'] == null) {
      print('Error: Root certificate data is invalid');
      return false;
    }

    final rootCertData = rootData['rootCertData'];
    if (rootCertData['publicKey'] == null) {
      print('Error: Root certificate public key is missing');
      return false;
    }

    final rootPubKey = RootCertService.parsePublicKeyFromASN1(
      base64Decode(rootCertData['publicKey']),
    );

    print('Client root modulus bitLength: ${rootPubKey.modulus!.bitLength}');
    print(
      "Client root modulus hex: "
      "${rootPubKey.modulus!.toRadixString(16).substring(0, 100)}",
    );

    // Use RSASigner with SHA-256 and PKCS#1 v1.5 padding
    // This matches what node-forge privateKey.sign(md) produces
    bool rsaSignerWorks = false;
    try {
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(rootPubKey));

      final isValid = verifier.verifySignature(
        Uint8List.fromList(contentBytes),
        RSASignature(signatureBytes),
      );

      if (isValid) {
        print('Certificate verification result: true');
        print('=== END CLIENT VERIFICATION ===');
        return true;
      }

      // If verification failed, try manual method
      print('RSASigner returned false, trying manual verification...');
      rsaSignerWorks = false;
    } catch (e) {
      print('RSASigner error: $e');
      print('Trying alternative verification method...');
      rsaSignerWorks = false;
    }

    // Try manual verification as fallback
    if (!rsaSignerWorks) {
      try {
        // Manually verify using modular exponentiation: sig^e mod n
        // Convert signature bytes to BigInt (big-endian)
        final signatureBigInt = BigInt.parse(
          signatureBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
          radix: 16,
        );

        // Perform RSA verification: m = s^e mod n
        final decryptedBigInt = signatureBigInt.modPow(
          rootPubKey.exponent!,
          rootPubKey.modulus!,
        );

        // Convert back to bytes (big-endian, padded to 256 bytes)
        final decryptedHex = decryptedBigInt
            .toRadixString(16)
            .padLeft(512, '0');
        final decrypted = Uint8List.fromList(
          List.generate(
            256,
            (i) =>
                int.parse(decryptedHex.substring(i * 2, i * 2 + 2), radix: 16),
          ),
        );

        // Compute expected hash
        final digest = SHA256Digest();
        final expectedHash = digest.process(Uint8List.fromList(contentBytes));

        // Debug: Print the entire decrypted signature
        print('Decrypted signature length: ${decrypted.length}');
        print(
          'Full decrypted (hex): ${decrypted.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
        print(
          'Expected hash (hex): ${expectedHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );

        // Check if the expected hash appears anywhere in the decrypted data
        bool hashFound = false;
        for (int i = 0; i <= decrypted.length - 32; i++) {
          bool match = true;
          for (int j = 0; j < 32; j++) {
            if (decrypted[i + j] != expectedHash[j]) {
              match = false;
              break;
            }
          }
          if (match) {
            print('Found hash at position $i in decrypted signature!');
            hashFound = true;
            break;
          }
        }

        if (!hashFound) {
          print('Hash NOT found anywhere in decrypted signature');
        }

        // PKCS#1 v1.5 format: 0x00 0x01 [padding 0xFF] 0x00 [DigestInfo] [hash]
        // DigestInfo for SHA-256: 30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20
        final digestInfo = [
          0x30,
          0x31,
          0x30,
          0x0d,
          0x06,
          0x09,
          0x60,
          0x86,
          0x48,
          0x01,
          0x65,
          0x03,
          0x04,
          0x02,
          0x01,
          0x05,
          0x00,
          0x04,
          0x20,
        ];

        // Find the start of DigestInfo in decrypted signature
        int digestInfoStart = -1;
        for (int i = 0; i < decrypted.length - digestInfo.length; i++) {
          bool match = true;
          for (int j = 0; j < digestInfo.length; j++) {
            if (decrypted[i + j] != digestInfo[j]) {
              match = false;
              break;
            }
          }
          if (match) {
            digestInfoStart = i;
            break;
          }
        }

        if (digestInfoStart == -1) {
          print('DigestInfo not found in signature');
          return false;
        }

        // Extract hash from signature (comes after DigestInfo)
        final hashStart = digestInfoStart + digestInfo.length;
        if (hashStart + 32 > decrypted.length) {
          print('Hash not found in signature');
          return false;
        }

        final signatureHash = decrypted.sublist(hashStart, hashStart + 32);

        // Compare hashes
        bool hashesMatch = true;
        for (int i = 0; i < 32; i++) {
          if (signatureHash[i] != expectedHash[i]) {
            hashesMatch = false;
            break;
          }
        }

        print('Manual verification result: $hashesMatch');
        print('=== END CLIENT VERIFICATION ===');
        return hashesMatch;
      } catch (e2) {
        print('Manual verification also failed: $e2');
        print('=== END CLIENT VERIFICATION ===');
        return false;
      }
    }

    // Should not reach here
    print('No verification method worked');
    print('=== END CLIENT VERIFICATION ===');
    return false;
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

    // Use RSASigner with SHA-256 and PKCS#1 v1.5 padding
    final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
    verifier.init(false, PublicKeyParameter<RSAPublicKey>(pubKey));

    try {
      // Verify the signature
      final messageBytes = Uint8List.fromList(utf8.encode(messageText));
      final signatureBytes = base64Decode(signatureBase64);

      final isValid = verifier.verifySignature(
        messageBytes,
        RSASignature(signatureBytes),
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
