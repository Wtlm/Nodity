const express = require('express');
const bodyParser = require('body-parser');
const forge = require('node-forge');
require('dotenv').config();

const app = express();
app.use(bodyParser.json());

const privateKeyPem = process.env.ROOT_PRIVATE_KEY;
const privateKey = forge.pki.privateKeyFromPem(privateKeyPem);

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
  const certContent = canonicalJsonStringify(req.body.certContent); 
  console.log('=== SERVER SIGNING ===');
  console.log('Certificate content:', certContent);
  console.log('Content length:', certContent.length, 'bytes');
  
  // Create SHA-256 hash
  const md = forge.md.sha256.create();
  md.update(certContent, 'utf8');
  
  // Get hash for logging (creates a copy so we don't consume the original)
  const hashBytes = md.digest().bytes();
  const hashHex = forge.util.bytesToHex(hashBytes);
  console.log('SHA-256 hash (hex):', hashHex);
  console.log('Hash length:', hashBytes.length, 'bytes');
  
  // Re-create the message digest for signing (because digest() consumed it)
  const mdForSigning = forge.md.sha256.create();
  mdForSigning.update(certContent, 'utf8');
  
  // Sign the hash with PKCS#1 v1.5 padding
  const signature = privateKey.sign(mdForSigning);
  const signatureBase64 = forge.util.encode64(signature);
  
  console.log('Signature created (base64):', signatureBase64);
  console.log('Signature length:', signature.length, 'bytes');
  console.log('=== END SERVER SIGNING ===');
  
  res.json({ rootSignature: signatureBase64 });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server on port ${PORT}`));
