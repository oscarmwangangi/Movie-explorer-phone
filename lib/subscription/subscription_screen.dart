import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movie_explorer/appUI/home/home.dart';
import 'package:movie_explorer/authentication/login.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import '../api/api_service.dart';

/// The different "pages" this one screen can show, in the order a
/// customer normally sees them:
///   form     -> pick a plan + type phone number + tap "Pay with M-Pesa"
///   waiting  -> spinner + countdown while we wait for the M-Pesa PIN
///   success  -> payment went through
///   failed   -> cancelled / insufficient balance / wrong PIN / etc.
///   timedOut -> we didn't hear back in time
enum _PayStep { form, waiting, success, failed, timedOut }

/// Shown when a user needs to subscribe (or their subscription has
/// expired). Lets them pick Monthly or Yearly and pay with M-Pesa.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  static String id = 'subscription_screen';

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with WidgetsBindingObserver {
  // Prices shown on the screen, in Kenya Shillings.
  // IMPORTANT: keep these the same as MPESA_MONTHLY_AMOUNT and
  // MPESA_YEARLY_AMOUNT in the backend .env. The backend decides what
  // is really charged - these numbers are only for display.
  static const int _monthlyPrice = 130;
  static const int _yearlyPrice = 1300;

  // How long we wait for the customer to enter their PIN (in seconds).
  static const int _waitSeconds = 90;

  // How often we ask the backend "did the payment go through?" (in seconds).
  static const int _pollEverySeconds = 4;

  static const Color _mpesaGreen = Color(0xFF00A651);

  // Accepts 07XXXXXXXX or 2547XXXXXXXX (spaces, dashes and a leading + are removed first).
  static final RegExp _phonePattern = RegExp(r'^(07\d{8}|2547\d{8})$');

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  _PayStep _step = _PayStep.form;
  String _selectedPlan = 'monthly';

  bool _isCheckingStatus = true; // true while we check "is this user already subscribed?"
  bool _isStarting = false; // true while we send the STK push
  bool _isPolling = false; // true while a status request is in flight
  bool _isCheckingAgain = false; // true after tapping "Check again"

  String? _currentStatus; // the subscription status from the backend
  String? _errorMessage; // error shown under the form
  String? _checkoutRequestId; // the ID of the payment we are waiting for
  String _sentToPhone = ''; // the number the prompt was sent to
  String _resultTitle = '';
  String _resultMessage = '';
  int _secondsLeft = _waitSeconds;

  Timer? _countdownTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _redirectIfActive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user comes back to the app (e.g. after the M-Pesa prompt),
    // check right away instead of waiting for the next timer tick.
    if (state != AppLifecycleState.resumed) return;

    if (_step == _PayStep.waiting) {
      _pollOnce();
    } else if (_step == _PayStep.form) {
      _redirectIfActive();
    }
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  void _stopTimers() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _countdownTimer = null;
    _pollTimer = null;
  }

  void _goToHome() {
    Navigator.pushNamedAndRemoveUntil(context, HomeScreen.id, (route) => false);
  }

  /// Removes spaces, dashes and a leading "+": "+254 712-345 678" -> "254712345678"
  String _cleanPhone(String value) {
    return value.replaceAll(RegExp(r'[\s-]'), '').replaceFirst(RegExp(r'^\+'), '');
  }

  /// Returns an error message if the number is wrong, or null if it is fine.
  String? _validatePhone(String? value) {
    final cleaned = _cleanPhone(value ?? '');
    if (cleaned.isEmpty) return 'Enter your M-Pesa phone number';
    if (!_phonePattern.hasMatch(cleaned)) {
      return 'Use the format 07XXXXXXXX or 2547XXXXXXXX';
    }
    return null;
  }

  // ---------------------------------------------------------------
  // Talking to the backend
  // ---------------------------------------------------------------

  /// If the user is already subscribed, skip this screen and go to Home.
  Future<void> _redirectIfActive({bool showSpinner = false}) async {
    if (showSpinner) setState(() => _isCheckingStatus = true);

    try {
      final sub = await ApiService.getMySubscription();
      _currentStatus = sub['status']?.toString();

      if (_currentStatus == 'active') {
        if (mounted) _goToHome();
        return;
      }
    } catch (e) {
      debugPrint("Status check error: $e");
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, LoginScreen.id, (route) => false);
        }
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  /// Called when the customer taps "Pay with M-Pesa".
  Future<void> _payWithMpesa() async {
    // Run the phone number validator. If it shows an error, stop here.
    if (!_formKey.currentState!.validate()) return;

    final phone = _cleanPhone(_phoneController.text);

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      // This makes the M-Pesa PIN prompt pop up on the customer's phone.
      final checkoutRequestId = await ApiService.startMpesaPayment(_selectedPlan, phone);

      _checkoutRequestId = checkoutRequestId;
      _sentToPhone = phone;
      _startWaiting();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  /// Starts the countdown + the "did they pay yet?" checks.
  void _startWaiting() {
    _stopTimers();

    setState(() {
      _step = _PayStep.waiting;
      _secondsLeft = _waitSeconds;
    });

    // Counts down once per second.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        _onTimeUp();
      } else if (mounted) {
        setState(() => _secondsLeft--);
      }
    });

    // Asks the backend what happened every few seconds.
    _pollTimer = Timer.periodic(const Duration(seconds: _pollEverySeconds), (timer) {
      _pollOnce();
    });
  }

  /// Asks the backend once: "did this payment go through?"
  Future<void> _pollOnce() async {
    // Don't send a new request while the last one is still running.
    if (_isPolling || _checkoutRequestId == null) return;
    _isPolling = true;

    try {
      final result = await ApiService.getPaymentStatus(_checkoutRequestId!);
      if (!mounted) return;

      final status = result['status']?.toString();
      final message = result['message']?.toString() ?? '';

      if (status == 'COMPLETED') {
        _onSuccess(message);
      } else if (status == 'FAILED' || status == 'CANCELLED') {
        _onFailed(status!, message);
      }
      // Any other status means PENDING: keep waiting.
    } catch (e) {
      // A bad network moment is not a failed payment. We simply try again on the next tick.
      debugPrint("Payment status check error: $e");
    } finally {
      _isPolling = false;
    }
  }

  /// The countdown reached zero without an answer.
  Future<void> _onTimeUp() async {
    _stopTimers();

    // One last check before we give up.
    await _pollOnce();

    if (mounted && _step == _PayStep.waiting) {
      setState(() => _step = _PayStep.timedOut);
    }
  }

  void _onSuccess(String message) {
    if (_step == _PayStep.success) return;
    _stopTimers();

    setState(() {
      _step = _PayStep.success;
      _resultTitle = 'Payment successful!';
      _resultMessage = message;
    });

    // Show the success message for a moment, then open the app.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _goToHome();
    });
  }

  void _onFailed(String status, String message) {
    _stopTimers();

    setState(() {
      _step = _PayStep.failed;
      _resultTitle = status == 'CANCELLED' ? 'Payment cancelled' : 'Payment failed';
      _resultMessage = message;
    });
  }

  /// "Check again" button (shown after the countdown ends).
  Future<void> _checkAgain() async {
    setState(() => _isCheckingAgain = true);
    await _pollOnce();

    if (!mounted) return;
    setState(() => _isCheckingAgain = false);

    if (_step == _PayStep.timedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still no confirmation from M-Pesa. Please try again in a moment.')),
      );
    }
  }

  /// Goes back to the form so the customer can try again.
  void _backToForm() {
    _stopTimers();
    setState(() {
      _step = _PayStep.form;
      _errorMessage = null;
      _checkoutRequestId = null;
    });
  }

  // ---------------------------------------------------------------
  // Screen
  // ---------------------------------------------------------------

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
            onPressed: () => _redirectIfActive(showSpinner: true),
            tooltip: "Refresh status",
          )
        ],
      ),
      body: _isCheckingStatus
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  // maxWidth keeps the layout tidy on the Windows desktop app.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildCurrentStep(),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _PayStep.form:
        return _buildForm();
      case _PayStep.waiting:
        return _buildWaiting();
      case _PayStep.success:
        return _buildResult(
          icon: Icons.check_circle,
          color: _mpesaGreen,
          footer: const Text('Taking you to the app...', style: TextStyle(color: Colors.white70)),
        );
      case _PayStep.failed:
        return _buildResult(
          icon: Icons.error_outline,
          color: Colors.redAccent,
          footer: _buildPrimaryButton('Try again', _backToForm),
        );
      case _PayStep.timedOut:
        return _buildTimedOut();
    }
  }

  // ----- Step 1: choose plan + phone number -----

  Widget _buildForm() {
    // Show a different title if the user used to be subscribed.
    String title = 'Unlock Full Access';
    String subtitle = 'Pick a plan and pay with M-Pesa.';
    IconData icon = Icons.movie_outlined;
    Color iconColor = AppColors.accent;

    if (_currentStatus == 'expired' || _currentStatus == 'cancelled') {
      title = _currentStatus == 'expired' ? 'Subscription Expired' : 'Subscription Cancelled';
      subtitle = 'Please renew your plan to continue enjoying movies.';
      icon = Icons.error_outline;
      iconColor = Colors.redAccent;
    }

    final price = _selectedPlan == 'monthly' ? _monthlyPrice : _yearlyPrice;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          const SizedBox(height: 28),

          _PlanCard(
            title: 'Monthly',
            price: 'KES $_monthlyPrice / month',
            selected: _selectedPlan == 'monthly',
            onTap: _isStarting ? null : () => setState(() => _selectedPlan = 'monthly'),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Yearly',
            price: 'KES $_yearlyPrice / year',
            badge: 'Best value',
            selected: _selectedPlan == 'yearly',
            onTap: _isStarting ? null : () => setState(() => _selectedPlan = 'yearly'),
          ),
          const SizedBox(height: 24),

          // The phone number box. The validator runs when we call _formKey.currentState!.validate().
          TextFormField(
            controller: _phoneController,
            enabled: !_isStarting,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              // Only allow digits, +, spaces and dashes.
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
              LengthLimitingTextInputFormatter(16),
            ],
            decoration: const InputDecoration(
              labelText: 'M-Pesa phone number',
              hintText: '07XXXXXXXX or 2547XXXXXXXX',
              prefixIcon: Icon(Icons.phone_android),
            ),
            validator: _validatePhone,
            onFieldSubmitted: (_) => _isStarting ? null : _payWithMpesa(),
          ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isStarting ? null : _payWithMpesa,
              style: ElevatedButton.styleFrom(
                backgroundColor: _mpesaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isStarting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      'Pay with M-Pesa  •  KES $price',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You will get an M-Pesa prompt on your phone. Enter your PIN to pay.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ----- Step 2: waiting for the PIN -----

  Widget _buildWaiting() {
    final minutes = _secondsLeft ~/ 60;
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A ring that shrinks as time runs out, with the countdown in the middle.
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _secondsLeft / _waitSeconds,
                  strokeWidth: 8,
                  color: _mpesaGreen,
                  backgroundColor: AppColors.surfaceElevated,
                ),
              ),
              Text('$minutes:$seconds', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Check your phone',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent an M-Pesa prompt to $_sentToPhone.\nEnter your M-Pesa PIN to complete the payment.',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
            ),
            SizedBox(width: 10),
            Text('Waiting for payment confirmation...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 28),
        TextButton(onPressed: _backToForm, child: const Text('Cancel')),
      ],
    );
  }

  // ----- Step 3: result (success or failed) -----

  Widget _buildResult({required IconData icon, required Color color, required Widget footer}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 80, color: color),
        const SizedBox(height: 16),
        Text(
          _resultTitle,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(_resultMessage, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        footer,
      ],
    );
  }

  // ----- Countdown ended without an answer -----

  Widget _buildTimedOut() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_empty, size: 72, color: Colors.orange),
        const SizedBox(height: 16),
        const Text(
          'Still waiting for confirmation',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          "We haven't received a confirmation from M-Pesa yet. If you already entered your PIN, tap "
          "'Check again'. If you did not get a prompt, you can try again.",
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        _buildPrimaryButton(
          _isCheckingAgain ? 'Checking...' : 'Check again',
          _isCheckingAgain ? null : _checkAgain,
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _backToForm, child: const Text('Try again with a new prompt')),
      ],
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _mpesaGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// A simple tappable card for one plan option.
/// The selected plan gets a green border.
class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final bool selected;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.selected,
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
          border: Border.all(
            color: selected ? const Color(0xFF00A651) : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
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
