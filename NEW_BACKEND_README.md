# New Certificate Backend - Complete Rewrite

## 🎉 What's New

I've completely rewritten the certificate signing and verification backend from scratch with:

- ✅ **Node.js native `crypto` module** (instead of node-forge) - more reliable and standard
- ✅ **Simplified, clean Dart code** - easier to understand and maintain
- ✅ **Better error handling** - clear success/failure messages with ✓ and ✗ symbols
- ✅ **Minimal logging** - only essential information, no debug clutter
- ✅ **Standard RSA-SHA256** - guaranteed compatibility between Node.js and Dart

## 📁 Files Changed

### Backend (Node.js)
- **`lib/backend/cert_sign/index.js`** - Complete rewrite using Node.js native crypto

### Dart Services
- **`lib/backend/service/cert_service.dart`** - Clean implementation with simplified verification
- **`lib/backend/service/root_cert_service.dart`** - Streamlined signing and key management

## 🚀 How to Use

### 1. Start the Backend Server

```bash
cd D:\Thesis\Nodity\lib\backend\cert_sign
node index.js
```

You should see:
```
✓ Server started successfully
✓ Private key loaded from environment
🚀 Certificate signing server running on port 3000
```

### 2. Run Your Flutter App

```bash
cd D:\Thesis\Nodity
flutter build apk --release
# Then install and run on your device
```

### 3. Test Certificate Operations

The new code will automatically work when you:
- Generate a new certificate
- Verify a certificate
- Sign a message
- Verify a signature

## ✅ What to Expect

### Successful Certificate Signing (Server):
```
=== SIGNING REQUEST ===
Canonical JSON: {...}
SHA-256 hash: abc123...
Signature length: 256 bytes
Self-verification: ✓ SUCCESS
=== END SIGNING ===
```

### Successful Certificate Verification (Client):
```
=== CERTIFICATE VERIFICATION ===
Certificate ID: xyz789
Canonical JSON: {...}
SHA-256 hash: abc123...
Verification result: ✓ VALID
=== END VERIFICATION ===
```

### Failed Verification:
```
=== CERTIFICATE VERIFICATION ===
...
Verification result: ✗ INVALID
=== END VERIFICATION ===
```

## 🔧 Key Improvements

### 1. Node.js Native Crypto
- Uses `crypto.createSign()` and `crypto.createVerify()`
- Standard RSA-SHA256 with PKCS#1 v1.5 padding
- Guaranteed compatibility with OpenSSL standard

### 2. Simplified Dart Code
- Direct use of `RSASigner` with SHA256Digest
- No manual padding/verification needed
- Clean error handling with try-catch

### 3. Better Logging
- Clear success indicators (✓) and failure indicators (✗)
- Essential information only
- Easy to read and understand

## 🔍 Troubleshooting

### If Server Won't Start
**Error:** `ROOT_PRIVATE_KEY not found in environment variables`

**Solution:** Make sure your `.env` file in `lib/backend/cert_sign/` contains:
```
ROOT_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----
...your key here...
-----END RSA PRIVATE KEY-----"
```

### If Verification Fails
Check these common issues:

1. **Key Mismatch**
   - Ensure root certificate in Firestore has the correct public key
   - Public key must match the private key in server's `.env`

2. **Expired Certificate**
   - Check certificate dates in Firestore
   - Regenerate if expired

3. **Network Issues**
   - Ensure backend server is running
   - Check `backendUrl` in `root_cert_service.dart`

## 📊 Technical Details

### Signing Algorithm
- **Algorithm:** RSA-SHA256
- **Padding:** PKCS#1 v1.5
- **Key Size:** 2048 bits
- **Signature Size:** 256 bytes

### Canonical JSON
Both server and client use the same canonical JSON format:
- Keys sorted alphabetically
- No extra whitespace
- Consistent encoding

### Hash Algorithm
- **Algorithm:** SHA-256
- **Output Size:** 32 bytes (256 bits)
- **Encoding:** Hexadecimal for logging

## 🎯 Why This Version Works

1. **Standard Implementation**
   - Node.js crypto module implements standard RSA-PKCS1-v1_5
   - PointyCastle implements the same standard
   - No custom padding or encoding needed

2. **Clean Code**
   - Single responsibility per function
   - Clear error messages
   - Easy to debug

3. **Proven Libraries**
   - Node.js crypto: battle-tested, part of Node.js core
   - PointyCastle: mature Dart crypto library
   - Both implement OpenSSL standards

## 📝 Code Structure

### Server (index.js)
```javascript
POST /sign-cert
  ↓
1. Receive certContent
2. Create canonical JSON
3. Compute SHA-256 hash
4. Sign with crypto.createSign('RSA-SHA256')
5. Self-verify
6. Return signature + hash
```

### Client (cert_service.dart)
```dart
verifyUserCert(certId)
  ↓
1. Fetch certificate from Firestore
2. Check time validity
3. Create canonical JSON
4. Compute SHA-256 hash
5. Fetch root public key
6. Verify with RSASigner(SHA256Digest())
7. Return true/false
```

## 🔐 Security Notes

- Private keys stored securely in `.env` (server) and FlutterSecureStorage (client)
- All communication over HTTPS
- Signatures use industry-standard RSA-SHA256
- Public keys stored in Firestore (safe to share)

## 🆘 Need Help?

If you encounter issues:

1. **Check server logs** - Look for ✗ symbols indicating errors
2. **Check client logs** - Look for error messages in Flutter console
3. **Compare hashes** - Server and client should compute the same SHA-256 hash
4. **Verify keys match** - Root public key in Firestore must match server private key

---

## 🎉 Quick Start Checklist

- [ ] Server is running (`node index.js`)
- [ ] `.env` file contains `ROOT_PRIVATE_KEY`
- [ ] Root certificate exists in Firestore at `rootCert/rootCA`
- [ ] Flutter app is built and running
- [ ] Network allows communication with backend server

If all boxes are checked, certificate operations should work! ✅

