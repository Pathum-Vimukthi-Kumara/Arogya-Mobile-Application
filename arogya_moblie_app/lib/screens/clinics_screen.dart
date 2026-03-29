import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/clinic_api_service.dart';
import '../services/user_api_service.dart';

// Sri Lankan provinces and their districts — mirrors the web frontend data
const Map<String, List<String>> _kProvincesDistricts = {
  'Western': ['Colombo District', 'Gampaha District', 'Kalutara District'],
  'Southern': ['Galle District', 'Matara District', 'Hambantota District'],
  'Central': ['Kandy District', 'Matale District', 'Nuwara Eliya District'],
  'Northern': [
    'Jaffna District',
    'Kilinochchi District',
    'Mannar District',
    'Mullaitivu District',
    'Vavuniya District'
  ],
  'Eastern': [
    'Ampara District',
    'Batticaloa District',
    'Trincomalee District'
  ],
  'North Western': ['Kurunegala District', 'Puttalam District'],
  'North Central': ['Anuradhapura District', 'Polonnaruwa District'],
  'Uva': ['Badulla District', 'Monaragala District'],
  'Sabaragamuwa': ['Ratnapura District', 'Kegalle District'],
};

// ── Main Screen ────────────────────────────────────────────────────────────────

class ClinicsScreen extends StatefulWidget {
  const ClinicsScreen({super.key});

  @override
  State<ClinicsScreen> createState() => _ClinicsScreenState();
}

class _ClinicsScreenState extends State<ClinicsScreen> {
  List<Map<String, dynamic>> _clinics = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _statusFilter = 'All';

  final _searchCtrl = TextEditingController();

