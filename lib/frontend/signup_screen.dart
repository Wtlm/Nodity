import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:Nodity/frontend/signin_screen.dart';
import 'package:Nodity/widget/alert.dart';
import 'package:Nodity/widget/custom_textfield.dart';

import '../assets/colors/color_palette.dart';
import '../backend/service/auth_service.dart';
import '../widget/custom_button.dart';
import '../widget/route_trans.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>{
  late final AuthService _authService = AuthService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> signUp(BuildContext context) async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    setState(() => _isLoading = true);

    try {
      await _authService.signUp(
        context: context,
        email: email,
        password: password,
        name: name,
        phone: phone,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.of(context).pushReplacement(
          moveUpRoute(
            SignInScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      showSnackBar(context, "Sign Up failed");
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
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("lib/assets/images/bgr.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: phoneWidth/8, vertical: phoneHeight/8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                    children: [
                      SizedBox(height: 20),
                      Image.asset("lib/assets/images/logo.png",
                        width: phoneWidth - ((phoneWidth/8)*6),
                        scale: 3,
                      ),
                      Align(
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                              fontFamily: 'Jersey25',
                              fontSize: 40
                          ),
                        ),
                      ),
                      Align(
                        child: Text(
                          "Join now for free and build your network of friends and chats.",
                          style: TextStyle(
                              fontFamily: 'Gothic',
                              fontSize: 13
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 20,),
                      CustomTextfield(controller: nameController, hintText: "Name"),
                      SizedBox(height: 20,),
                      CustomTextfield(controller: emailController, hintText: "Email Address"),
                      SizedBox(height: 20,),
                      CustomTextfield(controller: phoneController, hintText: "Phone Number"),
                      SizedBox(height: 20,),
                      CustomTextfield(controller: passwordController, hintText: "Password", obscureText: true),
                    ]
                ),
                Column(
                    children: [
                      CustomButton(
                          text: "Sign Up",
                          onTap: () => signUp(context),
                          color: ColorPalette.lightGreen
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
                                      color: ColorPalette.lightGreen
                                  )
                              ),
                              TextSpan(
                                text: "Sign In",
                                style: TextStyle(
                                    fontFamily: 'Jersey25',
                                    fontSize: 19,
                                    color: Colors.white
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(context).push(
                                        fadeRoute(
                                          SignInScreen()
                                        )
                                    );
                                  },
                              ),
                            ]
                        ),
                      )                ]
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}