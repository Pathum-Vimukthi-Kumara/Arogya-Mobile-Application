import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/user_api_service.dart';
import 'login_screen.dart';

// ── Role model ──────────────────────────────────────────────────────────────

class _RoleOption {
  final int id;
  final String roleName;
  final String label;
  final String description;
  final IconData icon;
  final bool requiresSecretKey;

  const _RoleOption({
    required this.id,
    required this.roleName,
    required this.label,
    required this.description,
    required this.icon,
    required this.requiresSecretKey,
  });
}

const List<_RoleOption> _kRoles = [
  _RoleOption(
    id: 2,
    roleName: 'PATIENT',
    label: 'Patient',
    description: 'Book appointments and manage your health records',
    icon: Icons.person_outline,
    requiresSecretKey: false,
  ),
  _RoleOption(
    id: 1,
    roleName: 'DOCTOR',
    label: 'Doctor',
    description: 'Manage consultations and patient care',
    icon: Icons.medical_services_outlined,
    requiresSecretKey: true,
  ),
  _RoleOption(
    id: 5,
    roleName: 'TECHNICIAN',
    label: 'Technician',
    description: 'Handle lab tests and diagnostic services',
    icon: Icons.science_outlined,
    requiresSecretKey: true,
  ),
  _RoleOption(
    id: 4,
    roleName: 'ADMIN',
    label: 'Admin',
    description: 'Manage the platform and users',
    icon: Icons.admin_panel_settings_outlined,
    requiresSecretKey: true,
  ),
];

// ── Widget ───────────────────────────────────────────────────────────────────

class SignupScreen extends StatefulWidget {
  static const routeName = '/signup';
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ── state ──────────────────────────────────────────────────────────
  _RoleOption? _selectedRole;
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

  // ── 4 frontend validation checks ───────────────────────────────────

  String? _runValidation() {
    // Check 1: all required fields filled
    if (_usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      return 'Please fill in all required fields';
    }

    // Check 2: passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Passwords do not match';
    }

    // Check 3: role selected
    if (_selectedRole == null) {
      return 'Role information is missing. Please select a role.';
    }

    // Check 4: secret key required for protected roles
    if (_selectedRole!.requiresSecretKey &&
        _secretKeyController.text.trim().isEmpty) {
      return 'Secret key is required for this role';
    }

    return null; // all checks passed
  }

  Future<void> _submit() async {
    // Run form-field validators (email format, etc.)
    if (!_formKey.currentState!.validate()) return;

    // Run the same 4 cross-field checks as the frontend
    final validationError = _runValidation();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await UserApiService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        roleId: _selectedRole!.id,
        roleName: _selectedRole!.roleName,
        secretKey: _selectedRole!.requiresSecretKey
            ? _secretKeyController.text.trim()
            : null,
      );

      if (!mounted) return;
      _showSuccessAndNavigate();
    } on UserApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessAndNavigate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Registration successful! Welcome, ${_usernameController.text.trim()}!'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // ── Brand logo ────────────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create an account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join Arogya and start your health journey',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Step 1 — Role selection ───────────────────────────
                _SectionHeader(title: 'Select your role'),
                const SizedBox(height: 12),
                _RoleSelector(
                  selected: _selectedRole,
                  onChanged: (role) => setState(() {
                    _selectedRole = role;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 24),

                // ── Step 2 — Account form ─────────────────────────────
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

                        // Secret key (for protected roles)
                        if (_selectedRole != null &&
                            _selectedRole!.requiresSecretKey) ...[
                          _SecretKeyBanner(
                            roleName: _selectedRole!.label,
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel(text: 'Secret Key *'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _secretKeyController,
                            obscureText: _obscureSecretKey,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'Enter secret key',
                              prefixIcon: const Icon(Icons.vpn_key_outlined,
                                  color: AppTheme.textHint),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureSecretKey
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppTheme.textHint,
                                ),
                                onPressed: () => setState(
                                    () => _obscureSecretKey = !_obscureSecretKey),
                              ),
                            ),
                            validator: (v) {
                              if (_selectedRole != null &&
                                  _selectedRole!.requiresSecretKey &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Secret key is required for this role';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: AppTheme.border),
                          const SizedBox(height: 20),
                        ],

                        // Username
                        _FieldLabel(text: 'Username *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Choose a username',
                            prefixIcon: Icon(Icons.person_outline,
                                color: AppTheme.textHint),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Username is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email
                        _FieldLabel(text: 'Email *'),
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
                        _FieldLabel(text: 'Password *'),
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

                        // Confirm Password
                        _FieldLabel(text: 'Confirm Password *'),
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

                        // What's next info box
                        if (_selectedRole != null) ...[
                          _WhatNextBanner(roleName: _selectedRole!.label),
                          const SizedBox(height: 24),
                        ],

                        // Submit
                        SizedBox(
                          height: 48,
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

                // ── Sign-in link ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable small widgets ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

// ── Role selector ─────────────────────────────────────────────────────────────

class _RoleSelector extends StatelessWidget {
  final _RoleOption? selected;
  final ValueChanged<_RoleOption> onChanged;

  const _RoleSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _kRoles
          .map((role) => _RoleTile(
                role: role,
                isSelected: selected?.roleName == role.roleName,
                onTap: () => onChanged(role),
              ))
          .toList(),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final _RoleOption role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                role.icon,
                color: isSelected ? Colors.white : AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        role.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (role.requiresSecretKey) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Key required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: role.roleName,
              groupValue: isSelected ? role.roleName : null,
              onChanged: (_) => onTap(),
              activeColor: AppTheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info banners ──────────────────────────────────────────────────────────────

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
        border:
            Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: AppTheme.error, size: 18),
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
              style: TextStyle(
                  fontSize: 12, color: Colors.amber.shade800),
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
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
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
