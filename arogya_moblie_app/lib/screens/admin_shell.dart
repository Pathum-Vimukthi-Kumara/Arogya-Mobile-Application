import 'package:flutter/material.dart';
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
    final user = widget.user;

    final stats = [
      _StatItem(
        label: 'Total Patients',
        value: _totalPatients,
        icon: Icons.people_outline_rounded,
      ),
      _StatItem(
        label: 'Total Clinics',
        value: _totalClinics,
        icon: Icons.calendar_today_outlined,
      ),
      _StatItem(
        label: 'Active Doctors',
        value: _activeDoctors,
        icon: Icons.how_to_reg_outlined,
      ),
      _StatItem(
        label: 'Scheduled Clinics',
        value: _scheduledClinics,
        icon: Icons.calendar_today_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          await context.read<AuthProvider>().refreshUser();
          await _fetchStats();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Page heading (matches web) ──────────────────────────
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // ── 2×2 stat cards grid ─────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemCount: stats.length,
              itemBuilder: (_, i) =>
                  _StatCard(item: stats[i], loading: _loading),
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
  const _StatItem(
      {required this.label, required this.value, required this.icon});
}

// ── Stat card widget (matches web card design) ────────────────────────────────

class _StatCard extends StatelessWidget {
  final _StatItem item;
  final bool loading;
  const _StatCard({required this.item, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Label
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          // Value row + icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Number
              Expanded(
                child: loading
                    ? Container(
                        height: 32,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(
                        item.value.toString(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1,
                        ),
                      ),
              ),
              // Icon badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
