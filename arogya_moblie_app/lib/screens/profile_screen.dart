import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../services/user_api_service.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';
  final User user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Common profile controllers (all roles)
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nicCtrl = TextEditingController();

  // Patient-specific
  final _addressCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _bloodGroupCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _chronicCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  // Doctor + Technician shared
  final _licenseCtrl = TextEditingController();

  // Doctor-specific
  final _specialCtrl = TextEditingController();
  final _qualCtrl = TextEditingController();
  final _expCtrl = TextEditingController();

  // Technician-specific
  final _techFieldCtrl = TextEditingController();
  final _certCtrl = TextEditingController();
  final _equipCtrl = TextEditingController();

  bool _editing = false;
  bool _saving = false;
  bool _loadingProfile = true;
  bool _isNewProfile = false;
  String? _saveError;
  String? _saveSuccess;
  Map<String, dynamic>? _profileData;

  // Dropdown selections
  String? _selectedGender;
  String? _selectedBloodGroup;
  String? _selectedSpecialization;
  String? _selectedTechField;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _bloodGroups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  static const _specializations = [
    'Cardiology', 'Dermatology', 'Endocrinology', 'Family Medicine',
    'Gastroenterology', 'Internal Medicine', 'Neurology', 'Oncology',
    'Pediatrics', 'Psychiatry', 'Pulmonology', 'Radiology', 'Surgery',
    'Urology', 'Other',
  ];
  static const _techFields = [
    'Radiology', 'Laboratory', 'Pharmacy', 'Cardiovascular', 'Respiratory',
    'Emergency Medical', 'Surgical', 'Dental', 'Ophthalmic', 'Dialysis', 'Other',
  ];

  String get _role => widget.user.userRole.roleName.toUpperCase();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    _nicCtrl.dispose();
    _addressCtrl.dispose();
    _genderCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _allergiesCtrl.dispose();
    _chronicCtrl.dispose();
    _emergencyCtrl.dispose();
    _licenseCtrl.dispose();
    _specialCtrl.dispose();
    _qualCtrl.dispose();
    _expCtrl.dispose();
    _techFieldCtrl.dispose();
    _certCtrl.dispose();
    _equipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _isNewProfile = false;
    });
    try {
      final uid = widget.user.id;
      Map<String, dynamic>? data;
      if (_role == 'PATIENT') {
        data = await UserApiService.getPatientProfile(uid);
      } else if (_role == 'DOCTOR') {
        data = await UserApiService.getDoctorProfile(uid);
      } else if (_role == 'TECHNICIAN') {
        data = await UserApiService.getTechnicianProfile(uid);
      } else if (_role == 'ADMIN') {
        data = await UserApiService.getAdminProfile(uid);
      }

      if (data != null) {
        _profileData = data;
        _populateControllers(data);
      } else {
        // No profile found — go straight into create mode
        _isNewProfile = true;
        _editing = true;
      }
    } catch (_) {
      // Network or unexpected error — treat as new profile
      _isNewProfile = true;
      _editing = true;
    }
    if (mounted) setState(() => _loadingProfile = false);
  }

  void _populateControllers(Map<String, dynamic> d) {
    _firstNameCtrl.text = d['firstName'] as String? ?? '';
    _lastNameCtrl.text = d['lastName'] as String? ?? '';
    _dobCtrl.text = d['dateOfBirth'] as String? ?? '';
    _phoneCtrl.text = d['phoneNumber'] as String? ?? '';
    _nicCtrl.text = d['nicNumber'] as String? ?? '';

    if (_role == 'PATIENT') {
      _addressCtrl.text = d['address'] as String? ?? '';
      _allergiesCtrl.text = d['allergies'] as String? ?? '';
      _chronicCtrl.text = d['chronicDiseases'] as String? ?? '';
      _emergencyCtrl.text = d['emergencyContact'] as String? ?? '';
      final g = d['gender'] as String? ?? '';
      _selectedGender = _genders.contains(g) ? g : null;
      final bg = d['bloodGroup'] as String? ?? '';
      _selectedBloodGroup = _bloodGroups.contains(bg) ? bg : null;
    } else if (_role == 'DOCTOR') {
      _licenseCtrl.text = d['licenseNumber'] as String? ?? '';
      _qualCtrl.text = d['qualification'] as String? ?? '';
      _expCtrl.text = (d['experienceYears'] ?? '').toString();
      final sp = d['specialization'] as String? ?? '';
      _selectedSpecialization = _specializations.contains(sp) ? sp : null;
    } else if (_role == 'TECHNICIAN') {
      _licenseCtrl.text = d['licenseNumber'] as String? ?? '';
      _certCtrl.text = d['certification'] as String? ?? '';
      _equipCtrl.text = d['assignedEquipment'] as String? ?? '';
      final tf = d['technicianField'] as String? ?? '';
      _selectedTechField = _techFields.contains(tf) ? tf : null;
    }
  }

  Map<String, dynamic> _buildBody() {
    final userRef = {'id': widget.user.id};
    final body = <String, dynamic>{
      'firstName': _firstNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'dateOfBirth': _dobCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      'nicNumber': _nicCtrl.text.trim(),
      'user': userRef,
    };

    if (!_isNewProfile && _profileData != null) {
      // Carry over the existing profile ID so backend can identify the record
      body.addAll(_profileData!);
      // Overwrite with fresh values
      body['firstName'] = _firstNameCtrl.text.trim();
      body['lastName'] = _lastNameCtrl.text.trim();
      body['dateOfBirth'] = _dobCtrl.text.trim();
      body['phoneNumber'] = _phoneCtrl.text.trim();
      body['nicNumber'] = _nicCtrl.text.trim();
    }

    if (_role == 'PATIENT') {
      body['address'] = _addressCtrl.text.trim();
      body['gender'] = _selectedGender ?? '';
      body['bloodGroup'] = _selectedBloodGroup ?? '';
      body['allergies'] = _allergiesCtrl.text.trim();
      body['chronicDiseases'] = _chronicCtrl.text.trim();
      body['emergencyContact'] = _emergencyCtrl.text.trim();
    } else if (_role == 'DOCTOR') {
      body['licenseNumber'] = _licenseCtrl.text.trim();
      body['specialization'] = _selectedSpecialization ?? '';
      body['qualification'] = _qualCtrl.text.trim();
      body['experienceYears'] = int.tryParse(_expCtrl.text.trim()) ?? 0;
    } else if (_role == 'TECHNICIAN') {
      body['technicianField'] = _selectedTechField ?? '';
      body['licenseNumber'] = _licenseCtrl.text.trim();
      body['certification'] = _certCtrl.text.trim();
      body['assignedEquipment'] = _equipCtrl.text.trim();
    }

    return body;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
      _saveSuccess = null;
    });

    try {
      final body = _buildBody();
      Map<String, dynamic> saved;

      if (_isNewProfile) {
        if (_role == 'PATIENT') {
          saved = await UserApiService.createPatientProfile(body);
        } else if (_role == 'DOCTOR') {
          saved = await UserApiService.createDoctorProfile(body);
        } else if (_role == 'TECHNICIAN') {
          saved = await UserApiService.createTechnicianProfile(body);
        } else {
          saved = await UserApiService.createAdminProfile(body);
        }
      } else {
        if (_role == 'PATIENT') {
          saved = await UserApiService.updatePatientProfile(body);
        } else if (_role == 'DOCTOR') {
          saved = await UserApiService.updateDoctorProfile(body);
        } else if (_role == 'TECHNICIAN') {
          saved = await UserApiService.updateTechnicianProfile(body);
        } else {
          saved = await UserApiService.updateAdminProfile(body);
        }
      }

      _profileData = saved;
      _isNewProfile = false;
      _populateControllers(saved);

      setState(() {
        _saveSuccess =
            _isNewProfile ? 'Profile created!' : 'Profile saved successfully.';
        _editing = false;
      });
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  String get _displayName {
    if (_profileData != null) {
      final first = _profileData!['firstName'] as String? ?? '';
      final last = _profileData!['lastName'] as String? ?? '';
      final full = '$first $last'.trim();
      if (full.isNotEmpty) return full;
    }
    return widget.user.username;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        automaticallyImplyLeading: true,
        actions: [
          if (!_loadingProfile)
            if (!_editing)
              TextButton(
                onPressed: () => setState(() {
                  _editing = true;
                  _saveError = null;
                  _saveSuccess = null;
                }),
                child: const Text('Edit'),
              )
            else if (!_isNewProfile)
              TextButton(
                onPressed: () {
                  if (_profileData != null) _populateControllers(_profileData!);
                  setState(() {
                    _editing = false;
                    _saveError = null;
                  });
                },
                child: const Text('Cancel'),
              ),
        ],
      ),
      // ── Pinned bottom actions ──────────────────────────────────────
      bottomNavigationBar: _loadingProfile
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _editing
                    ? SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white),
                                )
                              : Text(_isNewProfile
                                  ? 'Create Profile'
                                  : 'Save Changes'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              children: [
                // ── Avatar identity card ───────────────────────────
                Container(
                  color: AppTheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          widget.user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.user.userRole.roleName,
                          style: const TextStyle(
                            color: AppTheme.primaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Form fields ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isNewProfile)
                          _Banner(
                            message:
                                'No profile found. Fill in your details and tap "Create Profile".',
                            color: AppTheme.primary,
                            icon: Icons.info_outline,
                          ),
                        if (_saveSuccess != null)
                          _Banner(
                            message: _saveSuccess!,
                            color: AppTheme.success,
                            icon: Icons.check_circle_outline,
                          ),
                        if (_saveError != null)
                          _Banner(
                            message: _saveError!,
                            color: AppTheme.error,
                            icon: Icons.error_outline,
                          ),
                        _buildProfileFields(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _formField(_firstNameCtrl,
            label: 'First Name', hint: 'First name', required: true),
        const SizedBox(height: 16),
        _formField(_lastNameCtrl,
            label: 'Last Name', hint: 'Last name', required: true),
        const SizedBox(height: 16),
        _dateField(),
        const SizedBox(height: 16),
        _formField(_phoneCtrl,
            label: 'Phone Number',
            hint: '+94XXXXXXXXX',
            type: TextInputType.phone,
            required: true),
        const SizedBox(height: 16),
        _formField(_nicCtrl,
            label: 'NIC Number',
            hint: '123456789V or 123456789012',
            required: true),
        ..._roleSpecificFields(),
      ],
    );
  }

  List<Widget> _roleSpecificFields() {
    if (_role == 'PATIENT') return _patientFields();
    if (_role == 'DOCTOR') return _doctorFields();
    if (_role == 'TECHNICIAN') return _technicianFields();
    return []; // ADMIN — only common fields
  }

  List<Widget> _patientFields() => [
        const SizedBox(height: 16),
        _dropdownField(
          label: 'Gender',
          value: _selectedGender,
          items: _genders,
          onChanged: (v) => setState(() => _selectedGender = v),
        ),
        const SizedBox(height: 16),
        _dropdownField(
          label: 'Blood Group',
          value: _selectedBloodGroup,
          items: _bloodGroups,
          onChanged: (v) => setState(() => _selectedBloodGroup = v),
        ),
        const SizedBox(height: 16),
        _formField(_addressCtrl,
            label: 'Address', hint: 'Full address', maxLines: 2),
        const SizedBox(height: 16),
        _formField(_allergiesCtrl,
            label: 'Allergies',
            hint: 'Known allergies (if any)',
            maxLines: 2),
        const SizedBox(height: 16),
        _formField(_chronicCtrl,
            label: 'Chronic Diseases',
            hint: 'Chronic conditions (if any)',
            maxLines: 2),
        const SizedBox(height: 16),
        _formField(_emergencyCtrl,
            label: 'Emergency Contact',
            hint: 'Emergency phone number',
            type: TextInputType.phone),
      ];

  List<Widget> _doctorFields() => [
        const SizedBox(height: 16),
        _formField(_licenseCtrl,
            label: 'License Number',
            hint: 'SLMC license number',
            required: true),
        const SizedBox(height: 16),
        _dropdownField(
          label: 'Specialization',
          value: _selectedSpecialization,
          items: _specializations,
          onChanged: (v) => setState(() => _selectedSpecialization = v),
          required: true,
        ),
        const SizedBox(height: 16),
        _formField(_qualCtrl,
            label: 'Qualification',
            hint: 'e.g. MBBS, MD, Fellowship',
            maxLines: 2,
            required: true),
        const SizedBox(height: 16),
        _formField(_expCtrl,
            label: 'Years of Experience',
            hint: '0',
            type: TextInputType.number),
      ];

  List<Widget> _technicianFields() => [
        const SizedBox(height: 16),
        _dropdownField(
          label: 'Field / Specialization',
          value: _selectedTechField,
          items: _techFields,
          onChanged: (v) => setState(() => _selectedTechField = v),
          required: true,
        ),
        const SizedBox(height: 16),
        _formField(_licenseCtrl,
            label: 'License Number', hint: 'License number', required: true),
        const SizedBox(height: 16),
        _formField(_certCtrl,
            label: 'Certification',
            hint: 'e.g. ARRT, certification details',
            maxLines: 2),
        const SizedBox(height: 16),
        _formField(_equipCtrl,
            label: 'Assigned Equipment',
            hint: 'List equipment/instruments',
            maxLines: 2),
      ];

  // ── Form field builders ──────────────────────────────────────────────

  Widget _formField(
    TextEditingController ctrl, {
    required String label,
    String hint = '',
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label, required: required),
        _editing
            ? TextFormField(
                controller: ctrl,
                keyboardType: type,
                maxLines: maxLines,
                decoration: InputDecoration(hintText: hint),
                validator: required
                    ? (v) => v == null || v.trim().isEmpty
                        ? '$label is required'
                        : null
                    : null,
              )
            : _ReadOnlyField(ctrl.text.isEmpty ? '—' : ctrl.text),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label, required: required),
        _editing
            ? DropdownButtonFormField<String>(
                value: value,
                decoration: InputDecoration(hintText: 'Select $label'),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onChanged,
                validator: required
                    ? (v) => v == null ? 'Please select a $label' : null
                    : null,
              )
            : _ReadOnlyField(value?.isEmpty ?? true ? '—' : value!),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Date of Birth'),
        GestureDetector(
          onTap: _editing ? _pickDate : null,
          child: AbsorbPointer(
            child: TextFormField(
              controller: _dobCtrl,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Select date',
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: _editing ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now();
    if (_dobCtrl.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_dobCtrl.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: AppTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dobCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }
}

// ── Shared helper widgets ────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            if (required)
              const Text(' *',
                  style: TextStyle(color: AppTheme.error, fontSize: 13)),
          ],
        ),
      );
}

class _ReadOnlyField extends StatelessWidget {
  final String value;
  const _ReadOnlyField(this.value);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        ),
      );
}

class _Banner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  const _Banner(
      {required this.message, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(message, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}
