import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import './signin_screen.dart';
import '../widget/alert.dart';
import '../widget/custom_textfield.dart';

import '../assets/colors/color_palette.dart';
import '../backend/service/auth_service.dart';
import '../backend/service/phone_service.dart';
import '../widget/custom_button.dart';
import '../widget/route_trans.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final AuthService _authService = AuthService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPassController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingPhone = false;
  String? _phoneSource; // Shows where the phone number came from
  bool _autoFillAttempted = false; // Track if auto-fill was attempted
  String? _autoFillError; // Store the error message

  @override
  void initState() {
    super.initState();
    _autoFillPhoneNumber();
  }

  /// Auto-fill phone number from SIM card
  Future<void> _autoFillPhoneNumber() async {
    setState(() {
      _isLoadingPhone = true;
      _autoFillError = null;
    });

    try {
      final result = await PhoneService.getPhoneNumber();

      if (result.isSuccess && mounted) {
        setState(() {
          phoneController.text = result.phoneNumber!;
          _phoneSource = result.source;
          _autoFillError = null;
        });
      } else if (mounted) {
        setState(() {
          _autoFillError =
              result.error ?? 'Could not read phone number from SIM';
          _phoneSource = null;
        });
        print('Could not auto-fill phone: ${result.error}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _autoFillError = 'Error reading from SIM card';
          _phoneSource = null;
        });
      }
      print('Error auto-filling phone: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPhone = false;
          _autoFillAttempted = true;
        });
      }
    }
  }

  Future<void> signUp(BuildContext context) async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    final confirmPass = confirmPassController.text.trim();
    setState(() {
      _isLoading = true;
    });

    try {
      final invalidField = await _authService.signUp(
        context: context,
        email: email,
        password: password,
        name: name,
        phone: phone,
        confirmPass: confirmPass,
      );

      if (invalidField != null) {
        setState(() {
          if (invalidField == 'email') emailController.clear();
          if (invalidField == 'phone') phoneController.clear();
          if (invalidField == 'confirmPass') confirmPassController.clear();
        });
        return;
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          Navigator.of(context).pushReplacement(moveUpRoute(SignInScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      showSnackBar(context, "Sign Up failed");
      print("Sign Up error: ${e.code}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double phoneWidth = MediaQuery.of(context).size.width;
    double phoneHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Dismiss keyboard
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("lib/assets/images/bgr.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: phoneWidth / 8,
                vertical: phoneHeight / 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      phoneHeight -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      phoneHeight / 8,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          SizedBox(height: 20),
                          Image.asset(
                            "lib/assets/images/logo.png",
                            width: phoneWidth - ((phoneWidth / 8) * 6),
                            scale: 3,
                          ),
                          Align(
                            child: Text(
                              "Sign Up",
                              style: TextStyle(
                                fontFamily: 'Jersey25',
                                fontSize: 40,
                              ),
                            ),
                          ),
                          Align(
                            child: Text(
                              "Join now for free and build your network of friends and chats.",
                              style: TextStyle(
                                fontFamily: 'Gothic',
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 10),
                          CustomTextfield(
                            controller: nameController,
                            hintText: "Name",
                          ),
                          SizedBox(height: 10),
                          CustomTextfield(
                            controller: emailController,
                            hintText: "Email Address",
                          ),
                          SizedBox(height: 10),
                          Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              CustomTextfield(
                                controller: phoneController,
                                hintText:
                                    _isLoadingPhone
                                        ? "Checking SIM card..."
                                        : _autoFillAttempted &&
                                            _autoFillError != null
                                        ? "Enter your phone number"
                                        : "Phone Number",
                              ),
                              if (_isLoadingPhone)
                                Positioned(
                                  right: 12,
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        ColorPalette.darkGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_phoneSource != null && !_isLoadingPhone)
                                Positioned(
                                  right: 12,
                                  child: Tooltip(
                                    message: 'Auto-filled from $_phoneSource',
                                    child: Icon(
                                      Icons.sim_card,
                                      color: ColorPalette.darkGreen,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              if (_autoFillAttempted &&
                                  _autoFillError != null &&
                                  _phoneSource == null &&
                                  !_isLoadingPhone)
                                Positioned(
                                  right: 12,
                                  child: Tooltip(
                                    message: 'Manual entry required',
                                    child: Icon(
                                      Icons.keyboard_rounded,
                                      color: Colors.amber[700],
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (!_isLoadingPhone)
                            Padding(
                              padding: EdgeInsets.only(
                                top: 4,
                                left: 5,
                                right: 5,
                              ),
                              child:
                                  _phoneSource != null
                                      ? Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: ColorPalette.darkGreen,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Auto-filled from SIM',
                                            style: TextStyle(
                                              fontFamily: 'Gothic',
                                              fontSize: 11,
                                              color: ColorPalette.darkGreen,
                                            ),
                                          ),
                                        ],
                                      )
                                      : _autoFillAttempted &&
                                          _autoFillError != null
                                      ? Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.amber.withValues(
                                              alpha: 0.4,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_note_rounded,
                                              size: 20,
                                              color: Colors.amber[800],
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Please enter your phone number',
                                                    style: TextStyle(
                                                      fontFamily: 'Gothic',
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.amber[900],
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'SIM auto-detect unavailable on this device',
                                                    style: TextStyle(
                                                      fontFamily: 'Gothic',
                                                      fontSize: 10,
                                                      color: Colors.amber[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: _autoFillPhoneNumber,
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                child: Icon(
                                                  Icons.refresh_rounded,
                                                  size: 18,
                                                  color: Colors.amber[800],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : GestureDetector(
                                        onTap: _autoFillPhoneNumber,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.sim_card_outlined,
                                              size: 14,
                                              color: const Color.fromARGB(
                                                255,
                                                100,
                                                100,
                                                100,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Tap to auto-fill from SIM',
                                              style: TextStyle(
                                                fontFamily: 'Gothic',
                                                fontSize: 11,
                                                color: const Color.fromARGB(
                                                  255,
                                                  100,
                                                  100,
                                                  100,
                                                ),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                            ),
                          SizedBox(height: 10),
                          CustomTextfield(
                            controller: passwordController,
                            hintText: "Password",
                            obscureText: true,
                          ),
                          SizedBox(height: 10),
                          CustomTextfield(
                            controller: confirmPassController,
                            hintText: "Confirm Password",
                            obscureText: true,
                          ),
                        ],
                      ),
                      SizedBox(height: 30),
                      Padding(
                        padding: EdgeInsets.only(top: 20, bottom: 20),
                        child: Column(
                          children: [
                            CustomButton(
                              text: "Sign Up",
                              onTap: () => signUp(context),
                              color: ColorPalette.lightGreen,
                              isDisabled: _isLoading,
                            ),
                            SizedBox(height: 7),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "Already have an account? ",
                                    style: TextStyle(
                                      fontFamily: 'Jersey25',
                                      fontSize: 17,
                                      color: ColorPalette.lightGreen,
                                    ),
                                  ),
                                  TextSpan(
                                    text: "Sign In",
                                    style: TextStyle(
                                      fontFamily: 'Jersey25',
                                      fontSize: 19,
                                      color: Colors.white,
                                    ),
                                    recognizer:
                                        TapGestureRecognizer()
                                          ..onTap = () {
                                            Navigator.of(
                                              context,
                                            ).push(fadeRoute(SignInScreen()));
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
