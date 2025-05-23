import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:Nodity/assets/colors/color_palette.dart';
import 'package:Nodity/frontend/signin_screen.dart';
import 'package:Nodity/frontend/signup_screen.dart';
import 'package:Nodity/widget/custom_button.dart';

import '../widget/route_trans.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});


  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends  State<WelcomeScreen>{
  @override
  Widget build(BuildContext context) {
    double phoneWidth = MediaQuery.of(context).size.width;
    double phoneHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
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
                  SizedBox(height: phoneHeight/8),
                  Image.asset("lib/assets/images/logo.png",
                    width: phoneWidth - ((phoneWidth/8)*3),
                  ),
                  Align(
                    child: Text(
                      "WELCOME",
                      style: TextStyle(
                          fontFamily: 'Jersey25',
                          fontSize: 40
                      ),
                    ),
                  )
                ]
              ),
              Column(
                children: [
                  CustomButton(
                      text: "Login",
                      onTap: (){
                        Navigator.of(context).push(
                            fadeRoute(
                                SignInScreen()
                            )
                        );
                      },
                      color: ColorPalette.lightGreen
                  ),
                  SizedBox(height: 7),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(
                              fontFamily: 'Jersey25',
                              fontSize: 17,
                              color: ColorPalette.lightGreen
                          )
                        ),
                        TextSpan(
                          text: "Sign Up",
                          style: TextStyle(
                              fontFamily: 'Jersey25',
                              fontSize: 19,
                              color: Colors.white
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.of(context).pushReplacement(
                                  fadeRoute(
                                      SignUpScreen()
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
    );
  }
}