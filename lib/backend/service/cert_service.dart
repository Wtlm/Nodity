import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Nodity/backend/service/root_cert_service.dart';

import '../model/cert.dart';

class CertService {
  final _db = FirebaseFirestore.instance;

  Future<String> generateCert(String userId) async {
    final certDocRef = _db.collection('certificates').doc();
    final certId = certDocRef.id;
    final issuedTime = DateTime.now();
    final expiresTime = issuedTime.add(const Duration(days: 365));

    //Generate RSA key pair
    final keyParams = RSAKeyGeneratorParameters(
      BigInt.parse('65537'),
      2048,
      64,
    );
    final secureRandom =
        FortunaRandom()..seed(
          KeyParameter(Uint8List.fromList(List.generate(32, (_) => 42))),
        );
    final keyGen =
        RSAKeyGenerator()..init(ParametersWithRandom(keyParams, secureRandom));

    final pair = keyGen.generateKeyPair();
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;

    // Save private key locally
    await FlutterSecureStorage().write(
      key: 'private_key_$userId',
      value: base64Encode(RootCertService.encodePrivateKey(privateKey)),
    );
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
}
