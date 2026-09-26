import 'package:flutter/material.dart';
import 'package:movie_explorer/appUI/home/home.dart';
import 'package:movie_explorer/authentication/login.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_service.dart';

/// Shown when a user needs to subscribe (or their subscription has
/// expired). Lets them pick Monthly ($1) or Yearly ($10) and sends
/// them to PayPal to pay.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  static String id = 'subscription_screen';

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with WidgetsBindingObserver {
  bool isLoading = false;
  String? errorMessage;
  String? _currentStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user comes back to the app from the browser/PayPal
    if (state == AppLifecycleState.resumed) {
      _checkInitialStatus();
    }
  }

  Future<void> _checkInitialStatus() async {
    setState(() => isLoading = true);
    try {
      final sub = await ApiService.getMySubscription();
      final status = sub['status']?.toString();
      _currentStatus = status;

      if (status == 'active') {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, HomeScreen.id, (route) => false);
        }
      }
    } catch (e) {
      debugPrint("Status check error: $e");
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, LoginScreen.id, (route) => false);
        }
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _subscribe(String planType) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final approveUrl = await ApiService.startSubscription(planType);
      final uri = Uri.parse(approveUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open the payment page.');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Log out and clear the stack to return to login cleanly
            await ApiService.logout();
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                LoginScreen.id,
                (route) => false,
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkInitialStatus,
            tooltip: "Refresh status",
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentStatus == 'pending') ...[
                    const Icon(Icons.hourglass_empty, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      "Payment Pending",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "We're waiting for payment confirmation from PayPal. This usually takes a few seconds.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                  ] else if (_currentStatus == 'expired' || _currentStatus == 'cancelled') ...[
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      _currentStatus == 'expired' ? "Subscription Expired" : "Subscription Cancelled",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please renew your plan to continue enjoying movies.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    const Icon(Icons.movie_outlined, size: 64, color: AppColors.accent),
                    const SizedBox(height: 16),
                    const Text(
                      'Unlock Full Access',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick a plan to start exploring thousands of titles.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 32),
                  ],

                  _PlanCard(
                    title: 'Monthly',
                    price: '\$1 / month',
                    onTap: isLoading ? null : () => _subscribe('monthly'),
                  ),
                  const SizedBox(height: 16),
                  _PlanCard(
                    title: 'Yearly',
                    price: '\$10 / year',
                    badge: 'Best value',
                    onTap: isLoading ? null : () => _subscribe('yearly'),
                  ),

                  const SizedBox(height: 24),
                  if (_currentStatus == 'pending')
                    TextButton.icon(
                      onPressed: _checkInitialStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text("I've already paid"),
                    ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// A simple tappable card for one plan option.
class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(price, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
