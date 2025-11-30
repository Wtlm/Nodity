import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import './root_cert_service.dart';

/// Diagnostic tool to check Firestore root certificate structure
class FirestoreDiagnostic {
  static final _db = FirebaseFirestore.instance;
  
  /// Check root certificate in Firestore
  static Future<void> checkRootCertificate() async {
    print('\n╔════════════════════════════════════════════════════╗');
    print('║  Firestore Root Certificate Diagnostic            ║');
    print('╚════════════════════════════════════════════════════╝\n');
    
    try {
      // Get all root certificates
      print('📋 Fetching root certificates...');
      final allRootCerts = await _db.collection('rootCert').get();
      
      print('Found ${allRootCerts.docs.length} root certificate(s)\n');
      
      if (allRootCerts.docs.isEmpty) {
        print('❌ ERROR: No root certificates found!');
        print('\n💡 Solution: Generate a root certificate first:');
        print('   await RootCertService.generateRootCert();\n');
        return;
      }
      
      // Check each certificate
      for (var i = 0; i < allRootCerts.docs.length; i++) {
        final doc = allRootCerts.docs[i];
        print('─────────────────────────────────────────────────────');
        print('Certificate ${i + 1}/${allRootCerts.docs.length}');
        print('─────────────────────────────────────────────────────');
        
        await _checkCertificateDocument(doc);
        print('');
      }
      
      // Get the one that would be used (latest)
      print('═════════════════════════════════════════════════════');
      print('🎯 Testing actual query used by app...\n');
      
      final querySnap = await _db
          .collection('rootCert')
          .orderBy('issuedAt', descending: true)
          .limit(1)
          .get();
      
      if (querySnap.docs.isEmpty) {
        print('❌ Query returned no results!');
        print('   Check if "issuedAt" field exists at document root level\n');
      } else {
        final selectedDoc = querySnap.docs.first;
        print('✅ Query successful!');
        print('   Selected document ID: ${selectedDoc.id}');
        print('   This is the certificate that will be used for verification\n');
        
        // Show which one was selected
        final data = selectedDoc.data();
        if (data['issuedAt'] != null) {
          print('   Issued at: ${data['issuedAt']}');
        }
        
        // Extract and show modulus
        if (data['rootCertData'] != null && 
            data['rootCertData']['publicKey'] != null) {
          try {
            final pubKey = RootCertService.parsePublicKeyFromASN1(
              base64Decode(data['rootCertData']['publicKey']),
            );
            print('   Modulus (first 50 hex chars):');
            print('   ${pubKey.modulus!.toRadixString(16).substring(0, 50)}...');
            print('\n   👆 Compare this with your backend logs!');
          } catch (e) {
            print('   ⚠️  Could not parse public key: $e');
          }
        }
      }
      
      print('\n═════════════════════════════════════════════════════');
      print('✅ Diagnostic complete!');
      print('═════════════════════════════════════════════════════\n');
      
    } catch (e) {
      print('❌ Error during diagnostic: $e\n');
    }
  }
  
