import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/user_api_service.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class SignupScreen extends StatefulWidget {
  final RoleOption role;
  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _secretKeyController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureSecretKey = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await UserApiService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        roleId: widget.role.id,
        roleName: widget.role.roleName,
        secretKey: widget.role.requiresSecretKey
            ? _secretKeyController.text.trim()
            : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Account created! Welcome, ${_usernameController.text.trim()}'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on UserApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Selected role badge ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(role.icon,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                          Text(
                            role.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Change',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Form card ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error banner
                      if (_error != null) ...[
                        _ErrorBanner(
                          message: _error!,
                          onClose: () => setState(() => _error = null),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Secret key (protected roles only)
                      if (role.requiresSecretKey) ...[
                        _SecretKeyBanner(roleName: role.label),
                        const SizedBox(height: 16),
                        const _FieldLabel('Secret Key *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _secretKeyController,
                          obscureText: _obscureSecretKey,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'Enter secret key',
                            prefixIcon: const Icon(
                                Icons.vpn_key_outlined,
                                color: AppTheme.textHint),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureSecretKey
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppTheme.textHint,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureSecretKey = !_obscureSecretKey),
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty
                                  ? 'Secret key is required'
                                  : null,
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: AppTheme.border),
                        const SizedBox(height: 20),
                      ],

                      // Username
                      const _FieldLabel('Username *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Choose a username',
                          prefixIcon: Icon(Icons.person_outline,
                              color: AppTheme.textHint),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Username is required'
                                : null,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      const _FieldLabel('Email *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.email_outlined,
                              color: AppTheme.textHint),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$')
                              .hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      const _FieldLabel('Password *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppTheme.textHint),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppTheme.textHint,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm password
                      const _FieldLabel('Confirm Password *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppTheme.textHint),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppTheme.textHint,
                            ),
                            onPressed: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // What's next info
                      _WhatNextBanner(roleName: role.label),
                      const SizedBox(height: 24),

                      // Submit
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Create Account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Sign-in link ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context)
                        .pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                      (_) => false,
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppTheme.error, fontSize: 13)),
          ),
          GestureDetector(
            onTap: onClose,
            child:
                const Icon(Icons.close, color: AppTheme.error, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SecretKeyBanner extends StatelessWidget {
  final String roleName;
  const _SecretKeyBanner({required this.roleName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'The $roleName role requires a secret key. '
              'Please contact your administrator to obtain it.',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatNextBanner extends StatelessWidget {
  final String roleName;
  const _WhatNextBanner({required this.roleName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'After registration you\'ll be able to complete your '
              '${roleName.toLowerCase()} profile from your dashboard.',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}
