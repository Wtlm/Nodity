import 'package:Nodity/frontend/signup_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import '../model/user.dart';
import './conversation_service.dart';
import '../../widget/alert.dart';
import 'cert_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final CertService _certService = CertService();
  final ConversationService _conversationService = ConversationService();
  final secureStorage = FlutterSecureStorage();

  bool isEmail(String input) {
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegExp.hasMatch(input);
  }

  bool isPhone(String input) {
    final phoneRegExp = RegExp(r'^\+?[0-9]{9,15}$');
    return phoneRegExp.hasMatch(input);
  }

  Future<bool> isPhoneExist(String phone) async {
    final querySnapshot =
        await _db
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

    return querySnapshot.docs.isNotEmpty;
  }

  Future<String?> signUp({
    required BuildContext context,
    required String email,
    required String password,
    required String name,
    required String phone,
    required String confirmPass,
  }) async {
    bool phoneExists = await isPhoneExist(phone);
    if (!isEmail(email)) {
      showSnackBar(context, "Invalid email format");
      return 'email';
    }
    if (!isPhone(phone)) {
      showSnackBar(context, "Invalid phone format");
      return 'phone';
    }
    if (phoneExists) {
      showSnackBar(context, "Phone number already exists.");
      return 'phone';
    }
    if (password != confirmPass) {
      showSnackBar(context, "Confirm password does not match.");
      return 'confirmPass';
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      final certId = await _certService.generateCert(user.uid, password);
      if (certId.isEmpty) {
        showSnackBar(context, "Failed to generate certificate");
        return null;
      }

      print("UID: ${user.uid}");
      print("Email: ${user.email}");
      print("Phone: $phone");
      print("Cert ID: $certId");

      final newUser = Users(
        userId: user.uid,
        name: name,
        email: user.email ?? '',
        phone: phone,
        certId: certId,
        photoUrl: "",
      );
      try {
        await _db.collection('users').doc(user.uid).set(newUser.toMap());
      } catch (e, stack) {
        print("Firestore write failed: $e");
        print(stack);
      }
      await _conversationService.createChatRoom(user.uid);

      showSnackBar(context, "Create account successful", success: true);
    } catch (e, stack) {
      print('Firestore error: $e');
      print(stack);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.delete();
          print('User deleted from Firebase Auth due to Firestore failure.');
        } catch (deleteError) {
          print('Failed to delete user from Auth: $deleteError');
        }
      }
      showSnackBar(context, "Error during sign up");
    }
    return null;
  }

  Future<bool> signIn(
    BuildContext context,
    String input,
    String password,
  ) async {
    try {
      String? emailToUse;

      if (isEmail(input)) {
        // If it's an email, use directly
        emailToUse = input;
      } else if (isPhone(input)) {
        // If it's a phone number, query Firestore to find linked email
        final query =
            await _db
                .collection('users')
                .where('phone', isEqualTo: input)
                .limit(1)
                .get();

        if (query.docs.isEmpty) {
          showSnackBar(context, "Phone number not registered");
          return false;
        }

        final userData = query.docs.first.data();
        // if (userData['password'] != password) {
        //   showSnackBar(context, "Incorrect password");
        //   return false;
        // }

        emailToUse = userData['email'];
      } else {
        showSnackBar(context, "Invalid input format");
        return false;
      }

      // Proceed to sign in with email & password
      await _auth.signInWithEmailAndPassword(
        email: emailToUse!,
        password: password,
      );

      final user = FirebaseAuth.instance.currentUser!;
      final hasKey = await isPrivateKeyStored(user.uid);

      if (!hasKey) {
        try {
          await _certService.fetchAndStorePrivateKey(user.uid, password);
          print("Private key recovered and stored securely.");
        } catch (e) {
          print("Failed to recover private key: $e");
          showSnackBar(context, "Failed to restore credentials.");
          return false;
        }
      }

      showSnackBar(context, "Sign in successful", success: true);
      return true;
    } catch (e) {
      showSnackBar(context, "Sign in fail");
      return false;
    }
  }

  Future<bool> isPrivateKeyStored(String userId) async {
    final key = await secureStorage.read(key: 'private_key_$userId');
    return key != null;
  }
}
