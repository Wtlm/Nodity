const forge = require('node-forge');
const admin = require('firebase-admin');
const fs = require('fs');

// load serviceAccountKey.json (download from Firestore console)
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

async function generateRootCert() {
  console.log('Generating RSA key pair (2048)...');
  const keys = forge.pki.rsa.generateKeyPair(2048);
  const privateKey = keys.privateKey;
  const publicKey = keys.publicKey;

  // DER of publicKey (RSAPublicKey ASN.1)
  const publicKeyAsn1 = forge.pki.publicKeyToAsn1(publicKey);
  const publicKeyDer = forge.asn1.toDer(publicKeyAsn1).getBytes();
  const publicKeyBase64 = forge.util.encode64(publicKeyDer);

  // DER of privateKey (ASN.1)
  const privateKeyAsn1 = forge.pki.privateKeyToAsn1(privateKey);
  const privateKeyDer = forge.asn1.toDer(privateKeyAsn1).getBytes();
  const privateKeyBase64 = forge.util.encode64(privateKeyDer);

  const issuedTime = new Date();
  const expiresTime = new Date(issuedTime);
  expiresTime.setFullYear(expiresTime.getFullYear() + 10); // 10y

  const rootRef = db.collection('rootCert').doc('rootCA'); // fixed id
  const certContent = {
    version: 3,
    serialNumber: rootRef.id,
    signatureAlgorithm: 'SHA256withRSA',
    issuer: 'Nodity CA',
    subject: 'Nodity CA',
    publicKey: publicKeyBase64,
    issuedAt: issuedTime.toISOString(),
    expiresAt: expiresTime.toISOString(),
  };

  await rootRef.set({
    rootCertId: rootRef.id,
    rootCertData: certContent,
    issuedAt: issuedTime.toISOString(),
    expiresAt: expiresTime.toISOString(),
    // store privateKey as base64 DER for record (do NOT use to sign on server)
    privateKey: privateKeyBase64,
  });

  // Output PEM for server .env
  const privatePem = forge.pki.privateKeyToPem(privateKey);
  console.log('\n=== ROOT PRIVATE KEY (PEM) — put this into your server .env as ROOT_PRIVATE_KEY ===\n');
  console.log(privatePem);
  console.log('=== END PEM ===\n');

  console.log('Root cert saved (doc id =', rootRef.id, ').');
  process.exit(0);
}

generateRootCert().catch((e) => {
  console.error('Error:', e);
  process.exit(1);
});
