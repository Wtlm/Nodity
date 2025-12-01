const express = require('express');
const forge = require('node-forge');
require('dotenv').config();

const app = express();
app.use(express.json({ limit: '10mb' }));

// Load private key from environment
const privateKeyPem = process.env.ROOT_PRIVATE_KEY;
if (!privateKeyPem) {
  console.error('ERROR: ROOT_PRIVATE_KEY not found');
  process.exit(1);
}

let privateKey;
try {
  privateKey = forge.pki.privateKeyFromPem(privateKeyPem);
  console.log('✓ Private key loaded');
} catch (e) {
  console.error('ERROR: Invalid private key format');
  process.exit(1);
}

// Canonical JSON - sort keys alphabetically
function canonicalJson(obj) {
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) {
    return JSON.stringify(obj);
  }
  const sorted = {};
  Object.keys(obj).sort().forEach(k => sorted[k] = obj[k]);
  return JSON.stringify(sorted);
}

// Sign certificate endpoint
app.post('/sign-cert', (req, res) => {
  try {
    const certContent = req.body.certContent;
    if (!certContent) {
      return res.status(400).json({ error: 'certContent required' });
    }

    // Create canonical JSON
    const canonical = canonicalJson(certContent);
    
    // Create hash
    const md = forge.md.sha256.create();
    md.update(canonical, 'utf8');
    const hash = md.digest().toHex();
    
    // Sign (creates new digest for signing)
    const mdSign = forge.md.sha256.create();
    mdSign.update(canonical, 'utf8');
    const signature = privateKey.sign(mdSign);
    const signatureB64 = forge.util.encode64(signature);
    
    console.log('Signed cert, hash:', hash.substring(0, 16) + '...');
    
    res.json({
      rootSignature: signatureB64,
      canonical: canonical,
      sha256Hex: hash
    });
  } catch (e) {
    console.error('Error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
