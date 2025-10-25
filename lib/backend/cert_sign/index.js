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
  const md = forge.md.sha256.create();
  md.update(certContent, 'utf8');
  console.log('Certificate content:', certContent);
  const signature = privateKey.sign(md);
  const signatureBase64 = forge.util.encode64(signature);
  res.json({ rootSignature: signatureBase64 });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server on port ${PORT}`));
