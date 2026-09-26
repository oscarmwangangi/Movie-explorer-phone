import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_explorer/reusable/reusable.dart';
import 'forgot_password.dart';
import '../appUI/home/home.dart';
import '../api/api_service.dart';
import 'register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static String id = 'login_screen';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscureText = true;
  bool rememberMe = false;

  // Controllers read whatever the user typed into the text fields.
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
    _loadRememberedCredentials();
  }

  Future<void> _checkAutoLogin() async {
    final token = await ApiService.getToken();
    if (token != null && mounted) {
      Navigator.pushReplacementNamed(context, HomeScreen.id);
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      rememberMe = prefs.getBool('remember_me') ?? false;
      if (rememberMe) {
        emailController.text = prefs.getString('remembered_email') ?? '';
        passwordController.text = prefs.getString('remembered_password') ?? '';
      }
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;

    final error = await ApiService.login(email, password);

    if (!mounted) return; // screen was closed while we were waiting

    if (error != null) {
      setState(() {
        isLoading = false;
        errorMessage = error;
      });
      return;
    }

    // Save or clear remembered credentials
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', rememberMe);
    if (rememberMe) {
      await prefs.setString('remembered_email', email);
      await prefs.setString('remembered_password', password);
    } else {
      await prefs.remove('remembered_email');
      await prefs.remove('remembered_password');
    }

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, HomeScreen.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image with Scrim
          Positioned.fill(
            child: Image.asset(
              'images/view-urban-dark-city-with-fog.jpg',
              fit: BoxFit.cover,
              // The bundled asset for this background is missing from the
              // images/ folder; fall back to a plain dark gradient instead
              // of crashing the login screen.
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF121212),
              ),
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

          // 2. Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo with Glow
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8C42).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFF8C42), Color(0xFFE85D25)],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.movie_creation_outlined, // Film reel/clapperboard icon
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // App Name with Gradient
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF8C42), Color(0xFFE85D25)],
                      ).createShader(bounds),
                      child: const Text(
                        'MOVIE EXPLORER',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.0,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Email Field
                    CustomTextField(
                      controller: emailController,
                      hintText: "Email",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 24),

                    // Password Field
                    CustomTextField(
                      controller: passwordController,
                      hintText: "Password",
                      icon: Icons.lock_outline,
                      obscureText: obscureText,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                      suffixIcon: obscureText ? Icons.visibility_off : Icons.visibility,
                      onSuffixTap: () {
                        setState(() {
                          obscureText = !obscureText;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Remember Me Checkbox
                    Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor: Colors.white70,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: rememberMe,
                              activeColor: const Color(0xFFFF8C42),
                              checkColor: Colors.white,
                              onChanged: (value) {
                                setState(() {
                                  rememberMe = value ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Remember Me',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Gradient Login Button
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
                        onPressed: isLoading ? null : _handleLogin,
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
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'LOGIN',
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

                    const SizedBox(height: 24),

                    // Footer Links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, ForgotPasswordScreen.id);
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, RegisterScreen.id);
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
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
