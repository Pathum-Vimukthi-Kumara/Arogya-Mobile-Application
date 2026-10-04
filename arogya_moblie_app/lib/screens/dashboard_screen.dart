import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/clinic_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/lab_test_api_service.dart';
import '../services/queue_api_service.dart';
import '../services/test_results_api_service.dart';
import '../services/user_api_service.dart';
import 'admin_shell.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'lab_tests_screen.dart';

class DashboardScreen extends StatelessWidget {
  static const routeName = '/dashboard';
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) return const LoginScreen();
        switch (user.userRole.roleName.toUpperCase()) {
          case 'ADMIN':
            return AdminShell(user: user);
          case 'PATIENT':
            return PatientShell(user: user);
          case 'DOCTOR':
            return DoctorShell(user: user);
          default:
            return TechnicianShell(user: user);
        }
      },
    );
  }
}

/// Bottom-nav shell shown for PATIENT users. Tabs: Home · Clinics · Profile
class PatientShell extends StatefulWidget {
  final User user;
  const PatientShell({super.key, required this.user});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _HomeScreen(
        user: widget.user,
        onNavigateToClinics: () => setState(() => _index = 1),
      ),
      _PatientClinicsSheet(currentUser: widget.user),
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
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.primaryLight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _destinations,
        ),
      ),
    );
  }
}

/// Bottom-nav shell shown for DOCTOR users. Tabs: Home · Clinics · Profile
class DoctorShell extends StatefulWidget {
  final User user;
  const DoctorShell({super.key, required this.user});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _index = 0;
  final GlobalKey<_DoctorStatsPanelState> _doctorStatsKey =
      GlobalKey<_DoctorStatsPanelState>();
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _HomeScreen(
        user: widget.user,
        doctorStatsKey: _doctorStatsKey,
        onNavigateToClinics: () => setState(() => _index = 1),
      ),
      _DoctorClinicsTab(currentUser: widget.user),
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
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            if (i == 0 && _index != 0) {
              _doctorStatsKey.currentState?.fetchStats(silent: true);
            }
            setState(() => _index = i);
          },
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.primaryLight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _destinations,
        ),
      ),
    );
  }
}

class _DoctorClinicsTab extends StatelessWidget {
  final User currentUser;
  const _DoctorClinicsTab({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Clinic Dashboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _DoctorClinicsPanel(currentUser: currentUser),
        ),
      ),
    );
  }
}

/// Bottom-nav shell shown for TECHNICIAN users. Tabs: Home · Lab Tests · Profile
class TechnicianShell extends StatefulWidget {
  final User user;
  const TechnicianShell({super.key, required this.user});

  @override
  State<TechnicianShell> createState() => _TechnicianShellState();
}

class _TechnicianShellState extends State<TechnicianShell> {
  int _index = 0;
  String _labTestsFilter = 'ALL';
  final GlobalKey<_TechnicianStatsPanelState> _technicianStatsKey =
      GlobalKey<_TechnicianStatsPanelState>();

  void _navigateToLabTests(String? filter) {
    setState(() {
      _labTestsFilter = filter ?? 'ALL';
      _index = 1;
    });
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.science_outlined),
      selectedIcon: Icon(Icons.science_rounded),
      label: 'Lab Tests',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeScreen(
        user: widget.user,
        technicianStatsKey: _technicianStatsKey,
        onNavigateToLabTests: _navigateToLabTests,
      ),
      LabTestsScreen(
        currentUser: widget.user,
        initialStatusFilter: _labTestsFilter,
      ),
      ProfileScreen(user: widget.user),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            if (i == 0 && _index != 0) {
              _technicianStatsKey.currentState?.fetchStats(silent: true);
            }
            setState(() => _index = i);
          },
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.primaryLight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _destinations,
        ),
      ),
    );
  }
}

// ── Home screen for non-admin roles ─────────────────────────────────────────

class _HomeScreen extends StatefulWidget {
  final User user;
  final GlobalKey<_DoctorStatsPanelState>? doctorStatsKey;
  final GlobalKey<_TechnicianStatsPanelState>? technicianStatsKey;
  final VoidCallback? onNavigateToClinics;
  final void Function(String? filter)? onNavigateToLabTests;

  const _HomeScreen({
    required this.user,
    this.doctorStatsKey,
    this.technicianStatsKey,
    this.onNavigateToClinics,
    this.onNavigateToLabTests,
  });

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  late final GlobalKey<_DoctorStatsPanelState> _doctorKey =
      widget.doctorStatsKey ?? GlobalKey<_DoctorStatsPanelState>();
  late final GlobalKey<_TechnicianStatsPanelState> _techKey =
      widget.technicianStatsKey ?? GlobalKey<_TechnicianStatsPanelState>();

  User get user => widget.user;

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
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
    await auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

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

