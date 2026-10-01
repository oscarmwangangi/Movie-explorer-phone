import 'package:flutter/material.dart';
import 'package:movie_explorer/api/api_service.dart';
import 'package:movie_explorer/authentication/login.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:movie_explorer/reusable/reusable.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static String id = 'profile_screen';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = await ApiService.getUserProfile();
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleChangePassword() async {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _isChangingPassword = true);

    final error = await ApiService.changePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    if (!mounted) return;

    setState(() => _isChangingPassword = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password updated successfully")),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white70)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.surfaceElevated,
                            child: Icon(Icons.person, size: 60, color: Colors.white70),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _user?['email'] ?? 'User',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _user?['is_admin'] == true ? "Administrator" : "Member",
                            style: const TextStyle(color: Colors.white54),
                          ),
                          const SizedBox(height: 40),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: 20),
                          const Text(
                            "Update Password",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          CustomTextField(
                            controller: _currentPasswordController,
                            hintText: "Current Password",
                            icon: Icons.lock_outline,
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _newPasswordController,
                            hintText: "New Password",
                            icon: Icons.lock_reset,
                            obscureText: true,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isChangingPassword ? null : _handleChangePassword,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                              child: _isChangingPassword
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("CHANGE PASSWORD", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 60),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
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
                              icon: const Icon(Icons.logout, color: Colors.redAccent),
                              label: const Text("LOGOUT", style: TextStyle(color: Colors.redAccent)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
