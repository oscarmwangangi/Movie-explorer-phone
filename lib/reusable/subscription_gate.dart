import 'package:flutter/material.dart';
import 'package:movie_explorer/api/api_service.dart';
import 'package:movie_explorer/authentication/login.dart';
import 'package:movie_explorer/subscription/subscription_screen.dart';
import 'package:movie_explorer/theme/app_colors.dart';

/// A wrapper widget that checks the user's subscription status.
/// If the status is not 'active', it redirects the user to the
/// SubscriptionScreen.
class SubscriptionGate extends StatefulWidget {
  final Widget child;
  const SubscriptionGate({super.key, required this.child});

  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate> {
  bool _isLoading = true;
  bool _hasAccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subscription = await ApiService.getMySubscription();

      // The backend returns a JSON object. We check the 'status' field.
      // Expected statuses: 'active', 'pending', 'expired', 'cancelled'.
      final status = subscription['status']?.toString();

      if (status == 'active') {
        if (mounted) {
          setState(() {
            _hasAccess = true;
            _isLoading = false;
          });
        }
      } else {
        // Redirect to subscription screen if status is NOT active
        // (covers pending, expired, cancelled, or missing).
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            SubscriptionScreen.id,
            (route) => false,
          );
        }
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      // If it's a network/timeout error, stay on this screen and show an error UI.
      // This prevents the "refresh loop" redirect between Login and Home.
      if (errorStr.contains('network') || 
          errorStr.contains('socket') || 
          errorStr.contains('timeout') || 
          errorStr.contains('connection')) {
        if (mounted) {
          setState(() {
            _errorMessage = "No internet connection. Please check your network and try again.";
            _isLoading = false;
          });
        }
      } else {
        // If there's an auth error (like 401 Unauthorized),
        // we redirect to the login screen as a fallback.
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            LoginScreen.id,
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 80, color: AppColors.textMuted),
                const SizedBox(height: 24),
                const Text(
                  "Connection Lost",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 220,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _checkSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      "RETRY",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () async {
                    await ApiService.logout();
                    if (mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        LoginScreen.id,
                        (route) => false,
                      );
                    }
                  },
                  child: const Text(
                    "Back to Login",
                    style: TextStyle(
                      color: AppColors.textMuted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _hasAccess ? widget.child : const SizedBox.shrink();
  }
}
