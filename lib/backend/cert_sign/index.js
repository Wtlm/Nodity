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
  console.log('Certificate content:', certContent);
  console.log('Content length:', certContent.length, 'bytes');
  
  // Create SHA-256 hash
  const md = forge.md.sha256.create();
  md.update(certContent, 'utf8');
  const hashHex = md.digest().toHex();
  
  console.log('SHA-256 hash (hex):', hashHex);
  console.log('Hash length:', hashHex.length / 2, 'bytes');
  
  // Sign the hash (this is the raw signature)
  md.update(certContent, 'utf8'); // Re-update because digest() consumes it
  const signature = privateKey.sign(md);
  const signatureBase64 = forge.util.encode64(signature);
  
  console.log('Signature created (base64):', signatureBase64);
  console.log('Signature length:', signature.length, 'bytes');
  res.json({ rootSignature: signatureBase64 });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server on port ${PORT}`));
