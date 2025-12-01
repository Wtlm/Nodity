const express = require('express');
const forge = require('node-forge');
require('dotenv').config();

const app = express();
app.use(express.json({ limit: '10mb' }));

// Load and parse private key from environment
let privateKey;
const privateKeyEnv = process.env.ROOT_PRIVATE_KEY;

if (!privateKeyEnv) {
  console.error('ERROR: ROOT_PRIVATE_KEY not found in environment variables');
  process.exit(1);
}

try {
  // Try parsing as PEM first
  if (privateKeyEnv.includes('BEGIN RSA PRIVATE KEY') || privateKeyEnv.includes('BEGIN PRIVATE KEY')) {
    privateKey = forge.pki.privateKeyFromPem(privateKeyEnv);
    console.log('✓ Private key loaded from PEM format');
  } else {
    // Parse as base64 DER (from Firestore)
    console.log('Parsing base64 DER key from Firestore...');
    const derBytes = forge.util.decode64(privateKeyEnv.replace(/\s/g, ''));
    const asn1 = forge.asn1.fromDer(derBytes);
    privateKey = forge.pki.privateKeyFromAsn1(asn1);
    console.log('✓ Private key loaded from base64 DER format');
  }
  console.log('✓ Server started successfully');
} catch (e) {
  console.error('ERROR: Failed to parse private key:', e.message);
  console.error('Make sure ROOT_PRIVATE_KEY is in PEM format or base64 DER format');
  process.exit(1);
}

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
    
    // Compute SHA-256 hash using node-forge
    const md = forge.md.sha256.create();
    md.update(canonical, 'utf8');
    const hashHex = md.digest().toHex();
    
    console.log('SHA-256 hash:', hashHex);
    
    // Sign using RSA-SHA256 with PKCS#1 v1.5 padding
    const mdForSigning = forge.md.sha256.create();
    mdForSigning.update(canonical, 'utf8');
    const signature = privateKey.sign(mdForSigning);
    const signatureBase64 = forge.util.encode64(signature);
    
    console.log('Signature length:', signature.length, 'bytes');
    console.log('Signature (base64):', signatureBase64.substring(0, 60) + '...');
    
    // Self-verify
    const publicKey = forge.pki.rsa.setPublicKey(privateKey.n, privateKey.e);
    const mdForVerify = forge.md.sha256.create();
    mdForVerify.update(canonical, 'utf8');
    const verified = publicKey.verify(mdForVerify.digest().bytes(), signature);
    
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
    console.error('Stack:', error.stack);
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
