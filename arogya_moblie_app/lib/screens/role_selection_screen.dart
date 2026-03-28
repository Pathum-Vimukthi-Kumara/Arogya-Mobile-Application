import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

// ── Role model ────────────────────────────────────────────────────────────────

class RoleOption {
  final int id;
  final String roleName;
  final String label;
  final String description;
  final IconData icon;
  final bool requiresSecretKey;

  const RoleOption({
    required this.id,
    required this.roleName,
    required this.label,
    required this.description,
    required this.icon,
    required this.requiresSecretKey,
  });
}

const List<RoleOption> kRoles = [
  RoleOption(
    id: 2,
    roleName: 'PATIENT',
    label: 'Patient',
    description: 'Book appointments and manage your health records',
    icon: Icons.person_outline_rounded,
    requiresSecretKey: false,
  ),
  RoleOption(
    id: 1,
    roleName: 'DOCTOR',
    label: 'Doctor',
    description: 'Manage consultations and patient care',
    icon: Icons.medical_services_outlined,
    requiresSecretKey: true,
  ),
  RoleOption(
    id: 5,
    roleName: 'TECHNICIAN',
    label: 'Technician',
    description: 'Handle lab tests and diagnostic services',
    icon: Icons.science_outlined,
    requiresSecretKey: true,
  ),
  RoleOption(
    id: 4,
    roleName: 'ADMIN',
    label: 'Admin',
    description: 'Manage the platform and users',
    icon: Icons.admin_panel_settings_outlined,
    requiresSecretKey: true,
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  RoleOption? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Who are you?',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select the role that best describes you',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),

            // ── Role tiles ─────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: kRoles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final role = kRoles[i];
                  final isSelected =
                      _selected?.roleName == role.roleName;
                  return _RoleTile(
                    role: role,
                    isSelected: isSelected,
                    onTap: () =>
                        setState(() => _selected = role),
                  );
                },
              ),
            ),

            // ── Bottom area ─────────────────────────────────────────
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _selected == null
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SignupScreen(role: _selected!),
                                  ),
                                ),
                        child: const Text('Continue'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign-in link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account?  ',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role tile ─────────────────────────────────────────────────────────────────

class _RoleTile extends StatelessWidget {
  final RoleOption role;
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                role.icon,
                color: isSelected ? Colors.white : AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        role.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isSelected
                              ? AppTheme.primaryDark
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (role.requiresSecretKey) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Key required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    role.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Selection indicator
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primary, size: 24,
                      key: ValueKey('checked'))
                  : Icon(Icons.radio_button_unchecked_rounded,
                      color: AppTheme.border, size: 24,
                      key: const ValueKey('unchecked')),
            ),
          ],
        ),
      ),
    );
  }
}