  static Future<void> _checkCertificateDocument(
    DocumentSnapshot doc,
  ) async {
    print('Document ID: ${doc.id}');
    
    if (!doc.exists) {
      print('❌ Document does not exist');
      return;
    }
    
    final data = doc.data() as Map<String, dynamic>?;
    
    if (data == null) {
      print('❌ Document has no data');
      return;
    }
    
    // Check required fields
    final checks = <String, bool>{};
    
    // Root level fields
    checks['rootCertId'] = data.containsKey('rootCertId');
    checks['issuedAt (root level)'] = data.containsKey('issuedAt');
    checks['expiresAt (root level)'] = data.containsKey('expiresAt');
    checks['rootCertData'] = data.containsKey('rootCertData');
    
    // Check rootCertData structure
    if (data['rootCertData'] != null) {
      final certData = data['rootCertData'] as Map<String, dynamic>;
      checks['rootCertData.version'] = certData.containsKey('version');
      checks['rootCertData.serialNumber'] = certData.containsKey('serialNumber');
      checks['rootCertData.signatureAlgorithm'] = 
          certData.containsKey('signatureAlgorithm');
      checks['rootCertData.issuer'] = certData.containsKey('issuer');
      checks['rootCertData.subject'] = certData.containsKey('subject');
      checks['rootCertData.publicKey'] = certData.containsKey('publicKey');
      checks['rootCertData.issuedAt'] = certData.containsKey('issuedAt');
      checks['rootCertData.expiresAt'] = certData.containsKey('expiresAt');
      
      // Check publicKey is valid base64
      if (certData['publicKey'] != null) {
        try {
          final decoded = base64Decode(certData['publicKey']);
          checks['publicKey is valid base64'] = decoded.isNotEmpty;
        } catch (e) {
          checks['publicKey is valid base64'] = false;
        }
      }
    }
    
    // Print results
    print('\nField Check:');
    checks.forEach((field, exists) {
      final status = exists ? '✅' : '❌';
      print('  $status $field');
    });
    
    // Show issued/expires dates
    if (data['issuedAt'] != null) {
      print('\nIssued at: ${data['issuedAt']}');
    }
    if (data['expiresAt'] != null) {
      print('Expires at: ${data['expiresAt']}');
    }
    
    // Check if expired
    if (data['expiresAt'] != null) {
      try {
        final expiresAt = DateTime.parse(data['expiresAt']);
        final isExpired = DateTime.now().isAfter(expiresAt);
        if (isExpired) {
          print('⚠️  WARNING: This certificate has EXPIRED!');
        } else {
          print('✅ Certificate is not expired');
        }
      } catch (e) {
        print('⚠️  Could not parse expiry date');
      }
    }
    
    // Show public key info
    if (data['rootCertData'] != null && 
        data['rootCertData']['publicKey'] != null) {
      try {
        final pubKey = RootCertService.parsePublicKeyFromASN1(
          base64Decode(data['rootCertData']['publicKey']),
        );
        print('\nPublic Key Info:');
        print('  Key size: ${pubKey.modulus!.bitLength} bits');
        print('  Modulus (first 50 hex chars):');
        print('  ${pubKey.modulus!.toRadixString(16).substring(0, 50)}...');
      } catch (e) {
        print('\n❌ Error parsing public key: $e');
      }
    }
    
    // Overall status
    final allPassed = checks.values.every((v) => v);
    if (allPassed) {
      print('\n✅ This certificate structure looks good!');
    } else {
      print('\n⚠️  This certificate has some issues that need fixing');
    }
  }
  
  /// Clean up duplicate or old root certificates
  static Future<void> cleanupOldCertificates({
    bool keepLatest = true,
    bool dryRun = true,
  }) async {
    print('\n🧹 Root Certificate Cleanup Tool\n');
    
    if (dryRun) {
      print('📋 DRY RUN MODE - No changes will be made\n');
    }
    
    final allCerts = await _db
        .collection('rootCert')
        .orderBy('issuedAt', descending: true)
        .get();
    
    print('Found ${allCerts.docs.length} root certificate(s)\n');
    
    if (allCerts.docs.length <= 1) {
      print('✅ Only one certificate found, nothing to clean up\n');
      return;
    }
    
    if (keepLatest) {
      print('Will keep the LATEST certificate (newest issuedAt)\n');
      
      for (var i = 0; i < allCerts.docs.length; i++) {
        final doc = allCerts.docs[i];
        final data = doc.data();
        
        if (i == 0) {
          print('✅ KEEPING: ${doc.id}');
          print('   Issued: ${data['issuedAt']}');
        } else {
          print('🗑️  Would delete: ${doc.id}');
          print('   Issued: ${data['issuedAt']}');
          
          if (!dryRun) {
            await doc.reference.delete();
            print('   ✅ Deleted');
          }
        }
        print('');
      }
      
      if (dryRun) {
        print('💡 To actually delete, call with dryRun: false\n');
      } else {
        print('✅ Cleanup complete!\n');
      }
    }
  }
}

