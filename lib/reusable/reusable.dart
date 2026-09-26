import 'package:flutter/material.dart';

/// Validates email format and returns an error message if invalid, or null if valid.
String? validateEmail(String? email) {
  if (email == null || email.trim().isEmpty) {
    return "Please enter your email address.";
  }
  final trimmed = email.trim();
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  if (!emailRegex.hasMatch(trimmed)) {
    return "Please enter a valid email address (e.g., user@example.com).";
  }
  return null;
}

/// A reusable custom text field widget designed for cinematic styling.
class CustomTextField extends StatelessWidget {
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const CustomTextField({
    this.onSuffixTap,
    this.suffixIcon,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withOpacity(0.3), // Semi-transparent dark fill
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFFE8894D)), // Warm orange
        suffixIcon: suffixIcon != null
            ? IconButton(
                icon: Icon(suffixIcon, color: Colors.white54),
                onPressed: onSuffixTap,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28), // Pill-shaped
          borderSide: const BorderSide(color: Color(0xFFE8894D), width: 1.5), // Warm orange border
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFF4A03F), width: 2), // Brighter orange when focused
        ),
      ),
    );
  }
}
