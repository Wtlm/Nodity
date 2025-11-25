// Helper script to convert base64 private key from Firebase to PEM format
// Usage: node convert_key.js <base64_private_key>

const forge = require('node-forge');

const base64PrivateKey = process.argv[2];

if (!base64PrivateKey) {
  console.error('Usage: node convert_key.js <base64_private_key>');
  process.exit(1);
}

try {
  // Decode base64 to bytes
  const privateKeyBytes = forge.util.decode64(base64PrivateKey);
  
  // Parse ASN.1 structure
  const asn1 = forge.asn1.fromDer(privateKeyBytes);
  
  // Convert to private key object
  const privateKey = forge.pki.privateKeyFromAsn1(asn1);
  
  // Convert to PEM format
  const pem = forge.pki.privateKeyToPem(privateKey);
  
  console.log('=== PEM Format (use this as ROOT_PRIVATE_KEY) ===');
  console.log(pem);
  console.log('=== End PEM ===');
  
  // Verify by extracting public key
  const publicKey = forge.pki.setRsaPublicKey(privateKey.n, privateKey.e);
  const publicKeyAsn1 = forge.pki.publicKeyToAsn1(publicKey);
  const publicKeyDer = forge.asn1.toDer(publicKeyAsn1).getBytes();
  const publicKeyBase64 = forge.util.encode64(publicKeyDer);
  
  console.log('\n=== Public Key (verify this matches Firebase) ===');
  console.log(publicKeyBase64);
  console.log('=== End Public Key ===');
  
} catch (error) {
  console.error('Error converting key:', error.message);
  process.exit(1);
}


