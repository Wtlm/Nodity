import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:http/http.dart' as http;

class RootCertService {
  static const String backendUrl = 'https://nodity.onrender.com';

  static Future<void> generateRootCert() async {
    final rootCertDoc = FirebaseFirestore.instance
        .collection('rootCert')
        .doc('rootCA');

    const rootCertId = 'rootCA';
    final issuedTime = DateTime.now();
    final expiresTime = issuedTime.add(const Duration(days: 3650));

    // Generate key pair
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

    // Create certificate (sorted keys)
    final certContent = SplayTreeMap<String, dynamic>();
    certContent['expiresAt'] = expiresTime.toIso8601String();
    certContent['issuedAt'] = issuedTime.toIso8601String();
    certContent['issuer'] = 'Nodity CA';
    certContent['publicKey'] = base64Encode(encodePublicKey(publicKey));
    certContent['serialNumber'] = rootCertId;
    certContent['signatureAlgorithm'] = 'SHA256withRSA';
    certContent['subject'] = 'Nodity CA';
    certContent['version'] = 3;

    // Store in Firestore
    await rootCertDoc.set({
      'rootCertId': rootCertId,
      'rootCertData': certContent,
      'issuedAt': issuedTime.toIso8601String(),
      'expiresAt': expiresTime.toIso8601String(),
      'privateKey': base64Encode(encodePrivateKey(privateKey)),
    });

    print('✓ Root certificate generated');
  }

  static Future<String> signUserCert(Map<String, dynamic> certContent) async {
    // Ensure sorted keys
    final sorted = SplayTreeMap<String, dynamic>.from(certContent);
    final canonicalString = jsonEncode(sorted);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/sign-cert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'certContent': sorted}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['rootSignature'];
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Signing failed: $e');
    }
  }

  static SecureRandom secureRandom() {
    final secureRandom = FortunaRandom();
    final seed = Uint8List(32);
    final random = Random.secure();

    for (int i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }

    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  static Uint8List encodePrivateKey(RSAPrivateKey privateKey) {
    final sequence = ASN1Sequence();
    sequence.add(ASN1Integer(BigInt.zero));
    sequence.add(ASN1Integer(privateKey.n!));
    sequence.add(ASN1Integer(privateKey.exponent!));
    sequence.add(ASN1Integer(privateKey.privateExponent!));
    sequence.add(ASN1Integer(privateKey.p!));
    sequence.add(ASN1Integer(privateKey.q!));
    sequence.add(
      ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one)),
    );
    sequence.add(
      ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one)),
    );
    sequence.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));
    return sequence.encodedBytes;
  }

  static Uint8List encodePublicKey(RSAPublicKey publicKey) {
    final sequence = ASN1Sequence();
    sequence.add(ASN1Integer(publicKey.modulus!));
    sequence.add(ASN1Integer(publicKey.exponent!));
    return sequence.encodedBytes;
  }

  static RSAPublicKey parsePublicKeyFromASN1(Uint8List bytes) {
    final asn1Parser = ASN1Parser(bytes);
    final sequence = asn1Parser.nextObject() as ASN1Sequence;
    final n = (sequence.elements[0] as ASN1Integer).valueAsBigInteger;
    final e = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;
    return RSAPublicKey(n, e);
  }

  static RSAPrivateKey parsePrivateKeyFromASN1(Uint8List bytes) {
    final asn1Parser = ASN1Parser(bytes);
    final sequence = asn1Parser.nextObject() as ASN1Sequence;
    final n = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;
    final d = (sequence.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (sequence.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (sequence.elements[5] as ASN1Integer).valueAsBigInteger;
    return RSAPrivateKey(n, d, p, q);
  }
}
