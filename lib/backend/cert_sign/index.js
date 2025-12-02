require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');

const app = express();
app.use(bodyParser.json({ limit: '1mb' }));

const ROOT_PRIVATE_KEY_PEM = process.env.ROOT_PRIVATE_KEY;
if (!ROOT_PRIVATE_KEY_PEM) {
  console.error('Please set ROOT_PRIVATE_KEY in .env (PEM format).');
  process.exit(1);
}

// canonical JSON: stable stringify with sorted object keys (recursive)
function canonicalize(obj) {
  if (obj === null) return null;
  if (Array.isArray(obj)) {
    return '[' + obj.map((v) => canonicalize(v)).join(',') + ']';
  }
  if (typeof obj === 'object') {
    const keys = Object.keys(obj).sort();
    return '{' + keys.map((k) => JSON.stringify(k) + ':' + canonicalize(obj[k])).join(',') + '}';
  }
  // primitive: use JSON.stringify to ensure proper escaping
  return JSON.stringify(obj);
}

app.post('/sign-cert', (req, res) => {
  try {
    const { certContent } = req.body;
    if (!certContent || typeof certContent !== 'object') {
      return res.status(400).json({ error: 'certContent required (object)' });
    }

    // Build canonical JSON with sorted keys
    const canonical = canonicalize(certContent);

    // Sign using RSA + SHA256 PKCS#1 v1.5
    const signer = crypto.createSign('RSA-SHA256');
    signer.update(Buffer.from(canonical, 'utf8'));
    signer.end();

    const signature = signer.sign({
      key: ROOT_PRIVATE_KEY_PEM,
      padding: crypto.constants.RSA_PKCS1_PADDING,
    });

    const signatureBase64 = signature.toString('base64');

    return res.json({ rootSignature: signatureBase64 });
  } catch (e) {
    console.error('Error in /sign-cert:', e);
    return res.status(500).json({ error: e.message });
  }
});

const PORT = process.env.PORT || 10000;
app.listen(PORT, () => {
  console.log(`Signing server listening on ${PORT}`);
});
