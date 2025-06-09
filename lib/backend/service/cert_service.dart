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

    await _secureStorage.write(key: 'private_key_$userId', value: base64Encode(decryptedKey));
  }
}
