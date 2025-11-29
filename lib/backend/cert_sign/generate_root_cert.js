// Script to generate a new root certificate and save it to Firebase
// This will also output the private key in PEM format for the server

const forge = require('node-forge');
const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to provide your service account key)
// Download from Firebase Console → Project Settings → Service Accounts
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function generateRootCert() {
  console.log('Generating RSA key pair...');
  
  // Generate 2048-bit RSA key pair
  const keys = forge.pki.rsa.generateKeyPair(2048);
  const privateKey = keys.privateKey;
  const publicKey = keys.publicKey;
  
  console.log('Key pair generated!');
  
  // Create certificate content
  const issuedTime = new Date();
  const expiresTime = new Date(issuedTime);
  expiresTime.setFullYear(expiresTime.getFullYear() + 10); // 10 years
  
  // Convert public key to ASN.1 DER format (matching Dart's format)
  const publicKeyAsn1 = forge.pki.publicKeyToAsn1(publicKey);
  const publicKeyDer = forge.asn1.toDer(publicKeyAsn1).getBytes();
  const publicKeyBase64 = forge.util.encode64(publicKeyDer);
  
  const certContent = {
    version: 3,
    serialNumber: db.collection('rootCert').doc('rootCA').id,
    signatureAlgorithm: 'SHA256withRSA',
    issuer: 'Nodity CA',
    subject: 'Nodity CA',
    publicKey: publicKeyBase64,
    issuedAt: issuedTime.toISOString(),
    expiresAt: expiresTime.toISOString()
  };
  
  // Convert private key to ASN.1 DER format (matching Dart's format)
  const privateKeyAsn1 = forge.pki.privateKeyToAsn1(privateKey);
  const privateKeyDer = forge.asn1.toDer(privateKeyAsn1).getBytes();
  const privateKeyBase64 = forge.util.encode64(privateKeyDer);
  
  // Save to Firebase
  console.log('Saving to Firebase...');
  const rootCertRef = db.collection('rootCert').doc('rootCA');
  
  await rootCertRef.set({
    rootCertId: rootCertRef.id,
    rootCertData: certContent,
    issuedAt: issuedTime.toISOString(),
    expiresAt: expiresTime.toISOString(),
    privateKey: privateKeyBase64
  });
  
  console.log('✅ Root certificate saved to Firebase!');
  console.log('Document ID:', rootCertRef.id);
  
  // Output private key in PEM format for server
  const privateKeyPem = forge.pki.privateKeyToPem(privateKey);
  
  console.log('\n=== COPY THIS TO YOUR .env FILE ===');
  console.log('ROOT_PRIVATE_KEY=');
  console.log(privateKeyPem);
  console.log('=== END ===');
  
  console.log('\n⚠️  IMPORTANT: Delete all existing user certificates from Firebase!');
  console.log('They were signed with the old root certificate and will no longer be valid.');
  
  process.exit(0);
}

generateRootCert().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});


