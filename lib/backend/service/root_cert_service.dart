import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:asn1lib/asn1lib.dart';

class RootCertService {
  static final _secureStorage = FlutterSecureStorage();

  /// Main function to generate and store Root Cert + keys
  static Future<void> generateRootCert() async {
    final rootCertDoc = FirebaseFirestore.instance.collection('rootCert').doc();
    final rootCertId = rootCertDoc.id;
    final issuedTime = DateTime.now();
    final expiresTime = issuedTime.add(const Duration(days: 3650));

    // Generate RSA Key Pair
    final keyGen =
        RSAKeyGenerator()..init(
          ParametersWithRandom(
            RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
            _secureRandom(),
          ),
        );
    final pair = keyGen.generateKeyPair();
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;

    // Create and encode certificate
    final certContent = {
      'version': 3,
      'serialNumber': rootCertId,
      'signatureAlgorithm': 'SHA256withRSA',
      'issuer': 'Nodity CA',
      'subject': 'Nodity CA',
      'publicKey': base64.encode(encodePublicKey(publicKey)),
      'issuedAt': issuedTime.toIso8601String(),
      'expiresAt': expiresTime.toIso8601String(), // 10 years
    };

    // 5. Upload cert to Firebase
    await rootCertDoc.set({
      'rootCertId': rootCertId,
      'rootCertData': certContent,
      'issuedAt': issuedTime.toIso8601String(),
      'expiresAt': expiresTime.toIso8601String(),
      'privateKey':  base64Encode(encodePrivateKey(privateKey)),
    });
    print('Root certificate generated and uploaded.');
  }

  /// Generates secure random seed for key generation
  static SecureRandom _secureRandom() {
    final secureRandom = FortunaRandom();
    final seed = Uint8List.fromList(List.generate(32, (_) => 0));
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  /// Converts RSAPrivateKey
  static Uint8List encodePrivateKey(RSAPrivateKey privateKey) {
    final sequence = ASN1Sequence();
    sequence.add(ASN1Integer(BigInt.zero)); // version
    sequence.add(ASN1Integer(privateKey.n!));
    sequence.add(ASN1Integer(privateKey.exponent!)); // public exponent
    sequence.add(ASN1Integer(privateKey.privateExponent!));
    sequence.add(ASN1Integer(privateKey.p!));
    sequence.add(ASN1Integer(privateKey.q!));
    sequence.add(
      ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one)),
    ); // d mod (p-1)
    sequence.add(
      ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one)),
    ); // d mod (q-1)
    sequence.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!))); // qInv

    return sequence.encodedBytes;
  }

  /// Converts RSAPublicKey
  static Uint8List encodePublicKey(RSAPublicKey publicKey) {
    final sequence = ASN1Sequence();
    sequence.add(ASN1Integer(publicKey.modulus!));
    sequence.add(ASN1Integer(publicKey.exponent!));
    return sequence.encodedBytes;
  }

  /// Read the root keys from secure storage
  static Future<String?> getPrivateKey() =>
      _secureStorage.read(key: 'root_private_key');

  static RSAPrivateKey parsePrivateKeyFromASN1(Uint8List bytes) {
    final asn1Parser = ASN1Parser(bytes);
    final sequence = asn1Parser.nextObject() as ASN1Sequence;

    final n = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;
    final e = (sequence.elements[2] as ASN1Integer).valueAsBigInteger;
    final d = (sequence.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (sequence.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (sequence.elements[5] as ASN1Integer).valueAsBigInteger;

    return RSAPrivateKey(n, d, p, q);
  }

  static Future<String> signUserCert(Map<String, dynamic> certContent) async {
    final privateKeyBase64 = await getPrivateKey();
    final privateKeyBytes = base64Decode(privateKeyBase64!);
    final privateKey = parsePrivateKeyFromASN1(privateKeyBytes);

    final signer = Signer('SHA-256/RSA');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final certJson = jsonEncode(certContent);
    final signature =
        signer.generateSignature(Uint8List.fromList(utf8.encode(certJson)))
            as RSASignature;

    return base64Encode(signature.bytes);
  }
}
