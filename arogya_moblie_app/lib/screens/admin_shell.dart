import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/clinic_api_service.dart';
import '../services/user_api_service.dart';
import 'clinics_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _pages = [
      _AdminHomeTab(user: widget.user),
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
  const _AdminHomeTab({required this.user});

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

  Future<void> _confirmLogout(BuildContext context) async {
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

    if (confirmed != true) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
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
        label: 'Active Doctors',
        value: _activeDoctors,
        icon: Icons.how_to_reg_outlined,
        color: const Color(0xFF6366F1),
      ),
      _StatItem(
        label: 'Scheduled',
        value: _scheduledClinics,
        icon: Icons.event_available_outlined,
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
                            'Hello, ${widget.user.username} 👋',
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
                      onPressed: () => _confirmLogout(context),
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
                        const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
                      // ── Stat list (single column) ───────────────────
                      ...List.generate(stats.length, (i) => Padding(
                        padding: EdgeInsets.only(
                            bottom: i < stats.length - 1 ? 12 : 0),
                        child: _StatCard(item: stats[i], loading: _loading),
                      )),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 16),
          // Label + value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                loading
                    ? _SkeletonBox(width: 56, height: 24)
                    : Text(
                        item.value.toString(),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.1,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading box ───────────────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  const _SkeletonBox({required this.width, required this.height});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
