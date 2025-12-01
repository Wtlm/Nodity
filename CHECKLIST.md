# ✅ Pre-Flight Checklist

## Before You Start

### Server Setup
- [ ] Node.js is installed (`node --version`)
- [ ] You're in the correct directory (`D:\Thesis\Nodity\lib\backend\cert_sign`)
- [ ] `.env` file exists in that directory
- [ ] `.env` contains `ROOT_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----..."`
- [ ] Dependencies installed (`npm install`)

### Firebase Setup
- [ ] Root certificate exists at `rootCert/rootCA` in Firestore
- [ ] Public key in Firestore matches private key in `.env`

### Flutter Setup
- [ ] Flutter is installed (`flutter --version`)
- [ ] You're in project root (`D:\Thesis\Nodity`)
- [ ] Dependencies installed (`flutter pub get`)

---

## Start Testing

### Step 1: Start Server
```bash
cd D:\Thesis\Nodity\lib\backend\cert_sign
node index.js
```

**Expected Output:**
```
✓ Server started successfully
✓ Private key loaded from environment
🚀 Certificate signing server running on port 3000
```

- [ ] Server started without errors
- [ ] You see the ✓ symbols

### Step 2: Build App
```bash
cd D:\Thesis\Nodity
flutter build apk --release
```

- [ ] Build completed without errors
- [ ] APK created at `build\app\outputs\flutter-apk\app-release.apk`

### Step 3: Install & Run
- [ ] APK installed on device
- [ ] App launches without crashes

### Step 4: Test Certificate Operations
- [ ] Generate a certificate → Success
- [ ] Verify a certificate → Shows ✓ VALID
- [ ] Sign a message → Success
- [ ] Verify a signature → Success

---

## If Something Fails

### Server won't start
```
✗ ROOT_PRIVATE_KEY not found
```
→ Check `.env` file exists and has the correct format

### Verification fails
```
Verification result: ✗ INVALID
```
→ Check these in order:
1. Is server running?
2. Does root cert exist at `rootCert/rootCA`?
3. Does public key match private key?
4. Are the hashes the same on client and server?

### Build fails
```
Error: ...
```
→ Try:
1. `flutter clean`
2. `flutter pub get`
3. `flutter build apk --release` again

---

## Success Indicators

### You'll Know It Works When:

**Server logs show:**
```
=== SIGNING REQUEST ===
Canonical JSON: {...}
SHA-256 hash: [some hash]
Self-verification: ✓ SUCCESS
=== END SIGNING ===
```

**Client logs show:**
```
=== CERTIFICATE VERIFICATION ===
Certificate ID: [some id]
SHA-256 hash: [same hash as server]
Verification result: ✓ VALID
=== END VERIFICATION ===
```

**Key point:** The SHA-256 hash should be the **same** on both server and client!

---

## Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Server won't start | Check `.env` file |
| "Root cert not found" | Generate root cert first |
| Verification fails | Check key mismatch |
| Hash mismatch | Check canonical JSON encoding |
| Network error | Check backend URL in `root_cert_service.dart` |

---

## Documentation Quick Links

- 🚀 **Get started fast:** `QUICK_START.md`
- 📖 **Full documentation:** `NEW_BACKEND_README.md`
- 🔄 **What changed:** `WHAT_CHANGED.md`
- 📍 **You are here:** `CHECKLIST.md`

---

## Support

If you're stuck:
1. Check the error message carefully
2. Look for ✗ symbols in logs
3. Compare client and server hashes
4. Read the troubleshooting section in `NEW_BACKEND_README.md`

The new code is designed to give clear error messages. If something fails, the logs will tell you exactly what went wrong!

---

**Good luck! The new code should work much better than the old one.** 🎉

