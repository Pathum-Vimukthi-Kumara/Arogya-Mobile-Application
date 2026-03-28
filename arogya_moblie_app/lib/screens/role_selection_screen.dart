import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

// ── Role model (shared with SignupScreen) ─────────────────────────────────────

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
    icon: Icons.person_outline,
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

  void _continue() {
    if (_selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupScreen(role: _selected!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Brand ──────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
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
                      'Role Selection',
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
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Role tiles ─────────────────────────────────────────
              ...kRoles.map(
                (role) => _RoleTile(
                  role: role,
                  isSelected: _selected?.roleName == role.roleName,
                  onTap: () => setState(() => _selected = role),
                ),
              ),
              const SizedBox(height: 24),

              // ── Continue button ────────────────────────────────────
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _continue,
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 20),

              // ── Sign-in link ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
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
              const SizedBox(height: 16),
            ],
          ),
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
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    isSelected ? AppTheme.primary : AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                role.icon,
                color: isSelected ? Colors.white : AppTheme.primary,
                size: 22,
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
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (role.requiresSecretKey) ...[
                        const SizedBox(width: 8),
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
                  const SizedBox(height: 3),
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

            // Radio indicator
            Radio<String>(
              value: role.roleName,
              groupValue: _selected(isSelected, role.roleName),
              onChanged: (_) => onTap(),
              activeColor: AppTheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  String? _selected(bool isSelected, String roleName) =>
      isSelected ? roleName : null;
}
