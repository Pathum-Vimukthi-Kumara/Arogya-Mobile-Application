import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'admin_shell.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatelessWidget {
  static const routeName = '/dashboard';
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) return const LoginScreen();
        if (user.userRole.roleName.toUpperCase() == 'ADMIN') {
          return AdminShell(user: user);
        }
        return _HomeScreen(user: user);
      },
    );
  }
}

// ── Home screen for non-admin roles ─────────────────────────────────────────

class _HomeScreen extends StatelessWidget {
  final User user;
  const _HomeScreen({required this.user});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _roleLabel {
    switch (user.userRole.roleName.toUpperCase()) {
      case 'PATIENT':
        return 'Patient';
      case 'DOCTOR':
        return 'Doctor';
      case 'TECHNICIAN':
        return 'Lab Technician';
      default:
        return user.userRole.roleName;
    }
  }

  List<_Action> _buildActions(BuildContext context) {
    final role = user.userRole.roleName.toUpperCase();

    void soon(String name) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name — coming soon'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }

    final profile = _Action(
      icon: Icons.person_rounded,
      label: 'My Profile',
      color: AppTheme.primary,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
      ),
    );

    if (role == 'PATIENT') {
      return [
        profile,
        _Action(
          icon: Icons.local_hospital_rounded,
          label: 'Clinics',
          color: const Color(0xFFF59E0B),
          onTap: () => soon('Clinics'),
        ),
        _Action(
          icon: Icons.description_rounded,
          label: 'Prescriptions',
          color: const Color(0xFF6366F1),
          onTap: () => soon('Prescriptions'),
        ),
        _Action(
          icon: Icons.science_rounded,
          label: 'Lab Results',
          color: const Color(0xFF10B981),
          onTap: () => soon('Lab Results'),
        ),
      ];
    } else if (role == 'DOCTOR') {
      return [
        profile,
        _Action(
          icon: Icons.calendar_month_rounded,
          label: 'My Clinics',
          color: const Color(0xFFF59E0B),
          onTap: () => soon('My Clinics'),
        ),
        _Action(
          icon: Icons.people_rounded,
          label: 'Patients',
          color: const Color(0xFF6366F1),
          onTap: () => soon('Patients'),
        ),
        _Action(
          icon: Icons.medical_information_rounded,
          label: 'Records',
          color: const Color(0xFF10B981),
          onTap: () => soon('Medical Records'),
        ),
      ];
    } else {
      // Technician
      return [
        profile,
        _Action(
          icon: Icons.science_rounded,
          label: 'Lab Tests',
          color: const Color(0xFF10B981),
          onTap: () => soon('Lab Tests'),
        ),
        _Action(
          icon: Icons.assignment_rounded,
          label: 'Requests',
          color: const Color(0xFFF59E0B),
          onTap: () => soon('Requests'),
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayLight,
      child: Scaffold(
        backgroundColor: AppTheme.primary,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient header ────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hello, ${user.username} 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _roleLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── White body ─────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () =>
                      context.read<AuthProvider>().refreshUser(),
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    children: [
                      // ── Quick actions ──────────────────────────────
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.45,
                        children: actions
                            .map((a) => _ActionTile(action: a))
                            .toList(),
                      ),

                      const SizedBox(height: 28),

                      // ── Brand info strip ───────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.health_and_safety_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Arogya Mobile Clinics',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Quality healthcare at your doorstep',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primaryDark
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action model ──────────────────────────────────────────────────────────────

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ── Action tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final _Action action;
  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              Text(
                action.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
