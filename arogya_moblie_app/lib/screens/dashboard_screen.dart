import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/user_api_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  static const routeName = '/dashboard';
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _patientProfile;
  bool _profileLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _profileLoading = true);
    try {
      final profile = await UserApiService.getPatientProfile(user.id);
      if (mounted) setState(() => _patientProfile = profile);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('You will be returned to the sign-in screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) {
          return const LoginScreen();
        }
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Dashboard'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  auth.refreshUser();
                  _loadProfile();
                },
              ),
              IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout_rounded),
                onPressed: _confirmLogout,
              ),
            ],
          ),
          body: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              await auth.refreshUser();
              await _loadProfile();
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _WelcomeBanner(user: user),
                const SizedBox(height: 20),
                _AccountCard(user: user),
                const SizedBox(height: 20),
                _ProfileCard(
                  profile: _patientProfile,
                  loading: _profileLoading,
                  user: user,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProfileScreen(user: user)),
                  ),
                ),
                const SizedBox(height: 20),
                _QuickActionsGrid(user: user),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Welcome banner ─────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final User user;
  const _WelcomeBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user.username}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _roleLabel(user.userRole.roleName),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              user.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'patient':
        return 'Patient Account';
      case 'doctor':
        return 'Doctor Account';
      case 'admin':
        return 'Administrator';
      case 'technician':
        return 'Lab Technician';
      default:
        return roleName;
    }
  }
}

// ── Account info card ──────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final User user;
  const _AccountCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Account Details',
      icon: Icons.person_outline_rounded,
      children: [
        _InfoRow(label: 'User ID', value: '#${user.id}'),
        _InfoRow(label: 'Username', value: user.username),
        _InfoRow(label: 'Email', value: user.email),
        _InfoRow(label: 'Role', value: user.userRole.roleName),
      ],
    );
  }
}

// ── Patient profile card ───────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final bool loading;
  final User user;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.loading,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (user.userRole.roleName.toLowerCase() != 'patient') {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: _SectionCard(
        title: 'Patient Profile',
        icon: Icons.medical_information_outlined,
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppTheme.textSecondary),
        children: loading
            ? [
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary),
                ))
              ]
            : profile == null
                ? [
                    _EmptyState(
                      icon: Icons.add_circle_outline,
                      message: 'No profile found. Tap to create one.',
                    )
                  ]
                : [
                    _InfoRow(
                        label: 'Name',
                        value:
                            '${profile!['firstName'] ?? ''} ${profile!['lastName'] ?? ''}'
                                .trim()),
                    if (profile!['dateOfBirth'] != null)
                      _InfoRow(
                          label: 'Date of Birth',
                          value: profile!['dateOfBirth'].toString()),
                    if (profile!['gender'] != null)
                      _InfoRow(
                          label: 'Gender',
                          value: profile!['gender'].toString()),
                    if (profile!['bloodGroup'] != null)
                      _InfoRow(
                          label: 'Blood Group',
                          value: profile!['bloodGroup'].toString()),
                    if (profile!['phoneNumber'] != null)
                      _InfoRow(
                          label: 'Phone',
                          value: profile!['phoneNumber'].toString()),
                  ],
      ),
    );
  }
}

// ── Quick actions grid ─────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final User user;
  const _QuickActionsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    final isPatient =
        user.userRole.roleName.toLowerCase() == 'patient';

    final actions = <_QuickAction>[
      _QuickAction(
          icon: Icons.person_outline_rounded,
          label: 'My Profile',
          color: AppTheme.primary,
          onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileScreen(user: user)),
              )),
      if (isPatient)
        _QuickAction(
            icon: Icons.description_outlined,
            label: 'Prescriptions',
            color: const Color(0xFF6366F1),
            onTap: () => _showComingSoon(context, 'Prescriptions')),
      if (isPatient)
        _QuickAction(
            icon: Icons.science_outlined,
            label: 'Lab Results',
            color: const Color(0xFF10B981),
            onTap: () => _showComingSoon(context, 'Lab Results')),
      if (isPatient)
        _QuickAction(
            icon: Icons.local_hospital_outlined,
            label: 'Mobile Clinics',
            color: const Color(0xFFF59E0B),
            onTap: () => _showComingSoon(context, 'Mobile Clinics')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: actions
              .map((a) => _QuickActionTile(action: a))
              .toList(),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext ctx, String name) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text('$name — coming soon'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: action.color.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(action.icon, color: action.color, size: 28),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: TextStyle(
                color: action.color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable sub-widgets ───────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
