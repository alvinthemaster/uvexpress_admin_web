import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signIn() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signIn(
          _emailController.text.trim(), _passwordController.text);
    }
  }

  void _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your email address first.');
      return;
    }

    if (!AppHelpers.isValidEmail(_emailController.text.trim())) {
      _showErrorDialog('Please enter a valid email address.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.resetPassword(_emailController.text.trim());

    if (!mounted) return;

    if (authProvider.errorMessage == null) {
      _showSuccessDialog('Password reset email sent. Please check your inbox.');
    }
  }

  void _createAdminAccount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      String result = await authProvider.createInitialAdmin();
      if (!mounted) return;
      _showSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Failed to create admin account: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(AppConstants.primaryColorValue),
              const Color(AppConstants.primaryColorValue).withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.largePadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo and Title
                      Icon(
                        Icons.admin_panel_settings,
                        size: 64,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      Text(
                        AppStrings.appTitle,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppConstants.smallPadding),
                      Text(
                        'Admin Access Portal',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppConstants.largePadding),

                      // Login Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: AppStrings.email,
                                hintText: 'Enter your email address',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return AppStrings.fieldRequired;
                                }
                                if (!AppHelpers.isValidEmail(value.trim())) {
                                  return AppStrings.invalidEmail;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppConstants.defaultPadding),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: AppStrings.password,
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppStrings.fieldRequired;
                                }
                                if (value.length <
                                    AppConstants.minPasswordLength) {
                                  return AppStrings.passwordTooShort;
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _signIn(),
                            ),
                            const SizedBox(height: AppConstants.smallPadding),

                            // Remember Me and Forgot Password
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                ),
                                const Text('Remember me'),
                                const Spacer(),
                                TextButton(
                                  onPressed: _resetPassword,
                                  child: const Text(AppStrings.forgotPassword),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.defaultPadding),

                            // Error Message
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, _) {
                                if (authProvider.errorMessage != null) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(
                                        AppConstants.smallPadding),
                                    margin: const EdgeInsets.only(
                                        bottom: AppConstants.defaultPadding),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      border:
                                          Border.all(color: Colors.red[300]!),
                                      borderRadius: BorderRadius.circular(
                                          AppConstants.defaultBorderRadius),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline,
                                            color: Colors.red[700], size: 20),
                                        const SizedBox(
                                            width: AppConstants.smallPadding),
                                        Expanded(
                                          child: Text(
                                            authProvider.errorMessage!,
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.close, size: 16),
                                          color: Colors.red[700],
                                          onPressed: authProvider.clearError,
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),

                            // Sign In Button
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, _) {
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        authProvider.isLoading ? null : _signIn,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical:
                                              AppConstants.defaultPadding),
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            AppStrings.signIn,
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppConstants.largePadding),

                      // Development Only - Create Admin Button
                      if (kDebugMode) ...[
                        const Divider(),
                        const SizedBox(height: AppConstants.defaultPadding),
                        Text(
                          'Development Only',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppConstants.smallPadding),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _createAdminAccount,
                            icon: const Icon(Icons.admin_panel_settings),
                            label: const Text('Create Admin Account'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange[700],
                              side: BorderSide(color: Colors.orange[300]!),
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppConstants.defaultPadding),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                      ],

                      // Footer
                      Text(
                        '© 2025 UVExpress. All rights reserved.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
