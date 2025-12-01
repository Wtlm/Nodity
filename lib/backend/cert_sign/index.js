const express = require('express');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
app.use(express.json({ limit: '10mb' }));

// Load private key from environment
const privateKeyPem = process.env.ROOT_PRIVATE_KEY;

if (!privateKeyPem) {
  console.error('ERROR: ROOT_PRIVATE_KEY not found in environment variables');
  process.exit(1);
}

console.log('✓ Server started successfully');
console.log('✓ Private key loaded from environment');

/**
 * Canonical JSON: Sort object keys alphabetically
 */
function canonicalJson(obj) {
  if (obj === null || typeof obj !== 'object' || Array.isArray(obj)) {
    return JSON.stringify(obj);
  }
  
  const sorted = {};
  Object.keys(obj).sort().forEach(key => {
    sorted[key] = obj[key];
  });
  
  return JSON.stringify(sorted);
}

/**
 * Sign certificate endpoint
 */
app.post('/sign-cert', (req, res) => {
  try {
    const { certContent } = req.body;
    
    if (!certContent) {
      return res.status(400).json({ error: 'certContent is required' });
    }

    // Convert to canonical JSON
    const canonical = canonicalJson(certContent);
    
    console.log('\n=== SIGNING REQUEST ===');
    console.log('Canonical JSON:', canonical);
    
    // Compute SHA-256 hash
    const hash = crypto.createHash('sha256');
    hash.update(canonical, 'utf8');
    const hashHex = hash.digest('hex');
    
    console.log('SHA-256 hash:', hashHex);
    
    // Sign using RSA-SHA256 with PKCS#1 v1.5 padding
    const sign = crypto.createSign('RSA-SHA256');
    sign.update(canonical, 'utf8');
    sign.end();
    
    const signature = sign.sign({
      key: privateKeyPem,
      padding: crypto.constants.RSA_PKCS1_PADDING
    });
    
    const signatureBase64 = signature.toString('base64');
    
    console.log('Signature length:', signature.length, 'bytes');
    console.log('Signature (base64):', signatureBase64.substring(0, 60) + '...');
    
    // Self-verify
    const verify = crypto.createVerify('RSA-SHA256');
    verify.update(canonical, 'utf8');
    verify.end();
    
    // Extract public key from private key for verification
    const publicKeyObj = crypto.createPublicKey(privateKeyPem);
    const publicKeyPem = publicKeyObj.export({
      type: 'spki',
      format: 'pem'
    });
    
    const verified = verify.verify({
      key: publicKeyPem,
      padding: crypto.constants.RSA_PKCS1_PADDING
    }, signature);
    
    console.log('Self-verification:', verified ? '✓ SUCCESS' : '✗ FAILED');
    console.log('=== END SIGNING ===\n');
    
    res.json({
      rootSignature: signatureBase64,
      canonical: canonical,
      sha256Hex: hashHex,
      success: true
    });
    
  } catch (error) {
    console.error('Signing error:', error.message);
    res.status(500).json({ 
      error: 'Signing failed', 
      message: error.message 
    });
  }
});

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'cert-signing' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`\n🚀 Certificate signing server running on port ${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
  console.log(`📍 Sign endpoint: http://localhost:${PORT}/sign-cert\n`);
});
