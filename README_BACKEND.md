# Certificate Backend - Clean Implementation

## Files

### Backend Server
- `lib/backend/cert_sign/index.js` - Node.js server using node-forge
- `lib/backend/cert_sign/package.json` - Dependencies (express, dotenv, node-forge)

### Dart Services  
- `lib/backend/service/cert_service.dart` - Certificate generation and verification
- `lib/backend/service/root_cert_service.dart` - Root CA and signing requests

## How It Works

### 1. Server (index.js)
- Loads ROOT_PRIVATE_KEY from environment (PEM format)
- Creates canonical JSON (sorted keys)
- Signs with RSA-SHA256 using node-forge
- Returns signature

### 2. Client (Dart)
- Creates certificate with sorted keys (SplayTreeMap)
- Sends to server for signing
- Verifies signature using RSASigner with SHA256Digest

## Deploy to Render

```bash
git add lib/backend/cert_sign/index.js
git add lib/backend/service/cert_service.dart
git add lib/backend/service/root_cert_service.dart
git commit -m "Clean backend implementation"
git push
```

Render will auto-deploy.

## Environment Setup

On Render, set environment variable:
```
ROOT_PRIVATE_KEY=-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
-----END RSA PRIVATE KEY-----
```

(Get this from Firebase rootCert/rootCA document's privateKey field)

## Build Flutter App

```bash
flutter clean
flutter pub get
flutter build apk --release
```

## Test

Generate a certificate in your app. You should see:
- Server: "Signed cert, hash: ..."
- Client: "✓ Certificate valid"

That's it!

