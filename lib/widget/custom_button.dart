import 'package:flutter/material.dart';
import '../assets/colors/color_palette.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isDisabled;
  final Color color;

  const CustomButton({
    super.key,
    required this.text,
    required this.color,
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  _CustomButtonState createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  void _handleTap() {
    if (widget.isDisabled) return;
    setState(() {
      _isPressed = true;
    });
    widget.onTap();
    Future.delayed(Duration(milliseconds: 200), () {
      setState(() {
        _isPressed = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.isDisabled ? null : _handleTap,
      borderRadius: BorderRadius.circular(10),
      splashColor: widget.isDisabled ? Colors.transparent : widget.color,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: widget.isDisabled  ? ColorPalette.gray : (_isPressed ? ColorPalette.gray : widget.color),
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: widget.isDisabled
            ? SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  strokeWidth: 3,
                ),
              )
            : Text(
          widget.text,
          style: TextStyle(
            fontFamily: 'Jersey25',
            color: widget.isDisabled ? Colors.black45 : Colors.black,
            fontSize: 25,
          ),
        ),
      ),
    );
  }
}