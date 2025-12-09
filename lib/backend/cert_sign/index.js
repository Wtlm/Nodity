const express = require('express');
const bodyParser = require('body-parser');
const forge = require('node-forge');
const fs = require('fs');

const app = express();
app.use(bodyParser.json());

// Read private key from Render secret file
const privateKeyPem = fs.readFileSync('/etc/secrets/ROOT_PRIVATE_KEY', 'utf8');

console.log('=== SERVER KEY LOADING ===');
console.log('PEM length:', privateKeyPem.length, 'chars');
console.log('PEM starts with:', privateKeyPem.substring(0, 50));
console.log('PEM ends with:', privateKeyPem.substring(privateKeyPem.length - 50));

let privateKey;
try {
  privateKey = forge.pki.privateKeyFromPem(privateKeyPem);
  console.log('Private key loaded successfully');
  console.log('Server root modulus hex:', privateKey.n.toString(16).slice(0, 100));
  console.log('Server public exponent:', privateKey.e.toString(10));
  console.log('Modulus bit length:', privateKey.n.bitLength());
} catch (e) {
  console.error('Failed to load private key:', e.message);
  process.exit(1);
}
console.log('=== END SERVER KEY LOADING ===');


/**
 * Converts an object to canonical JSON string with sorted keys
 * This ensures consistent encoding between JavaScript and Dart
 */
function canonicalJsonStringify(obj) {
  if (obj === null || typeof obj !== 'object' || Array.isArray(obj)) {
    return JSON.stringify(obj);
  }
  
  const sortedKeys = Object.keys(obj).sort();
  const sortedObj = {};
  
  for (const key of sortedKeys) {
    sortedObj[key] = obj[key];
  }
  
  return JSON.stringify(sortedObj);
}

app.post('/sign-cert', (req, res) => {
  try {
    // Keep the same canonicalJsonStringify helper from your file.
    const certContent = canonicalJsonStringify(req.body.certContent);

    console.log('=== SERVER SIGNING ===');
    console.log('Canonical certContent:', certContent);
    console.log('Content length:', certContent.length, 'bytes');

    // SHA-256 of canonical string
    const md = forge.md.sha256.create();
    md.update(certContent, 'utf8');
    const hashBytes = md.digest().bytes();
    const hashHex = forge.util.bytesToHex(hashBytes);
    console.log('SHA-256 hash (hex):', hashHex);
    console.log('Hash length:', hashBytes.length, 'bytes');

    // Recreate digest for signing
    const mdForSigning = forge.md.sha256.create();
    mdForSigning.update(certContent, 'utf8');

    const signature = privateKey.sign(mdForSigning);
    const signatureBase64 = forge.util.encode64(signature);

    console.log('Signature created (base64):', signatureBase64);
    console.log('Signature length:', signature.length, 'bytes');
    console.log('Signature first 20 bytes (hex):', forge.util.bytesToHex(signature.slice(0, 20)));
    console.log('=== END SERVER SIGNING ===');

    // Return signature + canonical + hash for debugging/verification
    res.json({
      rootSignature: signatureBase64,
      canonical: certContent,
      sha256Hex: hashHex
    });
  } catch (error) {
    console.error('Signing error:', error);
    res.status(500).json({ error: error.message });
  }
});


const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server on port ${PORT}`));
