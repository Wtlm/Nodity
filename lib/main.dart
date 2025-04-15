import 'package:flutter/material.dart';

import 'fontend/message_list.dart';
import 'fontend/signin_screen.dart';
import 'fontend/signup_screen.dart';
import 'fontend/welcome_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WelcomeScreen(),
    );
  }
}