  void _openDoctorRecords(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConsultationRecordsSheet(
        currentUser: user,
        patientId: null,
        doctorId: user.id,
        title: 'Consultation Records',
        showDoctorAsPrimary: false,
        allowManage: true,
      ),
    );
  }

  void _openPatientPrescriptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConsultationRecordsSheet(
        currentUser: user,
        patientId: user.id,
        doctorId: null,
        title: 'Prescriptions',
        showDoctorAsPrimary: true,
      ),
    );
  }

  void _openPatientLabResults(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PatientLabResultsSheet(currentUser: user),
    );
  }

  List<_Action> _buildActions(BuildContext context) {
    final role = user.userRole.roleName.toUpperCase();

    if (role == 'PATIENT') {
      return [
        _Action(
          icon: Icons.description_rounded,
          label: 'Prescriptions',
          color: const Color(0xFF6366F1),
          onTap: () => _openPatientPrescriptions(context),
        ),
        _Action(
          icon: Icons.science_rounded,
          label: 'Lab Results',
          color: const Color(0xFF10B981),
          onTap: () => _openPatientLabResults(context),
        ),
      ];
    } else if (role == 'DOCTOR') {
      return [
        _Action(
          icon: Icons.people_rounded,
          label: 'Patients',
          color: const Color(0xFF6366F1),
          onTap: () {
            if (widget.onNavigateToClinics != null) {
              widget.onNavigateToClinics!();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _DoctorClinicsTab(currentUser: user),
                ),
              );
            }
          },
        ),
        _Action(
          icon: Icons.medical_information_rounded,
          label: 'Records',
          color: const Color(0xFF10B981),
          onTap: () => _openDoctorRecords(context),
        ),
      ];
    } else {
      // Technician
      return [];
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
                            'Hello, ${user.username}',
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
                              horizontal: 10,
                              vertical: 4,
                            ),
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async {
                    await Future.wait([
                      context.read<AuthProvider>().refreshUser(),
                      if (user.userRole.roleName.toUpperCase() == 'DOCTOR')
                        _doctorKey.currentState?.fetchStats() ?? Future.value(),
                      if (user.userRole.roleName.toUpperCase() ==
                          'TECHNICIAN')
                        _techKey.currentState?.fetchStats() ?? Future.value(),
                    ]);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    children: [
                      if (user.userRole.roleName.toUpperCase() == 'DOCTOR') ...[
                        _DoctorStatsPanel(
                          key: _doctorKey,
                          currentUser: user,
                          onNavigateToClinics: widget.onNavigateToClinics,
                          onOpenRecords: () => _openDoctorRecords(context),
                        ),
                        const SizedBox(height: 28),
                      ],
                      if (user.userRole.roleName.toUpperCase() ==
                          'TECHNICIAN') ...[
                        _TechnicianStatsPanel(
                          key: _techKey,
                          currentUser: user,
                          onNavigateToLabTests: widget.onNavigateToLabTests,
                        ),
                        const SizedBox(height: 28),
                      ],
                      if (actions.isNotEmpty) ...[
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
                      ],

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

// ── Doctor stats panel ─────────────────────────────────────────────────────────

class _DoctorStatsPanel extends StatefulWidget {
  final User currentUser;
  final VoidCallback? onNavigateToClinics;
  final VoidCallback? onOpenRecords;

  const _DoctorStatsPanel({
    super.key,
    required this.currentUser,
    this.onNavigateToClinics,
    this.onOpenRecords,
  });

  @override
  State<_DoctorStatsPanel> createState() => _DoctorStatsPanelState();
}

class _DoctorStatsPanelState extends State<_DoctorStatsPanel> {
  bool _loading = true;
  int _totalPatients = 0;
  int _totalClinics = 0;
  int _scheduledClinics = 0;
  int _totalConsultations = 0;

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final results = await Future.wait([
        UserApiService.getDoctorProfile(widget.currentUser.id)
            .catchError((_) => null),
        ClinicApiService.getAllClinicDoctors()
            .catchError((_) => <dynamic>[]),
        ClinicApiService.getAllClinics()
            .catchError((_) => <dynamic>[]),
        ConsultationApiService.list(doctorId: widget.currentUser.id)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      final doctorProfile = results[0] as Map<String, dynamic>?;
      final allClinicDoctors = results[1] as List<dynamic>;
      final allClinics = results[2] as List<dynamic>;
      final consultations = results[3] as List<Map<String, dynamic>>;

      final doctorRefId = doctorProfile?['id'];
      final userId = widget.currentUser.id;

      final myClinicIds = <int>{};
      for (final cd in allClinicDoctors) {
        if (cd is! Map) continue;
        final refId =
            cd['doctorRefId'] ?? cd['doctor_ref_id'] ?? cd['doctorId'];
        final isMatch = (doctorRefId != null && refId == doctorRefId) ||
            (refId == userId);
        if (isMatch) {
          final clinicObj = cd['clinic'];
          if (clinicObj is Map && clinicObj['id'] is int) {
            myClinicIds.add(clinicObj['id'] as int);
          } else if (cd['clinicId'] is int) {
            myClinicIds.add(cd['clinicId'] as int);
          } else if (cd['clinic_id'] is int) {
            myClinicIds.add(cd['clinic_id'] as int);
          }
        }
      }

      final myClinics = allClinics.where((c) {
        if (c is! Map) return false;
        final id = c['id'];
        return id is int && myClinicIds.contains(id);
      }).toList();

      final uniquePatientIds = <dynamic>{};
      for (final cons in consultations) {
        final pid = cons['patientId'];
        if (pid != null) uniquePatientIds.add(pid);
      }

      setState(() {
        _totalClinics = myClinics.length;
        _scheduledClinics = myClinics
            .where((c) => (c as Map<String, dynamic>)['status'] == 'SCHEDULED')
            .length;
        _totalConsultations = consultations.length;
        _totalPatients = uniquePatientIds.length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
        onTap: widget.onNavigateToClinics,
      ),
      _StatItem(
        label: 'Total Clinics',
        value: _totalClinics,
        icon: Icons.calendar_today_outlined,
        color: const Color(0xFFF59E0B),
        onTap: widget.onNavigateToClinics,
      ),
      _StatItem(
        label: 'Scheduled Clinics',
        value: _scheduledClinics,
        icon: Icons.event_available_outlined,
        color: const Color(0xFF6366F1),
        onTap: widget.onNavigateToClinics,
      ),
      _StatItem(
        label: 'Prescriptions',
        value: _totalConsultations,
        icon: Icons.description_outlined,
        color: const Color(0xFF10B981),
        onTap: widget.onOpenRecords,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: stats
              .map((item) => _StatCard(item: item, loading: _loading))
              .toList(),
        ),
      ],
    );
  }
}

// ── Technician stats panel ───────────────────────────────────────────────────

class _TechnicianStatsPanel extends StatefulWidget {
  final User currentUser;
  final void Function(String? filter)? onNavigateToLabTests;

  const _TechnicianStatsPanel({
    super.key,
    required this.currentUser,
    this.onNavigateToLabTests,
  });

  @override
  State<_TechnicianStatsPanel> createState() => _TechnicianStatsPanelState();
}

class _TechnicianStatsPanelState extends State<_TechnicianStatsPanel> {
  bool _loading = true;
  int _total = 0;
  int _pending = 0;
  int _inProgress = 0;
  int _completed = 0;

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final tests = await LabTestApiService.list(
        size: 1000,
      ).catchError((_) => <Map<String, dynamic>>[]);

      if (!mounted) return;

      int pendingCount = 0;
      int inProgressCount = 0;
      int completedCount = 0;

      for (final t in tests) {
        final status = (t['status']?.toString() ?? 'PENDING').toUpperCase();
        if (status == 'COMPLETED') {
          completedCount++;
        } else if (status == 'IN_PROGRESS') {
          inProgressCount++;
        } else if (status == 'CANCELLED') {
          // cancelled tests
        } else {
          pendingCount++;
        }
      }

      setState(() {
        _total = tests.length;
        _pending = pendingCount;
        _inProgress = inProgressCount;
        _completed = completedCount;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(
        label: 'Total Tests',
        value: _total,
        icon: Icons.science_outlined,
        color: AppTheme.primary,
        onTap: () => widget.onNavigateToLabTests?.call('ALL'),
      ),
      _StatItem(
        label: 'Pending',
        value: _pending,
        icon: Icons.hourglass_empty_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () => widget.onNavigateToLabTests?.call('PENDING'),
      ),
      _StatItem(
        label: 'In Progress',
        value: _inProgress,
        icon: Icons.autorenew_rounded,
        color: const Color(0xFF6366F1),
        onTap: () => widget.onNavigateToLabTests?.call('IN_PROGRESS'),
      ),
      _StatItem(
        label: 'Completed',
        value: _completed,
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF10B981),
        onTap: () => widget.onNavigateToLabTests?.call('COMPLETED'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: stats
              .map((item) => _StatCard(item: item, loading: _loading))
              .toList(),
        ),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  final bool loading;
  const _StatCard({required this.item, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color, size: 18),
                  ),
                  if (item.onTap != null)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: AppTheme.textHint.withValues(alpha: 0.8),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              loading
                  ? Container(
                      width: 44,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.border.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : Text(
                      item.value.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action model ──────────────────────────────────────────────────────────────

class _DoctorClinicsPanel extends StatefulWidget {
  final User currentUser;

  const _DoctorClinicsPanel({required this.currentUser});

  @override
  State<_DoctorClinicsPanel> createState() => _DoctorClinicsPanelState();
}

class _DoctorClinicsPanelState extends State<_DoctorClinicsPanel> {
  static const _statuses = [
    'All',
    'SCHEDULED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED',
  ];

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _clinics = [];
  bool _loading = true;
  String? _error;
  int? _selectedClinicId;
  String _search = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClinics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        UserApiService.getDoctorProfile(widget.currentUser.id)
            .catchError((_) => null),
        ClinicApiService.getAllClinicDoctors()
            .catchError((_) => <dynamic>[]),
        ClinicApiService.getAllClinics()
            .catchError((_) => <dynamic>[]),
      ]);

      if (!mounted) return;

      final doctorProfile = results[0] as Map<String, dynamic>?;
      final allClinicDoctors = results[1] as List<dynamic>;
      final allClinics = results[2] as List<dynamic>;

      final doctorRefId = doctorProfile?['id'];
      final userId = widget.currentUser.id;

      // Extract clinic IDs assigned to this doctor (matching doctorRefId or userId)
      final myClinicIds = <int>{};
      for (final cd in allClinicDoctors) {
        if (cd is! Map) continue;
        final refId =
            cd['doctorRefId'] ?? cd['doctor_ref_id'] ?? cd['doctorId'];
        final isMatch = (doctorRefId != null && refId == doctorRefId) ||
            (refId == userId);
        if (isMatch) {
          final clinicObj = cd['clinic'];
          if (clinicObj is Map && clinicObj['id'] is int) {
            myClinicIds.add(clinicObj['id'] as int);
          } else if (cd['clinicId'] is int) {
            myClinicIds.add(cd['clinicId'] as int);
          } else if (cd['clinic_id'] is int) {
            myClinicIds.add(cd['clinic_id'] as int);
          }
        }
      }

      // Filter allClinics to only those assigned to this doctor
      final assignedClinics = allClinics
          .whereType<Map>()
          .where((clinic) => myClinicIds.contains(clinic['id']))
          .map((clinic) => Map<String, dynamic>.from(clinic))
          .toList();

      setState(() {
        _clinics = assignedClinics;
        if (_selectedClinicId != null &&
            !_clinics.any((c) => c['id'] == _selectedClinicId)) {
          _selectedClinicId = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredClinics {
    final query = _search.toLowerCase().trim();
    return _clinics.where((clinic) {
      final selectedMatch =
          _selectedClinicId == null || clinic['id'] == _selectedClinicId;
      final status = (clinic['status'] ?? '').toString();
      final statusMatch = _statusFilter == 'All' || status == _statusFilter;
      final searchableText = [
        clinic['clinicName'],
        clinic['province'],
        clinic['district'],
        clinic['location'],
      ].where((value) => value != null).join(' ').toLowerCase();
      final searchMatch = query.isEmpty || searchableText.contains(query);
      return selectedMatch && statusMatch && searchMatch;
    }).toList();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _selectedClinicId = null;
      _search = '';
      _statusFilter = 'All';
    });
  }

  Future<void> _openQueue(Map<String, dynamic> clinic) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ClinicQueueSheet(clinic: clinic, currentUser: widget.currentUser),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredClinics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Clinic Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: _loadClinics,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: AppTheme.primary,
              tooltip: 'Refresh clinics',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Clinic',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: ValueKey(_selectedClinicId),
                initialValue: _selectedClinicId,
                isExpanded: true,
                hint: Text(
                  _loading
                      ? 'Loading your clinics...'
                      : _clinics.isEmpty
                          ? 'You are not assigned to any clinics yet.'
                          : 'Choose clinic...',
                  overflow: TextOverflow.ellipsis,
                ),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: _clinics
                    .map((clinic) {
                      final id = clinic['id'];
                      if (id is! int) return null;
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          (clinic['clinicName'] ?? 'Unnamed Clinic').toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: _loading || _clinics.isEmpty
                    ? null
                    : (value) => setState(() => _selectedClinicId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: 'Search by name or location...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _statuses
                      .map(
                        (status) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              status == 'All' ? 'All Status' : status,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _statusFilter == status,
                            onSelected: (_) =>
                                setState(() => _statusFilter = status),
                            selectedColor: AppTheme.primaryLight,
                            checkmarkColor: AppTheme.primary,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: _statusFilter == status
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontWeight: _statusFilter == status
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _PanelMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Failed to load clinics',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadClinics,
                )
              else if (filtered.isEmpty)
                _PanelMessage(
                  icon: Icons.event_busy_rounded,
                  title: _clinics.isEmpty
                      ? 'No Assigned Clinics'
                      : 'No clinics found',
                  message: _clinics.isEmpty
                      ? 'You are not assigned to any clinics yet. Please contact an administrator.'
                      : 'Adjust the clinic, search, or status filter.',
                  actionLabel: _clinics.isEmpty ? 'Refresh' : 'Clear Filters',
                  onAction: _clinics.isEmpty ? _loadClinics : _clearFilters,
                )
              else
                Column(
                  children: filtered
                      .map(
                        (clinic) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DoctorClinicCard(
                            clinic: clinic,
                            onTap: () => _openQueue(clinic),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoctorClinicCard extends StatefulWidget {
  final Map<String, dynamic> clinic;
  final VoidCallback onTap;

  const _DoctorClinicCard({required this.clinic, required this.onTap});

  @override
  State<_DoctorClinicCard> createState() => _DoctorClinicCardState();
}

class _DoctorClinicCardState extends State<_DoctorClinicCard> {
  List<Map<String, dynamic>> _doctors = [];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void didUpdateWidget(covariant _DoctorClinicCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clinic['id'] != widget.clinic['id']) {
      _loadDoctors();
    }
  }

  Future<void> _loadDoctors() async {
    final id = widget.clinic['id'];
    if (id is! int) return;
    try {
      final data = await ClinicApiService.getClinicDoctorsByClinicId(id);
      if (!mounted) return;
      setState(() {
        _doctors = data
            .whereType<Map>()
            .map((doctor) => Map<String, dynamic>.from(doctor))
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _doctors = []);
    }
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final parts = raw.split('-');
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${parts[2]} ${months[int.parse(parts[1]) - 1]} ${parts[0]}';
    } catch (_) {
      return raw;
    }
  }

  static String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final parts = raw.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1].padLeft(2, '0');
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      return '$hour12:$minute $suffix';
    } catch (_) {
      return raw;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'SCHEDULED':
        return const Color(0xFF3B82F6);
      case 'IN_PROGRESS':
        return AppTheme.primary;
      case 'COMPLETED':
        return AppTheme.success;
      case 'CANCELLED':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinic = widget.clinic;
    final status = (clinic['status'] ?? 'SCHEDULED').toString();
    final statusColor = _statusColor(status);
    final location = (clinic['location'] ?? '').toString();

    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (clinic['clinicName'] ?? 'Unnamed Clinic').toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.location_on_outlined,
                text:
                    '${clinic['district'] ?? '-'} - ${clinic['province'] ?? '-'}',
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 4),
                _InfoLine(icon: Icons.place_outlined, text: location),
              ],
              const SizedBox(height: 4),
              _InfoLine(
                icon: Icons.schedule_rounded,
                text:
                    '${_formatDate(clinic['scheduledDate']?.toString())} at ${_formatTime(clinic['scheduledTime']?.toString())}',
              ),
              if (_doctors.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _doctors.map((doctor) {
                    final name = (doctor['doctorName'] ?? 'Assigned Doctor')
                        .toString();
                    final specialization = (doctor['specialization'] ?? '')
                        .toString();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        specialization.isEmpty
                            ? name
                            : '$name - $specialization',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 15,
                    color: AppTheme.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Tap to view queue',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'SCHEDULED':
      return const Color(0xFF3B82F6);
    case 'IN_PROGRESS':
    case 'SERVING':
      return AppTheme.primary;
    case 'COMPLETED':
      return AppTheme.success;
    case 'CANCELLED':
      return AppTheme.error;
    case 'PENDING':
      return const Color(0xFFF59E0B);
    default:
      return AppTheme.textSecondary;
  }
}

String _formatDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
  final date =
      '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  return '$date $hour:$minute $suffix';
}

class _ConsultationRecordsSheet extends StatefulWidget {
  final User currentUser;
  final int? patientId;
  final int? doctorId;
  final String title;
  final bool showDoctorAsPrimary;
  final bool allowManage;

  const _ConsultationRecordsSheet({
    required this.currentUser,
    required this.patientId,
    required this.doctorId,
    required this.title,
    required this.showDoctorAsPrimary,
    this.allowManage = false,
  });

  @override
  State<_ConsultationRecordsSheet> createState() =>
      _ConsultationRecordsSheetState();
}

class _ConsultationRecordsSheetState extends State<_ConsultationRecordsSheet> {
  List<Map<String, dynamic>> _consultations = [];
  final Map<int, String> _patientNames = {};
  final Map<int, String> _clinicNames = {};
  final Map<int, String> _doctorNames = {};
  bool _loading = true;
  String? _error;
  final Set<int> _selectedIds = {};
  final _editChiefCtrl = TextEditingController();
  final _editPresentCtrl = TextEditingController();
  final _editPastCtrl = TextEditingController();
  final _editRecomCtrl = TextEditingController();
  bool _savingEdit = false;
  int? _deletingId;
  bool _bulkDeleting = false;

  @override
  void dispose() {
    _editChiefCtrl.dispose();
    _editPresentCtrl.dispose();
    _editPastCtrl.dispose();
    _editRecomCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ConsultationApiService.list(
        patientId: widget.patientId,
        doctorId: widget.doctorId,
        page: 0,
        size: 100,
      );
      await _hydrateNames(data);
      if (!mounted) return;
      setState(() {
        _consultations = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _hydrateNames(List<Map<String, dynamic>> consultations) async {
    final patientIds = consultations
        .map((row) => _asInt(row['patientId']))
        .whereType<int>()
        .where((id) => !_patientNames.containsKey(id))
        .toSet();
    final clinicIds = consultations
        .map((row) => _asInt(row['clinicId']))
        .whereType<int>()
        .where((id) => !_clinicNames.containsKey(id))
        .toSet();
    final doctorIds = consultations
        .map((row) => _asInt(row['doctorId']))
        .whereType<int>()
        .where((id) => !_doctorNames.containsKey(id))
        .toSet();

    for (final id in patientIds) {
      try {
        final profile = await UserApiService.getPatientProfile(id);
        final firstName = profile?['firstName']?.toString() ?? '';
        final lastName = profile?['lastName']?.toString() ?? '';
        final name = [
          firstName,
          lastName,
        ].where((part) => part.trim().isNotEmpty).join(' ');
        if (name.isNotEmpty) {
          _patientNames[id] = name;
          continue;
        }
      } catch (_) {}

      try {
        final user = await UserApiService.getUserById(id);
        _patientNames[id] = user.username.isNotEmpty
            ? user.username
            : 'Patient #$id';
      } catch (_) {
        _patientNames[id] = 'Patient #$id';
      }
    }

    for (final id in clinicIds) {
      try {
        final clinic = await ClinicApiService.getClinicById(id);
        _clinicNames[id] = (clinic['clinicName'] ?? 'Clinic #$id').toString();
      } catch (_) {
        _clinicNames[id] = 'Clinic #$id';
      }
    }

    for (final id in doctorIds) {
      try {
        final profile = await UserApiService.getDoctorProfile(id);
        final firstName = profile?['firstName']?.toString() ?? '';
        final lastName = profile?['lastName']?.toString() ?? '';
        final name = [
          firstName,
          lastName,
        ].where((part) => part.trim().isNotEmpty).join(' ');
        if (name.isNotEmpty) {
          _doctorNames[id] = name;
          continue;
        }
      } catch (_) {}

      try {
        final user = await UserApiService.getUserById(id);
        _doctorNames[id] = user.username.isNotEmpty
            ? user.username
            : 'Doctor #$id';
      } catch (_) {
        _doctorNames[id] = 'Doctor #$id';
      }
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _patientName(Map<String, dynamic> consultation) {
    final id = _asInt(consultation['patientId']);
    if (id == null) return 'Patient';
    return _patientNames[id] ?? 'Patient #$id';
  }

  String _clinicName(Map<String, dynamic> consultation) {
    final id = _asInt(consultation['clinicId']);
    if (id == null) return 'Clinic';
    return _clinicNames[id] ?? 'Clinic #$id';
  }

  String _doctorName(Map<String, dynamic> consultation) {
    final id = _asInt(consultation['doctorId']);
    if (id == null) return 'Doctor';
    return _doctorNames[id] ?? 'Doctor #$id';
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final allIds = _consultations
          .map((c) => _asInt(c['id']))
          .whereType<int>()
          .toSet();
      if (allIds.every((id) => _selectedIds.contains(id))) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  Future<void> _openEdit(Map<String, dynamic> consultation) async {
    final id = _asInt(consultation['id']);
    if (id == null) return;
    _editChiefCtrl.text = (consultation['chiefComplaint'] ?? '').toString();
    _editPresentCtrl.text = (consultation['presentIllness'] ?? '').toString();
    _editPastCtrl.text = (consultation['pastMedicalHistory'] ?? '').toString();
    _editRecomCtrl.text = (consultation['recommendations'] ?? '').toString();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Consultation #$id'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetField(
                      controller: _editChiefCtrl,
                      label: 'Chief Complaint',
                      hint: 'Enter chief complaint',
                    ),
                    _SheetField(
                      controller: _editPresentCtrl,
                      label: 'Present Illness',
                      hint: 'Enter present illness',
                      maxLines: 3,
                    ),
                    _SheetField(
                      controller: _editPastCtrl,
                      label: 'Past Medical History',
                      hint: 'Enter past medical history',
                      maxLines: 3,
                    ),
                    _SheetField(
                      controller: _editRecomCtrl,
                      label: 'Recommendations',
                      hint: 'Enter recommendations',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _savingEdit
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _savingEdit
                      ? null
                      : () async {
                          setDialogState(() => _savingEdit = true);
                          try {
                            final updated = await ConsultationApiService.update(id, {
                              'chiefComplaint': _editChiefCtrl.text.trim(),
                              'presentIllness': _editPresentCtrl.text.trim(),
                              'pastMedicalHistory': _editPastCtrl.text.trim(),
                              'recommendations': _editRecomCtrl.text.trim(),
                            });
                            if (mounted) {
                              setState(() {
                                final index = _consultations.indexWhere(
                                  (c) => _asInt(c['id']) == id,
                                );
                                if (index != -1) _consultations[index] = updated;
                                _savingEdit = false;
                              });
                            }
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                            _showSnack('Consultation updated', success: true);
                          } catch (e) {
                            setDialogState(() => _savingEdit = false);
                            _showSnack('Failed to update: $e', success: false);
                          }
                        },
                  child: _savingEdit
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteOne(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete consultation?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingId = id);
    try {
      await ConsultationApiService.delete(id);
      if (!mounted) return;
      setState(() {
        _consultations.removeWhere((c) => _asInt(c['id']) == id);
        _selectedIds.remove(id);
        _deletingId = null;
      });
      _showSnack('Consultation deleted', success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingId = null);
      _showSnack('Failed to delete: $e', success: false);
    }
  }

  Future<void> _bulkDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${ids.length} selected consultation${ids.length > 1 ? 's' : ''}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _bulkDeleting = true);
    try {
      await ConsultationApiService.bulkDelete(ids);
      if (!mounted) return;
      setState(() {
        _consultations.removeWhere((c) => _selectedIds.contains(_asInt(c['id'])));
        _selectedIds.clear();
        _bulkDeleting = false;
      });
      _showSnack('${ids.length} consultation${ids.length > 1 ? 's' : ''} deleted', success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bulkDeleting = false);
      _showSnack('Failed to delete: $e', success: false);
    }
  }

  void _showSnack(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _openDetails(Map<String, dynamic> consultation) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConsultationRecordDetailSheet(
        consultation: consultation,
        patientName: _patientName(consultation),
        clinicName: _clinicName(consultation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_consultations.length} records',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.allowManage && _consultations.isNotEmpty)
                      IconButton(
                        onPressed: _toggleSelectAll,
                        icon: Icon(
                          _selectedIds.isNotEmpty &&
                                  _selectedIds.length == _consultations.length
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                        ),
                        color: AppTheme.primary,
                        tooltip: 'Select all',
                      ),
                    IconButton(
                      onPressed: _loadRecords,
                      icon: const Icon(Icons.refresh_rounded),
                      color: AppTheme.primary,
                      tooltip: 'Refresh records',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AppTheme.textSecondary,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              if (widget.allowManage && _selectedIds.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} selected',
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _bulkDeleting ? null : _bulkDelete,
                        icon: _bulkDeleting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline_rounded, size: 18),
                        label: Text(_bulkDeleting ? 'Deleting...' : 'Delete Selected'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadRecords,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            _PanelMessage(
                              icon: Icons.cloud_off_rounded,
                              title: 'Failed to load records',
                              message: _error!,
                              actionLabel: 'Retry',
                              onAction: _loadRecords,
                            ),
                          ],
                        )
                      : _consultations.isEmpty
                      ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: const [_RecordsEmptyState()],
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _consultations.length,
                          itemBuilder: (_, index) {
                            final consultation = _consultations[index];
                            final id = _asInt(consultation['id']);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ConsultationRecordCard(
                                consultation: consultation,
                                primaryName: widget.showDoctorAsPrimary
                                    ? _doctorName(consultation)
                                    : _patientName(consultation),
                                clinicName: _clinicName(consultation),
                                onTap: () => _openDetails(consultation),
                                allowManage: widget.allowManage,
                                selected: id != null && _selectedIds.contains(id),
                                onToggleSelect: id == null
                                    ? null
                                    : () => _toggleSelect(id),
                                onEdit: () => _openEdit(consultation),
                                deleting: id != null && _deletingId == id,
                                onDelete: id == null
                                    ? null
                                    : () => _deleteOne(id),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConsultationRecordCard extends StatelessWidget {
  final Map<String, dynamic> consultation;
  final String primaryName;
  final String clinicName;
  final VoidCallback onTap;
  final bool allowManage;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onEdit;
  final bool deleting;
  final VoidCallback? onDelete;

  const _ConsultationRecordCard({
    required this.consultation,
    required this.primaryName,
    required this.clinicName,
    required this.onTap,
    this.allowManage = false,
    this.selected = false,
    this.onToggleSelect,
    this.onEdit,
    this.deleting = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = (consultation['status'] ?? 'SCHEDULED').toString();
    final statusColor = _statusColor(status);
    final chiefComplaint = (consultation['chiefComplaint'] ?? '-').toString();

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (allowManage && onToggleSelect != null) ...[
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onToggleSelect!(),
                      activeColor: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.medical_information_rounded,
                      color: AppTheme.success,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clinicName,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: status, color: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              _InfoLine(icon: Icons.sick_outlined, text: chiefComplaint),
              const SizedBox(height: 6),
              _InfoLine(
                icon: Icons.calendar_today_outlined,
                text: _formatDateTime(consultation['bookedAt']?.toString()),
              ),
              if (allowManage) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                    ),
                    TextButton.icon(
                      onPressed: deleting ? null : onDelete,
                      icon: deleting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text(deleting ? 'Deleting...' : 'Delete'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsultationRecordDetailSheet extends StatefulWidget {
  final Map<String, dynamic> consultation;
  final String patientName;
  final String clinicName;

  const _ConsultationRecordDetailSheet({
    required this.consultation,
    required this.patientName,
    required this.clinicName,
  });

  @override
  State<_ConsultationRecordDetailSheet> createState() =>
      _ConsultationRecordDetailSheetState();
}

class _ConsultationRecordDetailSheetState
    extends State<_ConsultationRecordDetailSheet> {
  List<Map<String, dynamic>> _labTests = [];
  bool _loadingTests = true;

  @override
  void initState() {
    super.initState();
    _loadLabTests();
  }

  Future<void> _loadLabTests() async {
    final id = _asInt(widget.consultation['id']);
    if (id == null) {
      setState(() => _loadingTests = false);
      return;
    }

    try {
      final tests = await LabTestApiService.getByConsultation(id);
      if (!mounted) return;
      setState(() {
        _labTests = tests;
        _loadingTests = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTests = false);
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consultation;
    final status = (c['status'] ?? 'SCHEDULED').toString();
    final statusColor = _statusColor(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.62,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'Consultation Details',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatusBadge(status: status, color: statusColor),
              const SizedBox(height: 16),
              _DetailRow(label: 'Patient', value: widget.patientName),
              _DetailRow(label: 'Clinic', value: widget.clinicName),
              _DetailRow(
                label: 'Session',
                value: (c['sessionNumber'] ?? '-').toString(),
              ),
              _DetailRow(
                label: 'Booked At',
                value: _formatDateTime(c['bookedAt']?.toString()),
              ),
              _DetailRow(
                label: 'Completed At',
                value: _formatDateTime(c['completedAt']?.toString()),
              ),
              _DetailBlock(
                label: 'Chief Complaint',
                value: (c['chiefComplaint'] ?? '-').toString(),
              ),
              _DetailBlock(
                label: 'Past Medical History',
                value: (c['pastMedicalHistory'] ?? '-').toString(),
              ),
              _DetailBlock(
                label: 'Present Illness',
                value: (c['presentIllness'] ?? '-').toString(),
              ),
              _DetailBlock(
                label: 'Recommendations',
                value: (c['recommendations'] ?? '-').toString(),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Lab Tests',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loadingTests)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_labTests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No lab tests requested for this consultation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ..._labTests.map(
                  (test) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LabTestRecordCard(test: test),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LabTestRecordCard extends StatelessWidget {
  final Map<String, dynamic> test;
  final Map<String, dynamic>? result;

  const _LabTestRecordCard({required this.test, this.result});

  @override
  Widget build(BuildContext context) {
    final rawStatus = (test['status'] ?? 'PENDING').toString();
    final status =
        (rawStatus == 'PENDING' || rawStatus == 'IN_PROGRESS') &&
            result != null
        ? 'COMPLETED'
        : rawStatus;
    final statusColor = _statusColor(status);
    final resultDescription = (result?['testResultDescription'] ?? '')
        .toString();
    final technicianNotes = (result?['technicianNotes'] ?? '').toString();
    final List<String> resultFiles = [];
    if (result?['files'] is List) {
      for (final f in (result!['files'] as List)) {
        if (f is Map && f['fileName'] != null) {
          resultFiles.add(f['fileName'].toString());
        }
      }
    }
    if (resultFiles.isEmpty && (result?['fileName'] ?? '').toString().isNotEmpty) {
      resultFiles.add(result!['fileName'].toString());
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.science_outlined,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (test['testName'] ?? 'Lab Test').toString(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              _StatusBadge(status: status, color: statusColor),
            ],
          ),
          if ((test['testDescription'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              test['testDescription'].toString(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if ((test['testInstructions'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailBlock(
              label: 'Instructions',
              value: test['testInstructions'].toString(),
              compact: true,
            ),
          ],
          if (resultDescription.isNotEmpty ||
              (test['testResults'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailBlock(
              label: 'Results',
              value: resultDescription.isNotEmpty
                  ? resultDescription
                  : test['testResults'].toString(),
              compact: true,
            ),
          ],
          if (technicianNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailBlock(
              label: 'Technician Notes',
              value: technicianNotes,
              compact: true,
            ),
          ],
          if (resultFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: resultFiles.map((fn) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.attach_file_rounded,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      fn,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;

  const _DetailBlock({
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsEmptyState extends StatelessWidget {
  const _RecordsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.medical_information_rounded,
              color: AppTheme.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No consultation records',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Completed and scheduled consultations will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ClinicQueueSheet extends StatefulWidget {
  final Map<String, dynamic> clinic;
  final User currentUser;

  const _ClinicQueueSheet({required this.clinic, required this.currentUser});

  @override
  State<_ClinicQueueSheet> createState() => _ClinicQueueSheetState();
}

class _ClinicQueueSheetState extends State<_ClinicQueueSheet> {
  List<Map<String, dynamic>> _tokens = [];
  final Map<String, String> _patientNames = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final clinicId = widget.clinic['id'].toString();
      final data = await QueueApiService.getClinicQueue(clinicId);
      final tokens = data
          .whereType<Map>()
          .map((token) => Map<String, dynamic>.from(token))
          .toList();
      await _hydratePatientNames(tokens);
      if (!mounted) return;
      setState(() {
        _tokens = tokens;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _hydratePatientNames(List<Map<String, dynamic>> tokens) async {
    final ids = tokens
        .map((token) => token['patientId']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty && !_patientNames.containsKey(id))
        .toSet();

    for (final id in ids) {
      final numericId = int.tryParse(id);
      if (numericId == null) {
        _patientNames[id] = 'User #$id';
        continue;
      }

      try {
        final profile = await UserApiService.getPatientProfile(numericId);
        final firstName = profile?['firstName']?.toString() ?? '';
        final lastName = profile?['lastName']?.toString() ?? '';
        final name = [
          firstName,
          lastName,
        ].where((part) => part.trim().isNotEmpty).join(' ');
        if (name.isNotEmpty) {
          _patientNames[id] = name;
          continue;
        }
      } catch (_) {}

      try {
        final user = await UserApiService.getUserById(numericId);
        _patientNames[id] = user.username.isNotEmpty
            ? user.username
            : 'User #$id';
      } catch (_) {
        _patientNames[id] = 'User #$id';
      }
    }
  }

  String _patientName(Map<String, dynamic> token) {
    final patientId = token['patientId']?.toString() ?? '';
    return _patientNames[patientId] ?? 'User #$patientId';
  }

  Future<void> _openConsultation(Map<String, dynamic> token) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConsultationSheet(
        clinic: widget.clinic,
        token: token,
        patientName: _patientName(token),
        currentUser: widget.currentUser,
      ),
    );

    if (saved == true) {
      await _loadQueue();
    }
  }

  void _viewPatientProfile(Map<String, dynamic> token) {
    final patientId = int.tryParse(token['patientId']?.toString() ?? '');
    if (patientId == null) return;
    showDialog(
      context: context,
      builder: (_) => _PatientProfileDialog(patientId: patientId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinicName = (widget.clinic['clinicName'] ?? 'Clinic Queue')
        .toString();

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Text(
                            clinicName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_tokens.length} waiting patients',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadQueue,
                      icon: const Icon(Icons.refresh_rounded),
                      color: AppTheme.primary,
                      tooltip: 'Refresh queue',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AppTheme.textSecondary,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadQueue,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            _PanelMessage(
                              icon: Icons.cloud_off_rounded,
                              title: 'Failed to load queue',
                              message: _error!,
                              actionLabel: 'Retry',
                              onAction: _loadQueue,
                            ),
                          ],
                        )
                      : _tokens.isEmpty
                      ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: const [_QueueEmptyState()],
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _tokens.length,
                          itemBuilder: (_, index) {
                            final token = _tokens[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _QueuePatientCard(
                                token: token,
                                patientName: _patientName(token),
                                onConsult: () => _openConsultation(token),
                                onViewProfile: () => _viewPatientProfile(token),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QueuePatientCard extends StatelessWidget {
  final Map<String, dynamic> token;
  final String patientName;
  final VoidCallback onConsult;
  final VoidCallback onViewProfile;

  const _QueuePatientCard({
    required this.token,
    required this.patientName,
    required this.onConsult,
    required this.onViewProfile,
  });

  static String _formatIssued(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final status = (token['status'] ?? 'PENDING').toString();
    final tokenNumber = token['tokenNumber']?.toString() ?? '-';
    final isCompleted = status == 'COMPLETED';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Center(
                  child: Text(
                    tokenNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _InfoLine(
                      icon: Icons.schedule_rounded,
                      text:
                          'Issued ${_formatIssued(token['issuedAt']?.toString())}',
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewProfile,
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isCompleted ? null : onConsult,
                  icon: const Icon(
                    Icons.medical_information_rounded,
                    size: 18,
                  ),
                  label: Text(isCompleted ? 'Completed' : 'Consult'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Patient profile dialog ───────────────────────────────────────────────────

class _PatientProfileDialog extends StatefulWidget {
  final int patientId;
  const _PatientProfileDialog({required this.patientId});

  @override
  State<_PatientProfileDialog> createState() => _PatientProfileDialogState();
}

class _PatientProfileDialogState extends State<_PatientProfileDialog> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await UserApiService.getPatientProfile(widget.patientId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static int? _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return null;
    final dob = DateTime.tryParse(dateOfBirth);
    if (dob == null) return null;
    final today = DateTime.now();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: _PanelMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Failed to load profile',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
              )
            : _profile == null
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No profile data available'),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Patient Profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: Text(
                              [
                                _profile!['firstName'],
                                _profile!['lastName'],
                              ].whereType<String>().where((s) => s.isNotEmpty).map((s) => s[0]).join().toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              '${_profile!['firstName'] ?? ''} ${_profile!['lastName'] ?? ''}'.trim(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date of Birth',
                      value: () {
                        final dob = _profile!['dateOfBirth']?.toString();
                        final age = _calculateAge(dob);
                        if (dob == null || dob.isEmpty) return '-';
                        return age != null ? '$dob ($age years old)' : dob;
                      }(),
                    ),
                    _ProfileInfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Gender',
                      value: (_profile!['gender'] ?? '-').toString(),
                    ),
                    if ((_profile!['bloodGroup'] ?? '').toString().isNotEmpty)
                      _ProfileInfoRow(
                        icon: Icons.bloodtype_outlined,
                        label: 'Blood Group',
                        value: _profile!['bloodGroup'].toString(),
                      ),
                    _ProfileInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone Number',
                      value: (_profile!['phoneNumber'] ?? '-').toString(),
                    ),
                    _ProfileInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: (_profile!['address'] ?? '-').toString(),
                    ),
                    _ProfileInfoRow(
                      icon: Icons.phone_in_talk_outlined,
                      label: 'Emergency Contact',
                      value: (_profile!['emergencyContact'] ?? '-').toString(),
                    ),
                    if ((_profile!['allergies'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _DetailBlock(
                        label: 'Allergies',
                        value: _profile!['allergies'].toString(),
                      ),
                    ],
                    if ((_profile!['chronicDiseases'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _DetailBlock(
                        label: 'Chronic Conditions',
                        value: _profile!['chronicDiseases'].toString(),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
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

class _ConsultationSheet extends StatefulWidget {
  final Map<String, dynamic> clinic;
  final Map<String, dynamic> token;
  final String patientName;
  final User currentUser;

  const _ConsultationSheet({
    required this.clinic,
    required this.token,
    required this.patientName,
    required this.currentUser,
  });

  @override
  State<_ConsultationSheet> createState() => _ConsultationSheetState();
}

class _ConsultationSheetState extends State<_ConsultationSheet> {
  final _chiefCtrl = TextEditingController();
  final _pastCtrl = TextEditingController();
  final _presentCtrl = TextEditingController();
  final _recomCtrl = TextEditingController();
  final _sessionCtrl = TextEditingController(text: '1');
  final List<_LabTestDraft> _labTests = [];
  bool _requestLabTests = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _chiefCtrl.dispose();
    _pastCtrl.dispose();
    _presentCtrl.dispose();
    _recomCtrl.dispose();
    _sessionCtrl.dispose();
    for (final test in _labTests) {
      test.dispose();
    }
    super.dispose();
  }

  void _toggleLabTests(bool selected) {
    setState(() {
      _requestLabTests = selected;
      if (selected && _labTests.isEmpty) {
        _labTests.add(_LabTestDraft());
      }
      if (!selected) {
        for (final test in _labTests) {
          test.dispose();
        }
        _labTests.clear();
      }
    });
  }

  void _addLabTest() {
    setState(() => _labTests.add(_LabTestDraft()));
  }

  void _removeLabTest(int index) {
    setState(() {
      final test = _labTests.removeAt(index);
      test.dispose();
      if (_labTests.isEmpty) {
        _requestLabTests = false;
      }
    });
  }

  Future<void> _save() async {
    if (_chiefCtrl.text.trim().isEmpty || _recomCtrl.text.trim().isEmpty) {
      setState(
        () => _error = 'Chief complaint and recommendations are required.',
      );
      return;
    }

    if (_requestLabTests) {
      final hasBlankName = _labTests.any(
        (test) => test.nameCtrl.text.trim().isEmpty,
      );
      if (hasBlankName) {
        setState(() => _error = 'Every requested lab test needs a test name.');
        return;
      }
    }

    final patientId = int.tryParse(widget.token['patientId']?.toString() ?? '');
    final clinicId = widget.clinic['id'];
    final tokenId = widget.token['id'];
    if (patientId == null || clinicId is! int || tokenId is! int) {
      setState(
        () => _error = 'Queue token has invalid patient or clinic data.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final consultation = await ConsultationApiService.create({
        'patientId': patientId,
        'doctorId': widget.currentUser.id,
        'clinicId': clinicId,
        'queueTokenId': tokenId,
        'chiefComplaint': _chiefCtrl.text.trim(),
        'pastMedicalHistory': _pastCtrl.text.trim(),
        'presentIllness': _presentCtrl.text.trim(),
        'recommendations': _recomCtrl.text.trim(),
        'sessionNumber': int.tryParse(_sessionCtrl.text.trim()) ?? 1,
        'bookedAt': DateTime.now().toIso8601String(),
      });

      final consultationId = consultation['id'];
      if (consultationId is int) {
        if (_requestLabTests) {
          for (final test in _labTests) {
            await LabTestApiService.create({
              'consultationId': consultationId,
              'testName': test.nameCtrl.text.trim(),
              'testDescription': test.descriptionCtrl.text.trim(),
              'testInstructions': test.instructionsCtrl.text.trim(),
            });
          }
        }
        await ConsultationApiService.updateStatus(
          consultationId,
          'IN_PROGRESS',
        );
        await ConsultationApiService.complete(consultationId);
      }
      await QueueApiService.updateStatus(tokenId, 'COMPLETED');

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Consultation saved'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.65,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create Consultation',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.patientName,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SheetField(
                controller: _chiefCtrl,
                label: 'Chief Complaint *',
                hint: 'Enter chief complaint',
              ),
              _SheetField(
                controller: _pastCtrl,
                label: 'Past Medical History',
                hint: 'Enter past medical history',
                maxLines: 3,
              ),
              _SheetField(
                controller: _presentCtrl,
                label: 'Present Illness',
                hint: 'Enter present illness',
                maxLines: 3,
              ),
              _SheetField(
                controller: _recomCtrl,
                label: 'Recommendations *',
                hint: 'Enter recommendations',
                maxLines: 3,
              ),
              _SheetField(
                controller: _sessionCtrl,
                label: 'Session Number',
                hint: '1',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 4),
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.border),
                    bottom: BorderSide(color: AppTheme.border),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _saving
                          ? null
                          : () => _toggleLabTests(!_requestLabTests),
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _requestLabTests,
                            onChanged: _saving
                                ? null
                                : (value) => _toggleLabTests(value ?? false),
                            activeColor: AppTheme.primary,
                          ),
                          const Icon(
                            Icons.science_outlined,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Request Lab Tests',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_requestLabTests) ...[
                      const SizedBox(height: 12),
                      ...List.generate(_labTests.length, (index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _labTests.length - 1 ? 0 : 12,
                          ),
                          child: _LabTestRequestCard(
                            draft: _labTests[index],
                            canRemove: _labTests.length > 1,
                            onRemove: () => _removeLabTest(index),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _addLabTest,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Another Test'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(
                            color: AppTheme.primary,
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Consultation'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}

class _LabTestDraft {
  final nameCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final instructionsCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
    instructionsCtrl.dispose();
  }
}

class _LabTestRequestCard extends StatelessWidget {
  final _LabTestDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;

  const _LabTestRequestCard({
    required this.draft,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lab Test',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.error,
                tooltip: 'Remove test',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          _SheetField(
            controller: draft.nameCtrl,
            label: 'Test Name *',
            hint: 'e.g., Complete Blood Count, Blood Sugar Test',
          ),
          _SheetField(
            controller: draft.descriptionCtrl,
            label: 'Test Description',
            hint: 'What does this test check for?',
            maxLines: 2,
          ),
          _SheetField(
            controller: draft.instructionsCtrl,
            label: 'Instructions for Technician',
            hint: 'Special instructions or requirements...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _QueueEmptyState extends StatelessWidget {
  const _QueueEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              color: AppTheme.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No patients in queue',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Patients who join this clinic queue will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _PanelMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 34),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

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

// ── Patient Clinics Sheet ─────────────────────────────────────────────────────

class _PatientClinicsSheet extends StatefulWidget {
  final User currentUser;

  const _PatientClinicsSheet({required this.currentUser});

  @override
  State<_PatientClinicsSheet> createState() => _PatientClinicsSheetState();
}

class _PatientClinicsSheetState extends State<_PatientClinicsSheet> {
  List<Map<String, dynamic>> _clinics = [];
  final Map<int, Map<String, dynamic>> _joinedTokens = {};
  final Map<int, int> _waitingCounts = {};
  final Set<int> _joiningClinicIds = {};
  final Set<int> _cancelingClinicIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ClinicApiService.getAllClinics();
      final clinics = data
          .whereType<Map>()
          .map((clinic) => Map<String, dynamic>.from(clinic))
          .where((clinic) => clinic['status'] == 'SCHEDULED')
          .toList();
      final joinedTokens = <int, Map<String, dynamic>>{};
      final waitingCounts = <int, int>{};

      await Future.wait(
        clinics.map((clinic) async {
          final clinicId = clinic['id'];
          if (clinicId is! int) return;
          try {
            final queue = await QueueApiService.getClinicQueue(
              clinicId.toString(),
            );
            final tokens = queue
                .whereType<Map>()
                .map((token) => Map<String, dynamic>.from(token))
                .toList();
            waitingCounts[clinicId] = tokens.length;

            for (final token in tokens) {
              if (token['patientId']?.toString() ==
                  widget.currentUser.id.toString()) {
                joinedTokens[clinicId] = token;
                break;
              }
            }
          } catch (_) {}
        }),
      );

      if (!mounted) return;
      setState(() {
        _clinics = clinics;
        _joinedTokens
          ..clear()
          ..addAll(joinedTokens);
        _waitingCounts
          ..clear()
          ..addAll(waitingCounts);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _joinQueue(Map<String, dynamic> clinic) async {
    final clinicId = clinic['id'];
    if (clinicId is! int) {
      _showSnack('Clinic data is invalid.', success: false);
      return;
    }
    if (_joinedTokens.containsKey(clinicId) ||
        _joiningClinicIds.contains(clinicId)) {
      return;
    }

    setState(() => _joiningClinicIds.add(clinicId));

    try {
      final token = await QueueApiService.createToken(
        clinicId: clinicId.toString(),
        patientId: widget.currentUser.id.toString(),
      );
      if (!mounted) return;
      setState(() {
        _joinedTokens[clinicId] = token;
        final position = token['position'];
        _waitingCounts[clinicId] = position is int
            ? position
            : (_waitingCounts[clinicId] ?? 0) + 1;
        _joiningClinicIds.remove(clinicId);
      });
      _showSnack(
        'Joined queue. Token #${token['tokenNumber'] ?? '-'}',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _joiningClinicIds.remove(clinicId));
      _showSnack('Failed to join queue: $e', success: false);
    }
  }

  Future<void> _cancelQueue(Map<String, dynamic> clinic) async {
    final clinicId = clinic['id'];
    if (clinicId is! int) {
      _showSnack('Clinic data is invalid.', success: false);
      return;
    }

    final token = _joinedTokens[clinicId];
    final tokenId = token?['id'];
    if (tokenId is! int) {
      _showSnack('Queue token is invalid.', success: false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel queue token'),
        content: const Text(
          'Are you sure you want to cancel your queue token for this clinic?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Cancel token'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelingClinicIds.add(clinicId));

    try {
      await QueueApiService.updateStatus(tokenId, 'CANCELLED');
      if (!mounted) return;
      setState(() => _cancelingClinicIds.remove(clinicId));
      await _loadClinics();
      if (mounted) {
        _showSnack('Queue token cancelled.', success: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelingClinicIds.remove(clinicId));
      _showSnack('Failed to cancel queue: $e', success: false);
    }
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Clinics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadClinics,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadClinics,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _PanelMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Failed to load clinics',
                    message: _error!,
                    actionLabel: 'Retry',
                    onAction: _loadClinics,
                  ),
                ],
              )
            : _clinics.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          color: AppTheme.textSecondary,
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No scheduled clinics',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Check back later for upcoming clinics.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _clinics.length,
                itemBuilder: (_, index) {
                  final clinic = _clinics[index];
                  final clinicId = clinic['id'];
                  final joinedToken = clinicId is int
                      ? _joinedTokens[clinicId]
                      : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PatientClinicCard(
                      clinic: clinic,
                      joinedToken: joinedToken,
                      waitingCount: clinicId is int
                          ? _waitingCounts[clinicId]
                          : null,
                      joining:
                          clinicId is int &&
                          _joiningClinicIds.contains(clinicId),
                      canceling:
                          clinicId is int &&
                          _cancelingClinicIds.contains(clinicId),
                      onJoin: () => _joinQueue(clinic),
                      onCancel: () => _cancelQueue(clinic),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PatientClinicCard extends StatelessWidget {
  final Map<String, dynamic> clinic;
  final Map<String, dynamic>? joinedToken;
  final int? waitingCount;
  final bool joining;
  final bool canceling;
  final VoidCallback onJoin;
  final VoidCallback onCancel;

  const _PatientClinicCard({
    required this.clinic,
    required this.joinedToken,
    required this.waitingCount,
    required this.joining,
    required this.canceling,
    required this.onJoin,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = (clinic['status'] ?? 'SCHEDULED').toString();
    final statusColor = _statusColor(status);
    final isJoined = joinedToken != null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  (clinic['clinicName'] ?? 'Unnamed Clinic').toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: '${clinic['district'] ?? '-'} - ${clinic['province'] ?? '-'}',
          ),
          const SizedBox(height: 4),
          _InfoLine(
            icon: Icons.schedule_rounded,
            text:
                '${clinic['scheduledDate'] ?? '-'} at ${clinic['scheduledTime'] ?? '-'}',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoLine(
                  icon: Icons.groups_2_outlined,
                  text: waitingCount == null
                      ? 'Queue status unavailable'
                      : '$waitingCount waiting in queue',
                ),
              ),
              const SizedBox(width: 10),
              if (isJoined)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'Token #${joinedToken?['tokenNumber'] ?? '-'}',
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: canceling ? null : onCancel,
                        icon: canceling
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.error,
                                ),
                              )
                            : const Icon(Icons.close_rounded, size: 14),
                        label: Text(canceling ? 'Cancelling' : 'Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: joining ? null : onJoin,
                    icon: joining
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login_rounded, size: 16),
                    label: Text(joining ? 'Joining' : 'Join Queue'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Patient Lab Results Sheet ─────────────────────────────────────────────────

class _PatientLabResultsSheet extends StatefulWidget {
  final User currentUser;

  const _PatientLabResultsSheet({required this.currentUser});

  @override
  State<_PatientLabResultsSheet> createState() =>
      _PatientLabResultsSheetState();
}

class _PatientLabResultsSheetState extends State<_PatientLabResultsSheet> {
  List<Map<String, dynamic>> _results = [];
  final Map<int, Map<String, dynamic>?> _resultByLabTest = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final consultations = await ConsultationApiService.list(
        patientId: widget.currentUser.id,
        page: 0,
        size: 100,
      );

      final allTests = <Map<String, dynamic>>[];
      for (final consultation in consultations) {
        final consultationId = consultation['id'];
        if (consultationId is int) {
          try {
            final tests = await LabTestApiService.getByConsultation(
              consultationId,
            );
            allTests.addAll(tests);
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _results = allTests;
        _loading = false;
      });

      await _hydrateResults(allTests);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// The lab-test's own `status`/`testResults` fields never get updated by
  /// the technician's submission (medical-records-service's link back to
  /// consultation-service is a stub), so look up the actual submitted result
  /// directly and use its presence to show the true COMPLETED state.
  Future<void> _hydrateResults(List<Map<String, dynamic>> tests) async {
    for (final test in tests) {
      final id = test['id'] as int?;
      final status = test['status']?.toString() ?? 'PENDING';
      if (id == null || (status != 'PENDING' && status != 'IN_PROGRESS')) {
        continue;
      }
      try {
        final result = await TestResultsApiService.getByLabTestId(id);
        if (!mounted) return;
        setState(() => _resultByLabTest[id] = result);
      } catch (_) {
        // Leave unset; treated as no result yet.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const Text(
                            'Lab Results',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_results.length} test results',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadResults,
                      icon: const Icon(Icons.refresh_rounded),
                      color: AppTheme.primary,
                      tooltip: 'Refresh',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AppTheme.textSecondary,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadResults,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            _PanelMessage(
                              icon: Icons.cloud_off_rounded,
                              title: 'Failed to load results',
                              message: _error!,
                              actionLabel: 'Retry',
                              onAction: _loadResults,
                            ),
                          ],
                        )
                      : _results.isEmpty
                      ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 80),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.science_outlined,
                                    color: AppTheme.textSecondary,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No lab results',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Your lab test results will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _results.length,
                          itemBuilder: (_, index) {
                            final test = _results[index];
                            final id = test['id'] as int?;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _LabTestRecordCard(
                                test: test,
                                result: id != null
                                    ? _resultByLabTest[id]
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.icon, color: action.color, size: 22),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppTheme.textHint.withValues(alpha: 0.8),
                  ),
                ],
              ),
              Text(
                action.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
