# 🔍 Firestore Root Certificate Checklist

## What I Fixed

1. ✅ **Updated signMessage** - Now uses `RSASigner` with PKCS#1 v1.5
2. ✅ **Improved root cert query** - Orders by `issuedAt` descending to get the latest root certificate
3. ✅ **Updated verifyUserCert** - Uses `RSASigner` for verification
4. ✅ **Updated verifyUserSignature** - Uses `RSASigner` for verification
5. ✅ **Better error handling** - More detailed logging

## Check Your Firestore Structure

### 1. Open Firebase Console
Go to: Firestore Database → `rootCert` collection

### 2. Verify Document Structure

Your root certificate document should look like this:

```
rootCert (collection)
  └─ [document-id] (auto-generated)
      ├─ rootCertId: "[document-id]"
      ├─ issuedAt: "2025-11-30T..."
      ├─ expiresAt: "2035-11-30T..."
      ├─ privateKey: "base64string..." (optional)
      └─ rootCertData: {
           ├─ version: 3
           ├─ serialNumber: "..."
           ├─ signatureAlgorithm: "SHA256withRSA"
           ├─ issuer: "Nodity CA"
           ├─ subject: "Nodity CA"
           ├─ publicKey: "MIIBCgKCAQEA..." ← THIS IS CRITICAL
           ├─ issuedAt: "2025-11-30T..."
           └─ expiresAt: "2035-11-30T..."
         }
```

### 3. Critical Fields to Check

✅ **`issuedAt`** field exists at root level (for ordering query)
✅ **`rootCertData.publicKey`** exists and is a base64-encoded string
✅ Only ONE root certificate exists (or the latest one is what you want to use)

## Common Issues

### Issue 1: Missing `issuedAt` at root level

**Symptom:** Error about ordering by `issuedAt`

**Fix:** 
- Make sure `issuedAt` is a field at the root of the document (not just inside `rootCertData`)
- It should be a Firestore Timestamp or ISO date string

### Issue 2: Wrong Public Key

**Symptom:** 
```
Server root modulus: b8504a152ba434...
Client root modulus: cef4b531e6b5f0...  ← DIFFERENT!
Certificate verification result: false
```

**Fix:** 
The `rootCertData.publicKey` in Firestore must match your backend's private key. See below for how to sync.

### Issue 3: Multiple Root Certificates

**Symptom:** Getting wrong certificate

**Fix:**
- The query now gets the LATEST certificate (newest `issuedAt`)
- If you have multiple, either delete old ones or ensure the latest is correct

## How to Sync Keys (If Modulus Doesn't Match)

### Quick Check Script

```bash
cd lib/backend/cert_sign
node -e "
const forge = require('node-forge');
require('dotenv').config();
const key = forge.pki.privateKeyFromPem(process.env.ROOT_PRIVATE_KEY);
console.log('Server modulus (first 50 chars):');
console.log(key.n.toString(16).slice(0, 50));
"
```

### If Modulus Doesn't Match:

**Option 1: Update Firestore to match backend**
1. Extract public key from your backend private key
2. Update `rootCertData.publicKey` in Firestore

**Option 2: Update backend to match Firestore**
1. Use the root certificate that's in Firestore
2. Get its private key (if stored)
3. Update backend `.env` with that private key

**Option 3: Generate new keys everywhere**
```dart
// In Flutter, run ONCE:
await RootCertService.generateRootCert();

// Then extract the private key from Firestore
// And update your backend's .env file
```

## Test After Fixing

Run your app and look for these logs:

```
✅ Root cert document ID: [some-id]
✅ Client root modulus hex: [same as server]
✅ Certificate verification result: true
✅ Signature verification result: true
```

## Debugging Logs

The updated code now prints:
- Root certificate document ID
- Whether root cert structure is valid
- More detailed error messages

Check your console for:
```
Root cert document ID: abc123...
Client root modulus bitLength: 2048
Client root modulus hex: cef4b531e6b5f0ce...
```

Compare this with your backend logs:
```
Server root modulus hex: cef4b531e6b5f0ce...  ← Should be IDENTICAL
```

## Need to Regenerate Root Certificate?

If you need to create a new root certificate:

```dart
import 'package:Nodity/backend/service/root_cert_service.dart';

// Run ONCE to generate new root certificate
await RootCertService.generateRootCert();
print('Root certificate generated!');
```

This will:
1. Generate new RSA key pair (2048-bit)
2. Create root certificate
3. Store in Firestore with proper structure
4. Store private key (for backup)

**⚠️ After regenerating:**
- All user certificates become invalid
- Update backend's private key to match
- Users must regenerate their certificates

---

## Summary

The code is now:
- ✅ Using proper RSASigner for signing/verification
- ✅ Querying root cert with proper ordering
- ✅ Better error handling and logging
- ✅ More robust structure validation

**Next:** Check your Firestore structure matches the format above!

