import 'package:flutter/material.dart';

class CustomTextfield extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final double height;

  const CustomTextfield({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Align(
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          cursorColor: Colors.black,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(fontFamily: obscureText == true ? null : 'Gothic',fontSize: 13, color: Colors.black),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black54)
            ),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black,width: 1.5)
            ),
            hintText: hintText,
            hintStyle: TextStyle(fontFamily: 'Gothic',fontSize: 13, color: Colors.black54),
          ),
        ),
      ),
    );
  }
}