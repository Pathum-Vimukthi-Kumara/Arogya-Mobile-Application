import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../services/lab_test_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/user_api_service.dart';
import '../services/test_results_api_service.dart';

class LabTestsScreen extends StatefulWidget {
  static const routeName = '/lab-tests';
  final User currentUser;

  const LabTestsScreen({super.key, required this.currentUser});

  @override
  State<LabTestsScreen> createState() => _LabTestsScreenState();
}

class _LabTestsScreenState extends State<LabTestsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _labTests = [];
  List<Map<String, dynamic>> _filteredTests = [];
  final Map<int, Map<String, dynamic>> _patientByConsultation = {};
  final Map<int, bool> _resultExistsByLabTest = {};

  bool _loading = false;
  String? _error;
  String _searchTerm = '';
  String _statusFilter = 'ALL';

  final List<String> _statusOptions = [
    'ALL',
    'PENDING',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _loadLabTests();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLabTests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch all lab tests using the API
      final data = await LabTestApiService.list(size: 1000);
      if (!mounted) return;

      // Ensure _labTests is a list
      final tests = data.whereType<Map<String, dynamic>>().toList();

      // Debug: Print all test statuses
      print('DEBUG: Total tests received: ${tests.length}');
      final statusCounts = <String, int>{};
      for (final test in tests) {
        final status = test['status']?.toString() ?? 'NULL';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        print('  Test ID: ${test['id']}, Status: $status');
      }
      print('DEBUG: Status counts: $statusCounts');

      setState(() {
        _labTests = tests;
      });

      // Hydrate patient details and result presence in parallel
      await Future.wait([
        _hydratePatientDetails(tests),
        _hydrateResultExistence(tests),
      ], eagerError: false);

      if (mounted) {
        setState(() {
          _loading = false;
        });
        _filterTests();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _hydratePatientDetails(List<Map<String, dynamic>> tests) async {
    final consultationIds = <int>{};
    for (final test in tests) {
      final consultId = test['consultationId'] as int?;
      if (consultId != null && !_patientByConsultation.containsKey(consultId)) {
        consultationIds.add(consultId);
      }
    }

    if (consultationIds.isEmpty) return;

    for (final consultationId in consultationIds) {
      try {
        final consultation = await ConsultationApiService.get(consultationId);
        final patientId = consultation['patientId'] as int?;

        if (patientId != null) {
          String patientName = 'Patient #$patientId';

          // Try to get patient profile first
          try {
            final profile = await UserApiService.getPatientProfile(patientId);
            if (profile != null) {
              final firstName = profile['firstName']?.toString() ?? '';
              final lastName = profile['lastName']?.toString() ?? '';
              final name = [firstName, lastName]
                  .where((part) => part.toString().trim().isNotEmpty)
                  .join(' ')
                  .trim();
              if (name.isNotEmpty) {
                patientName = name;
              }
            }
          } catch (e) {
            print('ERROR: Failed to get patient profile for $patientId: $e');
            // Fallback to user service
            try {
              final user = await UserApiService.getUserById(patientId);
              if (user.username.isNotEmpty) {
                patientName = user.username;
              }
            } catch (e2) {
              print('ERROR: Failed to get user by ID for $patientId: $e2');
              // Keep default patientName
            }
          }

          if (mounted) {
            setState(() {
              _patientByConsultation[consultationId] = {
                'patientId': patientId,
                'name': patientName,
              };
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _patientByConsultation[consultationId] = {
              'patientId': 0,
              'name': '-',
            };
          });
        }
      }
    }
  }

  Future<void> _hydrateResultExistence(List<Map<String, dynamic>> tests) async {
    final targets = tests.where((test) {
      final id = test['id'] as int?;
      final status = test['status']?.toString().toUpperCase() ?? 'PENDING';
      return id != null && (status == 'PENDING' || status == 'IN_PROGRESS');
    }).toList();

    await Future.wait(
      targets.map((test) async {
        final id = test['id'] as int;
        try {
          final result = await TestResultsApiService.getByLabTestId(id);
          if (mounted && result != null) {
            setState(() {
              _resultExistsByLabTest[id] = true;
            });
          }
        } catch (_) {
          // Leave unset; treated as no result yet.
        }
      }),
      eagerError: false,
    );
  }

  Future<void> _submitTestResult(Map<String, dynamic> test) async {
    final consultationId = test['consultationId'] as int?;
    final patientInfo = _patientByConsultation[consultationId];
    final patientId = patientInfo?['patientId'] as int?;
    final patientName = patientInfo?['name']?.toString() ?? 'Patient';

    if (patientId == null || patientId == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to resolve patient for this lab test. Please refresh and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SubmitTestResultSheet(
        test: test,
        patientName: patientName,
        patientId: patientId,
        currentUser: widget.currentUser,
      ),
    );

    if (submitted == true && mounted) {
      setState(() {
        _resultExistsByLabTest[test['id'] as int] = true;
      });
      _filterTests();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test result submitted successfully'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  Future<void> _viewTestResult(Map<String, dynamic> test) async {
    final consultationId = test['consultationId'] as int?;
    final patientInfo = _patientByConsultation[consultationId];
    final patientName = patientInfo?['name']?.toString() ?? 'Patient';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ViewTestResultSheet(
        test: test,
        patientName: patientName,
      ),
    );
  }

  String _getDisplayStatus(Map<String, dynamic> test) {
    final status = test['status']?.toString() ?? 'PENDING';
    // If result exists, show as COMPLETED
    if ((status == 'PENDING' || status == 'IN_PROGRESS') &&
        _resultExistsByLabTest[test['id']] == true) {
      return 'COMPLETED';
    }
    return status;
  }

  void _filterTests() {
    var filtered = _labTests;

    // Filter by status
    if (_statusFilter != 'ALL') {
      filtered = filtered
          .where((test) => _getDisplayStatus(test) == _statusFilter)
          .toList();
    }

    // Filter by search term
    if (_searchTerm.isNotEmpty) {
      final term = _searchTerm.toLowerCase();
      filtered = filtered.where((test) {
        final testName = (test['testName'] ?? '').toString().toLowerCase();
        final id = (test['id'] ?? '').toString();
        final consultId = (test['consultationId'] ?? '').toString();
        final patientInfo = _patientByConsultation[test['consultationId']];
        final patientName = (patientInfo?['name'] ?? '')
            .toString()
            .toLowerCase();

        return testName.contains(term) ||
            id.contains(term) ||
            consultId.contains(term) ||
            patientName.contains(term);
      }).toList();
    }

    setState(() {
      _filteredTests = filtered;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFFEF3C7);
      case 'IN_PROGRESS':
        return const Color(0xFFDEBEF7);
      case 'COMPLETED':
        return const Color(0xFFD1FAE5);
      case 'CANCELLED':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFF92400E);
      case 'IN_PROGRESS':
        return const Color(0xFF6B21A8);
      case 'COMPLETED':
        return const Color(0xFF065F46);
      case 'CANCELLED':
        return const Color(0xFF7F1D1D);
      default:
        return const Color(0xFF374151);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.schedule_rounded;
      case 'IN_PROGRESS':
        return Icons.info_rounded;
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'CANCELLED':
        return Icons.cancel_rounded;
      default:
        return Icons.science_rounded;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day} ${_getMonthAbbr(date.month)} ${date.year}, '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  String _getMonthAbbr(int month) {
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
    return months[month - 1];
  }

  int _getStatusCount(String status) {
    if (status == 'ALL') {
      return _labTests.length;
    }
    return _labTests.where((test) => _getDisplayStatus(test) == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayLight,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          title: const Text(
            'Lab Tests',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          elevation: 0,
          systemOverlayStyle: AppTheme.overlayLight,
        ),
        body: Column(
          children: [
            // Status Filter Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: _statusOptions.map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            '${status.replaceAll('_', ' ')} (${_getStatusCount(status)})',
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _statusFilter = status;
                            });
                            _filterTests();
                          },
                          backgroundColor: Colors.white,
                          selectedColor: AppTheme.primary,
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : AppTheme.border,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (value) {
                    setState(() {
                      _searchTerm = value;
                    });
                    _filterTests();
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Search by test name, patient, ID, or consultation ID...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error Message
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

            // Lab Tests List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _loadLabTests,
                      child: _filteredTests.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.4,
                                  child: Center(
                                    child: Text(
                                      'No lab tests found',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _filteredTests.length,
                              itemBuilder: (context, index) {
                        final test = _filteredTests[index];
                        final displayStatus = _getDisplayStatus(test);
                        final patientInfo =
                            _patientByConsultation[test['consultationId']];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppTheme.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ID and Status
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ID: ${test['id']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(displayStatus),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        displayStatus,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusTextColor(
                                            displayStatus,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Test Name with Icon
                                Row(
                                  children: [
                                    Icon(
                                      _getStatusIcon(displayStatus),
                                      size: 20,
                                      color: _getStatusTextColor(displayStatus),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        test['testName']?.toString() ??
                                            'Unknown',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Consultation and Patient
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Consultation',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '# ${test['consultationId']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Patient',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            patientInfo?['name'] ??
                                                'Loading...',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Created At
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Created At',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(
                                        test['createdAt']?.toString(),
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Action Button
                                SizedBox(
                                  width: double.infinity,
                                  child:
                                      displayStatus == 'PENDING' ||
                                          displayStatus == 'IN_PROGRESS'
                                      ? ElevatedButton.icon(
                                          onPressed: () => _submitTestResult(test),
                                          icon: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Take Test'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        )
                                      : OutlinedButton(
                                          onPressed: () => _viewTestResult(test),
                                          child: const Text('View Result'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primary,
                                            side: const BorderSide(
                                              color: AppTheme.primary,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit Test Result Modal Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitTestResultSheet extends StatefulWidget {
  final Map<String, dynamic> test;
  final String patientName;
  final int patientId;
  final User currentUser;

  const _SubmitTestResultSheet({
    required this.test,
    required this.patientName,
    required this.patientId,
    required this.currentUser,
  });

  @override
  State<_SubmitTestResultSheet> createState() => _SubmitTestResultSheetState();
}

class _SubmitTestResultSheetState extends State<_SubmitTestResultSheet> {
  final _descriptionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  PlatformFile? _pickedFile;

  static const _allowedExtensions = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];
  static const _maxFileSizeBytes = 10 * 1024 * 1024;
  static const _mimeTypesByExtension = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;
      if (file.size > _maxFileSizeBytes) {
        setState(() {
          _error = 'File size must be less than 10MB';
        });
        return;
      }
      setState(() {
        _pickedFile = file;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to pick file: $e';
      });
    }
  }

  Future<void> _submit() async {
    final description = _descriptionCtrl.text.trim();
    if (description.isEmpty) {
      setState(() {
        _error = 'Please enter a test result description or clinical findings.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final extension = _pickedFile?.extension?.toLowerCase();
      await TestResultsApiService.create(
        labTestId: widget.test['id'] as int,
        patientId: widget.patientId,
        technicianId: widget.currentUser.id,
        testResultDescription: description,
        technicianNotes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        fileBytes: _pickedFile?.bytes,
        fileName: _pickedFile?.name,
        mimeType: extension != null ? _mimeTypesByExtension[extension] : null,
      );

      // Best-effort status update to lab-test-service
      try {
        await LabTestApiService.completeTest(widget.test['id'] as int);
      } catch (_) {
        try {
          await LabTestApiService.updateStatus(
            widget.test['id'] as int,
            {'status': 'COMPLETED'},
          );
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final testName = widget.test['testName']?.toString() ?? 'Lab Test';
    final testId = widget.test['id']?.toString() ?? '-';
    final consultId = widget.test['consultationId']?.toString() ?? '-';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submit Test Result',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Record findings and upload reports for review',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.background,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // Scrollable Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Test Context Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.biotech_rounded,
                              color: AppTheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  testName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _infoBadge(
                                      icon: Icons.tag_rounded,
                                      label: 'ID: #$testId',
                                    ),
                                    _infoBadge(
                                      icon: Icons.receipt_long_rounded,
                                      label: 'Consult #$consultId',
                                    ),
                                    if (widget.patientName.isNotEmpty &&
                                        widget.patientName != '-')
                                      _infoBadge(
                                        icon: Icons.person_outline_rounded,
                                        label: widget.patientName,
                                        color: AppTheme.primary,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Error Message Banner (if any)
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Field 1: Test Result Description
                    Row(
                      children: [
                        const Text(
                          'Test Result Description',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            color: AppTheme.error,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descriptionCtrl,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText:
                            'Enter findings, measured values, reference range comparison, or clinical observations...',
                        hintStyle: TextStyle(
                          color: AppTheme.textHint,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Field 2: Technician Notes
                    Row(
                      children: [
                        const Text(
                          'Technician Notes',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesCtrl,
                      minLines: 2,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText:
                            'Any additional instructions, sample remarks, or notes for the doctor...',
                        hintStyle: TextStyle(
                          color: AppTheme.textHint,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Field 3: Report File Attachment
                    Row(
                      children: [
                        const Text(
                          'Report Attachment',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_pickedFile == null)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _submitting ? null : _pickFile,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryLight.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap to upload lab report or image',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'PDF, DOC, DOCX, JPG, PNG (Max 10MB)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getFileColor(
                                  _pickedFile!.extension,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getFileIcon(_pickedFile!.extension),
                                color: _getFileColor(_pickedFile!.extension),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFile!.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatFileSize(_pickedFile!.size),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _submitting ? null : _pickFile,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppTheme.primary,
                              ),
                              child: const Text('Change'),
                            ),
                            IconButton(
                              onPressed: _submitting
                                  ? null
                                  : () => setState(() => _pickedFile = null),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppTheme.error,
                                size: 20,
                              ),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _submitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Submitting...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded,
                                      size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Submit Result',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'doc':
      case 'docx':
        return const Color(0xFF2563EB);
      case 'jpg':
      case 'jpeg':
      case 'png':
        return const Color(0xFF059669);
      default:
        return AppTheme.primary;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View Test Result Modal Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ViewTestResultSheet extends StatelessWidget {
  final Map<String, dynamic> test;
  final String patientName;

  const _ViewTestResultSheet({
    required this.test,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    final id = test['id'] as int?;
    final testName = test['testName']?.toString() ?? 'Lab Test';
    final consultId = test['consultationId']?.toString() ?? '-';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lab Test Result',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Completed test details and clinical findings',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppTheme.background,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Content with FutureBuilder
          Flexible(
            child: id == null
                ? const SizedBox.shrink()
                : FutureBuilder<Map<String, dynamic>?>(
                    future: TestResultsApiService.getByLabTestId(id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(36),
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          ),
                        );
                      }
                      final result = snapshot.data;
                      if (result == null) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: AppTheme.background,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  size: 28,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No Result Found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No result has been recorded for this test yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final description =
                          result['testResultDescription']?.toString() ?? '-';
                      final notes =
                          result['technicianNotes']?.toString() ?? '';

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Test context card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5)
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF065F46),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          testName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: #$id  •  Consultation #$consultId  •  $patientName',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF065F46),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Result findings
                            const Text(
                              'Findings & Clinical Description',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),

                            // Notes (if present)
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'Technician Notes',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  notes,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.45,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Close Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
