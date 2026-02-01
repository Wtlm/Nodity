# Nodity – Secure Messaging App, Verified Identity

**Nodity** is a mobile messaging app focused on security and authenticity. It ensures every message you send or receive is verifiably linked to a real identity using a certificate-based verification system. Ideal for users who value privacy and trust in communication.

---

## 💡 Why "Nodity"?

"Nodity" is a blend of "Nod" (a subtle gesture of trust) and "Identity".  
The name reflects our goal: secure communication where every message comes from a **verified identity**.

---

## 🔐 Key Features

- **Certificate-Based Identity Verification**  
  Each user is issued a unique digital certificate at signup to verify their identity.

- **Secure Messaging**  
  Messages are signed using private keys and verified using public keys embedded in certificates.

- **Real-Time Chat**  
  Enjoy fast, responsive messaging with Firebase-backed real-time chat support.

- **Dual Authentication**  
  Sign in using either email or phone number for flexible and user-friendly access.

- **Modern UI/UX**  
  A clean and intuitive interface built with Flutter, offering a smooth messaging experience.

---

## 📱 Tech Stack

- **Flutter** – Cross-platform UI toolkit  
- **Firebase Auth & Firestore** – Authentication and real-time database  
- **RSA Cryptography** – For digital certificates and secure message verification  
- **End-to-End Encryption (planned)** – Encrypt message contents to ensure privacy even from the server

---

## 📥 Download the App

### Android

**Option 1: Direct Download**

[**Download Nodity APK**](https://github.com/Wtlm/Nodity/raw/refs/heads/SMS_test/qr_app/android/app/src/output_app/app-release.apk)

**Option 2: Scan QR Code**

Scan the QR code below with your phone's camera to download the app:

<p align="center">
  <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://github.com/Wtlm/Nodity/raw/refs/heads/SMS_test/qr_app/android/app/src/output_app/app-release.apk" alt="Download QR Code" />
</p>

### Installation Instructions

1. **Download** the APK file using one of the methods above
2. **Enable Unknown Sources** (if prompted):
   - Go to **Settings** > **Security** (or **Privacy**)
   - Enable **Install unknown apps** for your browser or file manager
   - For **Play Protect**: CH Play > Play Protect > Setting > Turn off **Scan apps with Play Protect**
3. **Open** the downloaded APK file
4. **Tap Install** and wait for the installation to complete
5. **Open** Nodity and enjoy secure messaging!

> **Note:** Since this app is not from the Play Store, Android may show a security warning. This is normal for apps distributed outside official stores. Tap "Install anyway" to proceed.


## 🔧 For Developers

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.7.2+)
- [Android Studio](https://developer.android.com/studio) with Android SDK
- Java JDK 11

Run `flutter doctor` to verify your setup.

---

### Run the Project

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

### Build APK

```bash
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```
