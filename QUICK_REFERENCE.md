# 🚀 Quick Reference

## What Changed

✅ Root certificate now uses specific document ID: `rootCert/rootCA`
✅ All signing/verification uses `RSASigner` (compatible with Node.js)

---

## Required Firestore Structure

```
rootCert/
  └─ rootCA/           ← Document ID must be "rootCA"
      ├─ rootCertData/
      │   └─ publicKey  ← Must match backend's private key
      └─ issuedAt
```

---

## Check Your Setup

### 1. Firestore Document Exists?
Firebase Console → Firestore → `rootCert` → Should see document named `rootCA`

### 2. Keys Match?
Compare these in your logs:
- Backend: `Server root modulus hex: abc123...`
- Flutter: `Client root modulus hex: abc123...`

Must be **identical**!

---

## If Document Missing

### Generate New Root Cert:
```dart
await RootCertService.generateRootCert();
// Creates rootCert/rootCA in Firestore
```

**Then update backend `.env` with the new private key from Firestore!**

---

## If Keys Don't Match

### Option 1: Update Firestore (Easier)
1. Extract public key from backend
2. Update `rootCert/rootCA/rootCertData/publicKey` in Firestore

### Option 2: Update Backend
1. Get private key from Firestore `rootCert/rootCA/privateKey`
2. Update backend `.env` file

---

## Test It Works

Run your app, should see:
```
✅ Client root modulus hex: [same as server]
✅ Certificate verification result: true
✅ Signature verification result: true
```

---

## Files Modified

- `cert_service.dart` - Uses `.doc('rootCA').get()`
- `root_cert_service.dart` - Creates `.doc('rootCA')`
- Both now use `RSASigner` for signing/verification

---

**That's it! Your setup should now work correctly.** 🎉

