import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:http/http.dart' as http;

class RootCertService {
  static const String backendUrl = 'https://nodity.onrender.com';

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
            secureRandom(),
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
      'privateKey': base64Encode(encodePrivateKey(privateKey)),
    });
    print('Root certificate generated and uploaded.');
  }

  /// Generates secure random seed for key generation
  static SecureRandom secureRandom() {
    final secureRandom = FortunaRandom();

    // Generate a random 32-byte seed using Dart's Random.secure()
    final seed = Uint8List(32);
    final random = Random.secure();
    for (int i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }

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
    final response = await http.post(
      Uri.parse('$backendUrl/sign-cert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'certContent': certContent}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['rootSignature'];
    } else {
      throw Exception('Failed to sign certificate: ${response.body}');
    }
  }
}
