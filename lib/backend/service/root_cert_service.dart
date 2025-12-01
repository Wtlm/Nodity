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

  /// Generate and store root certificate in Firestore
  static Future<void> generateRootCert() async {
    print('\n=== GENERATING ROOT CERTIFICATE ===');

    final rootCertDoc = FirebaseFirestore.instance
        .collection('rootCert')
        .doc('rootCA');

    const rootCertId = 'rootCA';
    final issuedTime = DateTime.now();
    final expiresTime = issuedTime.add(const Duration(days: 3650)); // 10 years

    // Generate RSA key pair
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

    print('✓ Key pair generated (2048-bit RSA)');

    // Create certificate content
    final certContent = {
      'version': 3,
      'serialNumber': rootCertId,
      'signatureAlgorithm': 'SHA256withRSA',
      'issuer': 'Nodity CA',
      'subject': 'Nodity CA',
      'publicKey': base64Encode(encodePublicKey(publicKey)),
      'issuedAt': issuedTime.toIso8601String(),
      'expiresAt': expiresTime.toIso8601String(),
    };

    // Store in Firestore
    await rootCertDoc.set({
      'rootCertId': rootCertId,
      'rootCertData': certContent,
      'issuedAt': issuedTime.toIso8601String(),
      'expiresAt': expiresTime.toIso8601String(),
      'privateKey': base64Encode(encodePrivateKey(privateKey)),
    });

    print('✓ Root certificate stored in Firestore (rootCert/rootCA)');
    final pubKeyStr = certContent['publicKey'] as String?;
    if (pubKeyStr != null && pubKeyStr.length > 40) {
      print('✓ Public key: ${pubKeyStr.substring(0, 40)}...');
    }
    print('=== ROOT CERTIFICATE GENERATION COMPLETE ===\n');
  }

  /// Sign a user certificate by calling the backend server
  static Future<String> signUserCert(Map<String, dynamic> certContent) async {
    final canonicalString = canonicalJsonEncode(certContent);

    // Compute local hash for verification
    final contentBytes = utf8.encode(canonicalString);
    final digest = SHA256Digest();
    final localHash = digest.process(Uint8List.fromList(contentBytes));
    final localHashHex =
        localHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    print('\n=== REQUESTING SIGNATURE ===');
    print('Canonical JSON: $canonicalString');
    print('Local SHA-256: $localHashHex');

    try {
      // Send to backend for signing
      final bodyObject = jsonDecode(canonicalString);

      final response = await http.post(
        Uri.parse('$backendUrl/sign-cert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'certContent': bodyObject}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        print('✓ Signature received from server');
        print('Server SHA-256: ${body['sha256Hex']}');

        // Verify hashes match
        if (body['sha256Hex'] != localHashHex) {
          print('⚠ WARNING: Hash mismatch between client and server!');
          print('  Client: $localHashHex');
          print('  Server: ${body['sha256Hex']}');
        } else {
          print('✓ Hashes match');
        }

        print('=== SIGNATURE REQUEST COMPLETE ===\n');
        return body['rootSignature'];
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('✗ Signing request failed: $e');
      rethrow;
    }
  }

  /// Generate secure random for key generation
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

  /// Encode RSA private key to ASN.1 DER format
  static Uint8List encodePrivateKey(RSAPrivateKey privateKey) {
    final sequence = ASN1Sequence();
    sequence.add(ASN1Integer(BigInt.zero)); // version
    sequence.add(ASN1Integer(privateKey.n!)); // modulus
    sequence.add(ASN1Integer(privateKey.exponent!)); // public exponent
    sequence.add(ASN1Integer(privateKey.privateExponent!)); // private exponent
    sequence.add(ASN1Integer(privateKey.p!)); // prime1
    sequence.add(ASN1Integer(privateKey.q!)); // prime2
    sequence.add(
      ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one)),
    ); // exponent1
    sequence.add(
      ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one)),
    ); // exponent2
    sequence.add(
      ASN1Integer(privateKey.q!.modInverse(privateKey.p!)),
    ); // coefficient

    return sequence.encodedBytes;
  }

  /// Encode RSA public key to ASN.1 DER format
  static Uint8List encodePublicKey(RSAPublicKey publicKey) {
    final sequence = ASN1Sequence();
    sequence.add(ASN1Integer(publicKey.modulus!));
    sequence.add(ASN1Integer(publicKey.exponent!));
    return sequence.encodedBytes;
  }

  /// Parse RSA public key from ASN.1 DER format
  static RSAPublicKey parsePublicKeyFromASN1(Uint8List bytes) {
    final asn1Parser = ASN1Parser(bytes);
    final sequence = asn1Parser.nextObject() as ASN1Sequence;

    final n = (sequence.elements[0] as ASN1Integer).valueAsBigInteger;
    final e = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;

    return RSAPublicKey(n, e);
  }

  /// Parse RSA private key from ASN.1 DER format
  static RSAPrivateKey parsePrivateKeyFromASN1(Uint8List bytes) {
    final asn1Parser = ASN1Parser(bytes);
    final sequence = asn1Parser.nextObject() as ASN1Sequence;

    final n = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;
    final d = (sequence.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (sequence.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (sequence.elements[5] as ASN1Integer).valueAsBigInteger;

    return RSAPrivateKey(n, d, p, q);
  }

  /// Convert map to canonical JSON (alphabetically sorted keys)
  static String canonicalJsonEncode(Map<String, dynamic> map) {
    // Sort keys alphabetically
    final sortedMap = SplayTreeMap<String, dynamic>.from(
      map,
      (a, b) => a.compareTo(b),
    );

    // Recursively sort nested objects
    dynamic sortValue(dynamic value) {
      if (value is Map<String, dynamic>) {
        final sorted = SplayTreeMap<String, dynamic>.from(
          value,
          (a, b) => a.compareTo(b),
        );
        return sorted.map((k, v) => MapEntry(k, sortValue(v)));
      } else if (value is List) {
        return value.map((e) => sortValue(e)).toList();
      }
      return value;
    }

    final sorted = sortedMap.map((k, v) => MapEntry(k, sortValue(v)));
    return jsonEncode(sorted);
  }
}
