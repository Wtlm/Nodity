import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:http/http.dart' as http;

class RootCertService {
  static const String backendUrl = 'https://nodity.onrender.com';

  /// Main function to generate and store Root Cert + keys
  static Future<void> generateRootCert() async {
    final rootCertDoc = FirebaseFirestore.instance.collection('rootCert').doc('rootCA');
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

static parsePublicKeyFromASN1(Uint8List base64decode) {
  final asn1Parser = ASN1Parser(base64decode);
  final sequence = asn1Parser.nextObject() as ASN1Sequence;

  final n = (sequence.elements[0] as ASN1Integer).valueAsBigInteger;
  final e = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;

  return RSAPublicKey(n, e);
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

static String canonicalJsonEncode(Map<String, dynamic> map) {
  // recursive SplayTreeMap conversion (sorts keys)
  dynamic _normalize(dynamic v) {
    if (v is Map<String, dynamic>) {
      final s = SplayTreeMap<String, dynamic>.from(v, (a, b) => a.compareTo(b));
      final out = <String, dynamic>{};
      s.forEach((k, val) => out[k] = _normalize(val));
      return out;
    }
    if (v is List) {
      return v.map(_normalize).toList();
    }
    return v;
  }

  final normalized = _normalize(map);
  return jsonEncode(normalized);
}


  static Future<String> signUserCert(Map<String, dynamic> certContent) async {
    final canonical = jsonDecode(canonicalJsonEncode(certContent)); // normalized Map
    final resp = await http.post(
      Uri.parse('$backendUrl/sign-cert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'certContent': canonical}),
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return body['rootSignature'] as String;
    } else {
      throw Exception('Failed signing: ${resp.statusCode} ${resp.body}');
    }
  }

}
