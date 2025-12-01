# Deploy to Render

## Step 1: Push Code

```powershell
cd D:\Thesis\Nodity

git add lib/backend/cert_sign/index.js
git add lib/backend/service/cert_service.dart  
git add lib/backend/service/root_cert_service.dart

git commit -m "Fresh backend implementation"

git push
```

Render will automatically deploy in 2-3 minutes.

## Step 2: Build Flutter App

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

## Step 3: Test

Install APK and test certificate operations.

Expected output:
- ✓ Certificate valid

Done!

