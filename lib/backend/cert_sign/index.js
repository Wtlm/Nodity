const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const forge = require('node-forge');
require('dotenv').config();

const app = express();
app.use(bodyParser.json());

const privateKeyPem = process.env.ROOT_PRIVATE_KEY;

// Use forge only to extract modulus for logging
const forgeKey = forge.pki.privateKeyFromPem(privateKeyPem);
console.log(
  "Server root modulus hex:",
  forgeKey.n.toString(16).slice(0, 100)
);


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
  // Keep the same canonicalJsonStringify helper from your file.
  const certContent = canonicalJsonStringify(req.body.certContent);

  console.log('=== SERVER SIGNING ===');
  console.log('Canonical certContent:', certContent);
  console.log('Content length:', certContent.length, 'bytes');

  // SHA-256 of canonical string using Node.js crypto
  const hash = crypto.createHash('sha256');
  hash.update(certContent, 'utf8');
  const hashBuffer = hash.digest();
  const hashHex = hashBuffer.toString('hex');
  console.log('SHA-256 hash (hex):', hashHex);
  console.log('Hash length:', hashBuffer.length, 'bytes');

  // Sign using Node.js crypto with PKCS#1 v1.5 padding (RSA_PKCS1_PADDING)
  const sign = crypto.createSign('SHA256');
  sign.update(certContent, 'utf8');
  sign.end();
  
  const signatureBuffer = sign.sign({
    key: privateKeyPem,
    padding: crypto.constants.RSA_PKCS1_PADDING
  });
  
  const signatureBase64 = signatureBuffer.toString('base64');

  console.log('Signature created (base64):', signatureBase64);
  console.log('Signature length:', signatureBuffer.length, 'bytes');
  console.log('=== END SERVER SIGNING ===');

  // Return signature + canonical + hash for debugging/verification
  res.json({
    rootSignature: signatureBase64,
    canonical: certContent,
    sha256Hex: hashHex
  });
});


const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server on port ${PORT}`));
