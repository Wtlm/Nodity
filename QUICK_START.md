# Quick Start Guide - New Certificate Backend

## 🚀 Get Started in 3 Steps

### Step 1: Start the Server
```bash
cd D:\Thesis\Nodity\lib\backend\cert_sign
node index.js
```

**Expected output:**
```
✓ Server started successfully
✓ Private key loaded from environment
🚀 Certificate signing server running on port 3000
```

### Step 2: Build and Run Flutter App
```bash
cd D:\Thesis\Nodity
flutter build apk --release
```

Install the APK on your device and run it.

### Step 3: Test Certificate Operations

Use your app to:
- Generate a certificate
- Verify a certificate
- Sign/verify messages

## ✅ Success Indicators

### On Server Console:
```
=== SIGNING REQUEST ===
Canonical JSON: {...}
SHA-256 hash: [hash]
Self-verification: ✓ SUCCESS
=== END SIGNING ===
```

### On Flutter App:
```
=== CERTIFICATE VERIFICATION ===
Certificate ID: [id]
SHA-256 hash: [hash]
Verification result: ✓ VALID
=== END VERIFICATION ===
```

## ❌ If Something Goes Wrong

### Server Error: "ROOT_PRIVATE_KEY not found"
1. Check `.env` file exists in `lib/backend/cert_sign/`
2. Ensure it contains:
   ```
   ROOT_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----
   ...
   -----END RSA PRIVATE KEY-----"
   ```

### Verification Fails
1. Ensure server is running
2. Check that root certificate exists in Firestore at `rootCert/rootCA`
3. Verify the public key in Firestore matches server's private key

## 🎯 Key Differences from Old Code

| Old Code | New Code |
|----------|----------|
| node-forge library | Node.js native crypto |
| Complex manual verification | Simple RSASigner |
| Extensive debug logs | Clean, minimal logs |
| Compatibility issues | Standard implementation |

## 📖 Full Documentation

See `NEW_BACKEND_README.md` for complete documentation.

---

That's it! The new code should just work. ✨