  static const _statuses = [
    'All',
    'SCHEDULED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED',
  ];

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
      final data = await ClinicApiService.getAllClinics();
      if (mounted) {
        setState(() {
          _clinics = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase().trim();
    return _clinics.where((c) {
      final textMatch = q.isEmpty ||
          (c['clinicName'] ?? '').toString().toLowerCase().contains(q) ||
          (c['district'] ?? '').toString().toLowerCase().contains(q) ||
          (c['province'] ?? '').toString().toLowerCase().contains(q) ||
          (c['location'] ?? '').toString().toLowerCase().contains(q);
      final statusMatch =
          _statusFilter == 'All' || c['status'] == _statusFilter;
      return textMatch && statusMatch;
    }).toList();
  }

  void _openForm({Map<String, dynamic>? clinic}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClinicFormSheet(
        clinic: clinic,
        onSaved: _loadClinics,
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> clinic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Clinic'),
        content: Text(
          'Delete "${clinic['clinicName']}"?\nThis action cannot be undone.',
        ),
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

    if (confirmed != true || !mounted) return;

    try {
      await ClinicApiService.deleteClinic(clinic['id'] as int);
      _loadClinics();
      if (mounted) _showSnack('Clinic deleted', success: true);
    } catch (e) {
      if (mounted) _showSnack('Failed to delete clinic: $e', success: false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mobile Clinics'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadClinics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Schedule Clinic',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // ── Search + Filter bar ────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or location…',
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    isDense: true,
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _statuses
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  s == 'All' ? 'All Status' : s,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: _statusFilter == s,
                                onSelected: (_) =>
                                    setState(() => _statusFilter = s),
                                selectedColor: AppTheme.primaryLight,
                                checkmarkColor: AppTheme.primary,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: _statusFilter == s
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
                                  fontWeight: _statusFilter == s
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── List body ──────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _loadClinics,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(
                          error: _error!, onRetry: _loadClinics)
                      : filtered.isEmpty
                          ? _EmptyView(
                              hasFilters: _search.isNotEmpty ||
                                  _statusFilter != 'All',
                              onSchedule: () => _openForm(),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 16, 16, 100),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: _ClinicCard(
                                  clinic: filtered[i],
                                  onEdit: () =>
                                      _openForm(clinic: filtered[i]),
                                  onDelete: () =>
                                      _confirmDelete(filtered[i]),
                                ),
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clinic Card ────────────────────────────────────────────────────────────────

class _ClinicCard extends StatefulWidget {
  final Map<String, dynamic> clinic;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClinicCard({
    required this.clinic,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ClinicCard> createState() => _ClinicCardState();
}

class _ClinicCardState extends State<_ClinicCard> {
  int _doctorCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDoctorCount();
  }

  Future<void> _loadDoctorCount() async {
    try {
      final doctors = await ClinicApiService.getClinicDoctorsByClinicId(
          widget.clinic['id'] as int);
      if (mounted) setState(() => _doctorCount = doctors.length);
    } catch (_) {}
  }

  static Color _statusFg(String s) {
    switch (s) {
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

  static Color _statusBg(String s) {
    switch (s) {
      case 'SCHEDULED':
        return const Color(0xFFEFF6FF);
      case 'IN_PROGRESS':
        return AppTheme.primaryLight;
      case 'COMPLETED':
        return const Color(0xFFD1FAE5);
      case 'CANCELLED':
        return const Color(0xFFFEE2E2);
      default:
        return AppTheme.background;
    }
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final p = raw.split('-');
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${p[2]} ${months[int.parse(p[1]) - 1]} ${p[0]}';
    } catch (_) {
      return raw;
    }
  }

  static String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final p = raw.split(':');
      final h = int.parse(p[0]);
      final m = p[1].padLeft(2, '0');
      final suffix = h >= 12 ? 'PM' : 'AM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:$m $suffix';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.clinic;
    final status = (c['status'] ?? 'SCHEDULED') as String;
    final location = (c['location'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: name + status badge ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['clinicName']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${c['district'] ?? ''} · ${c['province'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusFg(status),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Date/Time + Doctor count ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(
                              c['scheduledDate']?.toString()),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                        ),
                        Text(
                          _formatTime(
                              c['scheduledTime']?.toString()),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.people_outline_rounded,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '$_doctorCount ${_doctorCount == 1 ? 'Doctor' : 'Doctors'}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Actions ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit',
                      style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side:
                        const BorderSide(color: AppTheme.primary),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: widget.onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Form Bottom Sheet ──────────────────────────────────────────────────────────

class _ClinicFormSheet extends StatefulWidget {
  final Map<String, dynamic>? clinic; // null → create, non-null → edit
  final VoidCallback onSaved;

  const _ClinicFormSheet({this.clinic, required this.onSaved});

  @override
  State<_ClinicFormSheet> createState() => _ClinicFormSheetState();
}

class _ClinicFormSheetState extends State<_ClinicFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  final _doctorSearchCtrl = TextEditingController();

  String? _province;
  String? _district;
  DateTime? _date;
  TimeOfDay? _time;
  String _status = 'SCHEDULED';

  List<Map<String, dynamic>> _allDoctors = [];
  List<Map<String, dynamic>> _filteredDoctors = [];
  List<Map<String, dynamic>> _selectedDoctors = [];
  bool _showDropdown = false;

  bool _saving = false;
  bool _loadingDoctors = true;
  String? _formError;

  bool get _isEdit => widget.clinic != null;

  @override
  void initState() {
    super.initState();
    final c = widget.clinic;
    _nameCtrl =
        TextEditingController(text: c?['clinicName']?.toString() ?? '');
    _locationCtrl =
        TextEditingController(text: c?['location']?.toString() ?? '');

    if (c != null) {
      _province = c['province'] as String?;
      _district = c['district'] as String?;
      _status = (c['status'] as String?) ?? 'SCHEDULED';

      final dateStr = c['scheduledDate']?.toString();
      if (dateStr != null) {
        try {
          final p = dateStr.split('-');
          _date = DateTime(
              int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        } catch (_) {}
      }

      final timeStr = c['scheduledTime']?.toString();
      if (timeStr != null) {
        try {
          final p = timeStr.split(':');
          _time = TimeOfDay(
              hour: int.parse(p[0]), minute: int.parse(p[1]));
        } catch (_) {}
      }
    }

    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _doctorSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingDoctors = true);
    try {
      final raw = await UserApiService.getAllDoctorProfiles();
      if (mounted) {
        // Raw profile has: id, firstName, lastName, specialization
        // Normalise to: doctorId, name, specialization — mirrors the web frontend transform
        final doctors = raw.cast<Map<String, dynamic>>().map((p) {
          final first = p['firstName']?.toString() ?? '';
          final last  = p['lastName']?.toString() ?? '';
          return <String, dynamic>{
            'doctorId':       p['id'],
            'name':           'Dr. $first $last'.trim(),
            'specialization': p['specialization']?.toString() ?? '',
          };
        }).toList();
        setState(() {
          _allDoctors = doctors;
          _loadingDoctors = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDoctors = false);
    }

    if (_isEdit && mounted) {
      try {
        final assigned = await ClinicApiService.getClinicDoctorsByClinicId(
            widget.clinic!['id'] as int);
        if (mounted) {
          setState(() {
            _selectedDoctors = assigned
                .cast<Map<String, dynamic>>()
                .map((m) => {
                      'doctorId': m['doctorRefId'],
                      'name': m['doctorName']?.toString() ?? '',
                      'specialization':
                          m['specialization']?.toString() ?? '',
                    })
                .toList();
          });
        }
      } catch (_) {}
    }
  }

  void _onDoctorSearch(String q) {
    final trimmed = q.trim().toLowerCase();
    setState(() {
      if (trimmed.isEmpty) {
        _filteredDoctors = [];
        _showDropdown = false;
      } else {
        _filteredDoctors = _allDoctors.where((d) {
          final name =
              (d['name'] ?? d['doctorName'] ?? '').toString().toLowerCase();
          final spec =
              (d['specialization'] ?? '').toString().toLowerCase();
          return name.contains(trimmed) || spec.contains(trimmed);
        }).toList();
        _showDropdown = true;
      }
    });
  }

  void _selectDoctor(Map<String, dynamic> d) {
    final id = d['doctorId'] ?? d['id'];
    if (!_selectedDoctors.any((s) => s['doctorId'] == id)) {
      setState(() {
        _selectedDoctors.add({
          'doctorId': id,
          'name': (d['name'] ?? d['doctorName'] ?? '').toString(),
          'specialization': (d['specialization'] ?? '').toString(),
        });
      });
    }
    _doctorSearchCtrl.clear();
    setState(() => _showDropdown = false);
  }

  void _removeDoctor(dynamic id) {
    setState(() =>
        _selectedDoctors.removeWhere((d) => d['doctorId'] == id));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: _isEdit ? DateTime(2020) : DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  String get _dateLabel {
    if (_date == null) return 'Select Date';
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${_date!.day} ${m[_date!.month - 1]} ${_date!.year}';
  }

  String get _timeLabel {
    if (_time == null) return 'Select Time';
    final suffix = _time!.hour >= 12 ? 'PM' : 'AM';
    final h = _time!.hour % 12 == 0 ? 12 : _time!.hour % 12;
    return '$h:${_time!.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _submit() async {
    setState(() => _formError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_date == null) {
      setState(() => _formError = 'Please select a scheduled date.');
      return;
    }
    if (_time == null) {
      setState(() => _formError = 'Please select a scheduled time.');
      return;
    }
    if (_selectedDoctors.isEmpty) {
      setState(() =>
          _formError = 'Please assign at least one doctor.');
      return;
    }

    setState(() => _saving = true);

    try {
      final dateStr =
          '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}:00';

      final body = <String, dynamic>{
        if (_isEdit) 'id': widget.clinic!['id'],
        'clinicName': _nameCtrl.text.trim(),
        'province': _province,
        'district': _district,
        'scheduledDate': dateStr,
        'scheduledTime': timeStr,
        'status': _status,
        'doctorIds':
            _selectedDoctors.map((d) => d['doctorId']).toList(),
      };

      final loc = _locationCtrl.text.trim();
      if (loc.isNotEmpty) body['location'] = loc;

      if (_isEdit) {
        await ClinicApiService.updateClinic(body);
      } else {
        await ClinicApiService.createClinic(body);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? 'Clinic updated successfully'
                : 'Clinic scheduled successfully'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = e.toString();
        });
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Text(
                  _isEdit ? 'Edit Clinic' : 'Schedule New Clinic',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable form
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error banner
                    if (_formError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.error
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _formError!,
                          style: const TextStyle(
                              color: AppTheme.error, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Clinic Name ───────────────────────────────
                    _fieldLabel('Clinic Name *'),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                          hintText: 'e.g., Galle Mobile Clinic'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true)
                              ? 'Clinic name is required'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Province ──────────────────────────────────
                    _fieldLabel('Province *'),
                    DropdownButtonFormField<String>(
                      value: _province,
                      decoration: const InputDecoration(
                          hintText: 'Select Province'),
                      items: _kProvincesDistricts.keys
                          .map((p) => DropdownMenuItem(
                              value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _province = v;
                        _district = null;
                      }),
                      validator: (v) =>
                          v == null ? 'Province is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── District ──────────────────────────────────
                    _fieldLabel('District *'),
                    DropdownButtonFormField<String>(
                      value: _district,
                      decoration: const InputDecoration(
                          hintText: 'Select District'),
                      items: (_province == null
                              ? <String>[]
                              : _kProvincesDistricts[_province!]!)
                          .map((d) => DropdownMenuItem(
                              value: d, child: Text(d)))
                          .toList(),
                      onChanged: _province == null
                          ? null
                          : (v) => setState(() => _district = v),
                      validator: (v) =>
                          v == null ? 'District is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Location (optional) ───────────────────────
                    _fieldLabel('Specific Location (Optional)'),
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(
                          hintText:
                              'e.g., Town Centre, Near Hospital'),
                    ),
                    const SizedBox(height: 16),

                    // ── Date + Time ───────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              _fieldLabel('Date *'),
                              OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 15),
                                label: Text(_dateLabel,
                                    style: const TextStyle(
                                        fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _date == null
                                      ? AppTheme.textHint
                                      : AppTheme.textPrimary,
                                  side: BorderSide(
                                      color: _date == null
                                          ? AppTheme.border
                                          : AppTheme.primary),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  alignment: Alignment.centerLeft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              _fieldLabel('Time *'),
                              OutlinedButton.icon(
                                onPressed: _pickTime,
                                icon: const Icon(
                                    Icons.access_time_outlined,
                                    size: 15),
                                label: Text(_timeLabel,
                                    style: const TextStyle(
                                        fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _time == null
                                      ? AppTheme.textHint
                                      : AppTheme.textPrimary,
                                  side: BorderSide(
                                      color: _time == null
                                          ? AppTheme.border
                                          : AppTheme.primary),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  alignment: Alignment.centerLeft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Status (edit only) ────────────────────────
                    if (_isEdit) ...[
                      _fieldLabel('Status'),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(),
                        items: [
                          'SCHEDULED',
                          'IN_PROGRESS',
                          'COMPLETED',
                          'CANCELLED'
                        ]
                            .map((s) => DropdownMenuItem(
                                value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _status = v!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Doctor Assignment ─────────────────────────
                    _fieldLabel(_isEdit
                        ? 'Update Assigned Doctors *'
                        : 'Assign Doctors *'),
                    if (_loadingDoctors)
                      const Center(
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        ),
                      )
                    else ...[
                      // Doctor search input
                      TextField(
                        controller: _doctorSearchCtrl,
                        onChanged: _onDoctorSearch,
                        decoration: const InputDecoration(
                          hintText:
                              'Search by name or specialization…',
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 18),
                        ),
                      ),

                      // Dropdown suggestions
                      if (_showDropdown &&
                          _filteredDoctors.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          constraints:
                              const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius:
                                BorderRadius.circular(12),
                            border:
                                Border.all(color: AppTheme.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(
                                vertical: 4),
                            itemCount: _filteredDoctors.length,
                            itemBuilder: (_, i) {
                              final d = _filteredDoctors[i];
                              final name = (d['name'] ??
                                      d['doctorName'] ??
                                      '')
                                  .toString();
                              final spec =
                                  (d['specialization'] ?? '')
                                      .toString();
                              return InkWell(
                                onTap: () => _selectDoctor(d),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 14,
                                          color:
                                              AppTheme.textPrimary,
                                        ),
                                      ),
                                      if (spec.isNotEmpty)
                                        Text(
                                          spec,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme
                                                .textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Selected doctors chips
                      if (_selectedDoctors.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ..._selectedDoctors.map(
                          (d) => Container(
                            margin:
                                const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius:
                                  BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: AppTheme.success),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['name']?.toString() ??
                                            '',
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 13,
                                          color:
                                              AppTheme.textPrimary,
                                        ),
                                      ),
                                      if ((d['specialization'] ??
                                              '')
                                          .toString()
                                          .isNotEmpty)
                                        Text(
                                          d['specialization']
                                              .toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme
                                                .textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      _removeDoctor(d['doctorId']),
                                  child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: AppTheme.error),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),

                    // ── Submit buttons ────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  AppTheme.textSecondary,
                              side: const BorderSide(
                                  color: AppTheme.border),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : Text(_isEdit
                                    ? 'Update Clinic'
                                    : 'Schedule Clinic'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onSchedule;

  const _EmptyView({required this.hasFilters, required this.onSchedule});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.calendar_today_outlined,
                    color: AppTheme.primary, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'No clinics found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasFilters
                    ? 'Try adjusting your search or filter'
                    : 'Schedule your first mobile clinic',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              if (!hasFilters) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onSchedule,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Schedule Clinic'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Failed to load clinics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
