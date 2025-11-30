# ✅ Final Fix - Using Specific Document ID

## What Was Fixed

You were **absolutely correct**! The root certificate should use a specific document ID `'rootCA'` instead of querying with `.limit(1)`.

### Changes Made:

1. ✅ **cert_service.dart** - Now fetches root cert by document ID:
   ```dart
   final rootDoc = await _db.collection('rootCert').doc('rootCA').get();
   ```

2. ✅ **root_cert_service.dart** - Now creates root cert with fixed ID:
   ```dart
   final rootCertDoc = FirebaseFirestore.instance.collection('rootCert').doc('rootCA');
   ```

3. ✅ **All signing/verification methods** - Now use `RSASigner` for compatibility with Node.js backend

---

## 🎯 What You Need to Do

### Step 1: Make Sure Your Firestore Has the Right Structure

Your Firestore should have:
```
rootCert (collection)
  └─ rootCA (document) ← Must be exactly "rootCA"
      ├─ rootCertId: "rootCA"
      ├─ issuedAt: "2025-11-30T..."
      ├─ expiresAt: "2035-11-30T..."
      └─ rootCertData: {
           ├─ version: 3
           ├─ serialNumber: "rootCA"
           ├─ signatureAlgorithm: "SHA256withRSA"
           ├─ issuer: "Nodity CA"
           ├─ subject: "Nodity CA"
           ├─ publicKey: "MIIBCgKCAQEA..." ← MUST match your backend
           ├─ issuedAt: "2025-11-30T..."
           └─ expiresAt: "2035-11-30T..."
         }
```

### Step 2: Check If Document Exists

Go to Firebase Console → Firestore → `rootCert` collection

**If you DON'T have a document called `rootCA`**, you have two options:

#### Option A: Rename Your Existing Document
1. Note the existing document ID
2. Create a new document with ID `rootCA`
3. Copy all data from the old document
4. Delete the old document

#### Option B: Generate New Root Certificate
```dart
import 'package:Nodity/backend/service/root_cert_service.dart';

// This will create rootCert/rootCA with new keys
await RootCertService.generateRootCert();
```

**⚠️ WARNING:** If you generate new keys, you MUST:
1. Extract the private key from Firestore
2. Update your backend's `.env` file with the new private key
3. Regenerate all user certificates

### Step 3: Verify Keys Match

After ensuring the document exists, compare the keys:

**In Flutter logs:**
```
Client root modulus hex: b8504a152ba434c1d01c3b77737112da...
```

**In Backend logs:**
```
Server root modulus hex: b8504a152ba434c1d01c3b77737112da...
```

**These MUST be identical!**

---

## 🔧 How to Sync Keys (If They Don't Match)

### Quick Way: Update Firestore Public Key

1. **Extract public key from your backend:**

Create `extract_key.js`:
```javascript
const forge = require('node-forge');
require('dotenv').config();

const privateKey = forge.pki.privateKeyFromPem(process.env.ROOT_PRIVATE_KEY);
const publicKey = forge.pki.setRsaPublicKey(privateKey.n, privateKey.e);
const publicKeyDer = forge.asn1.toDer(forge.pki.publicKeyToAsn1(publicKey)).getBytes();
const publicKeyBase64 = forge.util.encode64(publicKeyDer);

console.log('Public Key (Base64):');
console.log(publicKeyBase64);
console.log('\nModulus (hex):');
console.log(privateKey.n.toString(16).slice(0, 100));
```

Run it:
```bash
cd lib/backend/cert_sign
node extract_key.js
```

2. **Update Firestore:**
   - Go to Firebase Console → Firestore
   - Navigate to `rootCert` → `rootCA`
   - Update `rootCertData.publicKey` with the Base64 value from step 1

3. **Regenerate user certificates** (old ones won't verify anymore)

---

## ✅ Testing

After the fix, run your app and check the logs:

```
✅ Certificate verification result: true
✅ Signature verification result: true
```

And compare modulus:
```
Server root modulus hex: b8504a152ba434...
Client root modulus hex: b8504a152ba434...  ← SAME!
```

---

## 📝 Summary

**Before:**
```dart
// Could get any random document
final rootSnap = await _db.collection('rootCert').limit(1).get();
final data = rootSnap.docs.first.data();
```

**After:**
```dart
// Gets specific document 'rootCA'
final rootDoc = await _db.collection('rootCert').doc('rootCA').get();
final data = rootDoc.data();
```

**Benefits:**
- ✅ Always gets the correct root certificate
- ✅ No confusion with multiple documents
- ✅ Clear and explicit
- ✅ Faster (direct document access vs query)

---

## 🎯 Next Steps

1. Check Firestore has document `rootCert/rootCA`
2. Verify the public key matches your backend
3. Test certificate generation
4. Test message signing
5. Verify all operations return `true`

**Your code should now work correctly!** 🚀

