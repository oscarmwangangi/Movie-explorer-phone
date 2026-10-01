import 'package:flutter/material.dart';
import 'package:movie_explorer/reusable/reusable.dart';
import '../api/api_service.dart';
import '../subscription/subscription_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static String id = 'register_screen';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool obscureText = true;

  bool isLoading = false;
  String? errorMessage;

  Future<void> _handleRegister() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    final emailError = validateEmail(email);
    if (emailError != null) {
      setState(() => errorMessage = emailError);
      return;
    }

    if (password.isEmpty) {
      setState(() => errorMessage = "Please enter a password.");
      return;
    }

    if (password.length < 6) {
      setState(() => errorMessage = "Password must be at least 6 characters long.");
      return;
    }

    if (password != confirmPassword) {
      setState(() => errorMessage = "Passwords do not match.");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final error = await ApiService.register(email, password);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        isLoading = false;
        errorMessage = error;
      });
      return;
    }

    Navigator.pushReplacementNamed(context, SubscriptionScreen.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              color: const Color(0xFF121212),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.movie_filter_outlined,
                        size: 80,
                        color: Color(0xFFFF8C42),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'JOIN US',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create your account to start exploring',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 48),

                      CustomTextField(
                        controller: emailController,
                        hintText: "Email",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: passwordController,
                        hintText: "Password",
                        icon: Icons.lock_outline,
                        obscureText: obscureText,
                        textInputAction: TextInputAction.next,
                        suffixIcon: obscureText ? Icons.visibility_off : Icons.visibility,
                        onSuffixTap: () => setState(() => obscureText = !obscureText),
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: confirmPasswordController,
                        hintText: "Confirm Password",
                        icon: Icons.lock_clock_outlined,
                        obscureText: obscureText,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleRegister(),
                      ),
                      const SizedBox(height: 32),

                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B2E1F), Color(0xF4A03F)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B2E1F).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'SIGN UP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? ", style: TextStyle(color: Colors.white70)),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
