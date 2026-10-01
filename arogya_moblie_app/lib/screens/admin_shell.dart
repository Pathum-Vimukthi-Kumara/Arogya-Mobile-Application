import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/clinic_api_service.dart';
import '../services/user_api_service.dart';
import 'clinics_screen.dart';
import 'lab_tests_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Bottom-nav shell shown only for ADMIN users.
/// Tabs: Home · Clinics · Profile
class AdminShell extends StatefulWidget {
  final User user;
  const AdminShell({super.key, required this.user});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  late final List<Widget> _pages;

  void _setTab(int i) {
    setState(() => _index = i);
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      _AdminHomeTab(user: widget.user, onSelectTab: _setTab),
      const ClinicsScreen(),
      ProfileScreen(user: widget.user),
    ];
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_today_outlined),
      selectedIcon: Icon(Icons.calendar_today_rounded),
      label: 'Clinics',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primaryLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _destinations,
      ),
    );
  }
}

// ── Admin Home Tab ───────────────────────────────────────────────────────────

class _AdminHomeTab extends StatefulWidget {
  final User user;
  final ValueChanged<int>? onSelectTab;
  const _AdminHomeTab({required this.user, this.onSelectTab});

  @override
  State<_AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<_AdminHomeTab> {
  bool _loading = true;
  int _totalPatients = 0;
  int _totalClinics = 0;
  int _activeDoctors = 0;
  int _scheduledClinics = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign out?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('You will be returned to the sign-in screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    // Fetch all in parallel — same approach as the web hook
    final results = await Future.wait([
      UserApiService.getAllPatientProfiles().catchError((_) => <dynamic>[]),
      UserApiService.getAllDoctorProfiles().catchError((_) => <dynamic>[]),
      ClinicApiService.getAllClinics().catchError((_) => <dynamic>[]),
    ]);

    final patients = results[0];
    final doctors = results[1];
    final clinics = results[2];

    if (mounted) {
      setState(() {
        _totalPatients = patients.length;
        _activeDoctors = doctors.length;
        _totalClinics = clinics.length;
        _scheduledClinics = clinics
            .where((c) =>
                (c as Map<String, dynamic>)['status'] == 'SCHEDULED')
            .length;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(
        label: 'Total Patients',
        value: _totalPatients,
        icon: Icons.people_outline_rounded,
        color: AppTheme.primary,
      ),
      _StatItem(
        label: 'Total Clinics',
        value: _totalClinics,
        icon: Icons.calendar_today_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _StatItem(
        label: 'Scheduled Clinics',
        value: _scheduledClinics,
        icon: Icons.event_available_outlined,
        color: const Color(0xFF6366F1),
      ),
      _StatItem(
        label: 'Active Doctors',
        value: _activeDoctors,
        icon: Icons.how_to_reg_outlined,
        color: const Color(0xFF10B981),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayLight,
      child: Scaffold(
        backgroundColor: AppTheme.primary,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient header ──────────────────────────────────────
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
                            _greeting(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hello, ${widget.user.username}',
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
                            child: const Text(
                              'Administrator',
                              style: TextStyle(
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
                    IconButton(
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout_rounded),
                      color: Colors.white,
                      tooltip: 'Sign Out',
                    ),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        widget.user.initials,
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

            // ── White body ───────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async {
                    await context.read<AuthProvider>().refreshUser();
                    await _fetchStats();
                  },
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    children: [
                      const Text(
                        'Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── 2x2 Stats Grid ──────────────────────────────
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: stats
                            .map((item) =>
                                _StatCard(item: item, loading: _loading))
                            .toList(),
                      ),
                      const SizedBox(height: 28),

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
                        children: [
                          _ActionTile(
                            action: _AdminAction(
                              icon: Icons.calendar_today_rounded,
                              label: 'Manage Clinics',
                              color: AppTheme.primary,
                              onTap: () => widget.onSelectTab?.call(1),
                            ),
                          ),
                          _ActionTile(
                            action: _AdminAction(
                              icon: Icons.science_rounded,
                              label: 'Lab Tests',
                              color: const Color(0xFF10B981),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LabTestsScreen(currentUser: widget.user),
                                ),
                              ),
                            ),
                          ),
                          _ActionTile(
                            action: _AdminAction(
                              icon: Icons.person_rounded,
                              label: 'My Profile',
                              color: const Color(0xFF6366F1),
                              onTap: () => widget.onSelectTab?.call(2),
                            ),
                          ),
                          _ActionTile(
                            action: _AdminAction(
                              icon: Icons.sync_rounded,
                              label: 'Refresh Stats',
                              color: const Color(0xFFF59E0B),
                              onTap: _fetchStats,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Brand info strip ───────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                          ),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: AppTheme.primaryDark.withValues(
                                        alpha: 0.7,
                                      ),
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

// ── Stat card data ────────────────────────────────────────────────────────────

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

// ── Stat card widget ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final _StatItem item;
  final bool loading;
  const _StatCard({required this.item, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          loading
              ? Container(
                  width: 40,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              : Text(
                  item.value.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Admin Quick Action data ───────────────────────────────────────────────────

class _AdminAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ── Action tile widget ────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final _AdminAction action;
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
