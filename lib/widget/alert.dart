import 'package:flutter/material.dart';

void showSnackBar(BuildContext context, String message, {bool success = false}) {
  final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  if (scaffoldMessenger != null) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Gothic',
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  } else {
    // fallback (not recommended but avoids crashing)
    debugPrint('ScaffoldMessenger not found in context. SnackBar: $message');
  }
}
