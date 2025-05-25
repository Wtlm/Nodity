import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:Nodity/backend/model/user.dart';
import 'package:Nodity/backend/service/conversation_service.dart';
import '../../widget/alert.dart';
import 'cert_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final CertService _certService = CertService();
  final ConversationService _conversationService = ConversationService();
  // final BuildContext context;
  //
  // AuthService(this.context);

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

  Future<void> signUp({
    required BuildContext context,
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    bool phoneExists = await isPhoneExist(phone);
    if (!isEmail(email)) {
      showSnackBar(context, "Invalid email format");
      return;
    }
    if (!isPhone(phone)) {
      showSnackBar(context, "Invalid phone format");
      return;
    }
    if (phoneExists) {
      showSnackBar(context, "Phone number already exists.");
      return;
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      final certId = await _certService.generateCert(user.uid);
      if (certId == null) {
        throw Exception('Certificate generation failed');
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

      showSnackBar(context, "Sign in successful", success: true);
      return true;
    } catch (e) {
      showSnackBar(context, "Sign in fail");
      return false;
    }
  }
}
