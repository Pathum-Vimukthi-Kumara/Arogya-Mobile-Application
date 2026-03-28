import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
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
  Map<String, dynamic>? _adminProfile;
  bool _profileLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
    setState(() => _profileLoading = true);
    try {
      final data = await UserApiService.getAdminProfile(widget.user.id);
      if (mounted) setState(() => _adminProfile = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
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
          await _loadAdminProfile();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Welcome banner ─────────────────────────────────────
            Container(
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
                        const Text(
                          'Administrator',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.2),
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
            ),
            const SizedBox(height: 20),

            // ── Account card ────────────────────────────────────────
            _InfoCard(
              title: 'Account Details',
              icon: Icons.manage_accounts_outlined,
              rows: [
                _Row('User ID', '#${user.id}'),
                _Row('Username', user.username),
                _Row('Email', user.email),
                _Row('Role', user.userRole.roleName),
              ],
            ),
            const SizedBox(height: 20),

            // ── Admin profile card ──────────────────────────────────
            _InfoCard(
              title: 'Admin Profile',
              icon: Icons.badge_outlined,
              rows: _profileLoading
                  ? []
                  : _adminProfile == null
                      ? [_Row('Info', 'No profile found')]
                      : [
                          _Row(
                            'Name',
                            '${_adminProfile!['firstName'] ?? ''} ${_adminProfile!['lastName'] ?? ''}'
                                .trim(),
                          ),
                          if (_adminProfile!['phoneNumber'] != null)
                            _Row('Phone',
                                _adminProfile!['phoneNumber'].toString()),
                          if (_adminProfile!['nicNumber'] != null)
                            _Row('NIC',
                                _adminProfile!['nicNumber'].toString()),
                        ],
              loading: _profileLoading,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_Row> rows;
  final bool loading;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.loading = false,
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    ),
                  )
                : Column(
                    children: rows
                        .map((r) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      r.label,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      r.value.isEmpty ? '—' : r.value,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
