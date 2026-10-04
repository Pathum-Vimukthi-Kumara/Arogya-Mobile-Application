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
  final String? initialStatusFilter;

  const LabTestsScreen({
    super.key,
    required this.currentUser,
    this.initialStatusFilter,
  });

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
    if (widget.initialStatusFilter != null &&
        _statusOptions.contains(widget.initialStatusFilter)) {
      _statusFilter = widget.initialStatusFilter!;
    }
    _loadLabTests();
  }

  @override
  void didUpdateWidget(covariant LabTestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStatusFilter != null &&
        widget.initialStatusFilter != oldWidget.initialStatusFilter &&
        _statusOptions.contains(widget.initialStatusFilter)) {
      setState(() {
        _statusFilter = widget.initialStatusFilter!;
        _filterTests();
      });
    }
  }

  void setFilter(String status) {
    if (_statusOptions.contains(status)) {
      setState(() {
        _statusFilter = status;
        _filterTests();
      });
    }
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
      final data = await LabTestApiService.list(size: 1000);
      if (!mounted) return;

      final tests = data.whereType<Map<String, dynamic>>().toList();

      setState(() {
        _labTests = tests;
      });

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
        _error = e.toString().replaceFirst('Exception: ', '');
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
          } catch (_) {
            try {
              final user = await UserApiService.getUserById(patientId);
              if (user.username.isNotEmpty) {
                patientName = user.username;
              }
            } catch (_) {}
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
      } catch (_) {
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
        } catch (_) {}
      }),
      eagerError: false,
    );
  }

  Future<void> _updateLabTestStatus(
    Map<String, dynamic> test,
    String newStatus,
  ) async {
    final id = test['id'] as int?;
    if (id == null) return;

    try {
      if (newStatus == 'IN_PROGRESS') {
        try {
          await LabTestApiService.startTest(id);
        } catch (_) {
          await LabTestApiService.updateStatus(id, {'status': 'IN_PROGRESS'});
        }
      } else if (newStatus == 'COMPLETED') {
        try {
          await LabTestApiService.completeTest(id);
        } catch (_) {
          await LabTestApiService.updateStatus(id, {'status': 'COMPLETED'});
        }
      } else {
        await LabTestApiService.updateStatus(id, {'status': newStatus});
      }

      if (mounted) {
        setState(() {
          test['status'] = newStatus;
        });
        _filterTests();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test #$id marked as ${newStatus.replaceAll('_', ' ')}',
            ),
            backgroundColor: AppTheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update status: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
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
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    // Auto-start test if it is currently pending
    final status = test['status']?.toString().toUpperCase() ?? 'PENDING';
    if (status == 'PENDING') {
      try {
        await LabTestApiService.startTest(test['id'] as int);
        if (mounted) {
          setState(() {
            test['status'] = 'IN_PROGRESS';
          });
        }
      } catch (_) {}
    }

    if (!mounted) return;

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
      await _loadLabTests();
      if (!mounted) return;
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
    final patientId = patientInfo?['patientId'] as int? ?? 0;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ViewTestResultSheet(
        test: test,
        patientName: patientName,
        patientId: patientId,
        currentUser: widget.currentUser,
      ),
    );

    if (changed == true && mounted) {
      await _loadLabTests();
    }
  }

  String _getDisplayStatus(Map<String, dynamic> test) {
    final status = test['status']?.toString().toUpperCase() ?? 'PENDING';
    if (status == 'PENDING' && _resultExistsByLabTest[test['id']] == true) {
      return 'COMPLETED';
    }
    return status;
  }

  void _filterTests() {
    var filtered = _labTests;

    if (_statusFilter != 'ALL') {
      filtered = filtered
          .where((test) => _getDisplayStatus(test) == _statusFilter)
          .toList();
    }

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
        return const Color(0xFFEDE9FE);
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
        return Icons.hourglass_top_rounded;
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
            'Lab Tests Worklist',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          elevation: 0,
          systemOverlayStyle: AppTheme.overlayLight,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loading ? null : _loadLabTests,
            ),
          ],
        ),
        body: Column(
          children: [
            // Status Filter Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
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
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

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
                  decoration: const InputDecoration(
                    hintText:
                        'Search test name, patient, ID, consultation...',
                    hintStyle: TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Error Message
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
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
                                      MediaQuery.of(context).size.height * 0.45,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.biotech_outlined,
                                          size: 48,
                                          color: AppTheme.textHint,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No lab tests found',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: _filteredTests.length,
                              itemBuilder: (context, index) {
                                final test = _filteredTests[index];
                                final displayStatus = _getDisplayStatus(test);
                                final patientInfo =
                                    _patientByConsultation[test['consultationId']];
                                final hasRecordedResult =
                                    _resultExistsByLabTest[test['id']] == true;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: AppTheme.border),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header: ID + Status + Options Menu
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'ID: #${test['id']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (hasRecordedResult &&
                                                    displayStatus !=
                                                        'COMPLETED') ...[
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    margin:
                                                        const EdgeInsets.only(
                                                      right: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFFEF3C7,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        12,
                                                      ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFFDE68A,
                                                        ),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Result recorded',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFF92400E),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(
                                                      displayStatus,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      20,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    displayStatus.replaceAll(
                                                      '_',
                                                      ' ',
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          _getStatusTextColor(
                                                        displayStatus,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Quick Status popup menu
                                                PopupMenuButton<String>(
                                                  icon: const Icon(
                                                    Icons.more_vert_rounded,
                                                    size: 18,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                  tooltip: 'Change Status',
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      12,
                                                    ),
                                                  ),
                                                  onSelected: (newStatus) =>
                                                      _updateLabTestStatus(
                                                    test,
                                                    newStatus,
                                                  ),
                                                  itemBuilder: (context) => [
                                                    if (displayStatus !=
                                                        'IN_PROGRESS')
                                                      const PopupMenuItem(
                                                        value: 'IN_PROGRESS',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .hourglass_top_rounded,
                                                              size: 16,
                                                              color: Color(
                                                                0xFF6B21A8,
                                                              ),
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(
                                                              'Mark as In Progress',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    if (displayStatus !=
                                                        'COMPLETED')
                                                      const PopupMenuItem(
                                                        value: 'COMPLETED',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .check_circle_outline_rounded,
                                                              size: 16,
                                                              color: Color(
                                                                0xFF065F46,
                                                              ),
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(
                                                              'Mark as Completed',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Test Name
                                        Row(
                                          children: [
                                            Icon(
                                              _getStatusIcon(displayStatus),
                                              size: 20,
                                              color: _getStatusTextColor(
                                                displayStatus,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                test['testName']?.toString() ??
                                                    'Lab Test',
                                                style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Consultation & Patient
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Consultation',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '# ${test['consultationId']}',
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppTheme.textPrimary,
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
                                                  const Text(
                                                    'Patient',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    patientInfo?['name'] ??
                                                        'Loading...',
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppTheme.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Created At
                                        Text(
                                          'Created: ${_formatDateTime(test['createdAt']?.toString())}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 14),

                                        // Actions Row
                                        if (displayStatus == 'COMPLETED')
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _viewTestResult(test),
                                              icon: const Icon(
                                                Icons.visibility_outlined,
                                                size: 18,
                                              ),
                                              label: const Text('View Result'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppTheme.primary,
                                                side: const BorderSide(
                                                  color: AppTheme.primary,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          )
                                        else if (displayStatus == 'IN_PROGRESS')
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      hasRecordedResult
                                                          ? _viewTestResult(test)
                                                          : _submitTestResult(test),
                                                  icon: Icon(
                                                    hasRecordedResult
                                                        ? Icons.edit_note_rounded
                                                        : Icons.add_task_rounded,
                                                    size: 18,
                                                  ),
                                                  label: Text(
                                                    hasRecordedResult
                                                        ? 'View / Edit Result'
                                                        : 'Submit Result',
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppTheme.primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _updateLabTestStatus(
                                                  test,
                                                  'COMPLETED',
                                                ),
                                                icon: const Icon(
                                                  Icons
                                                      .check_circle_outline_rounded,
                                                  size: 16,
                                                ),
                                                label: const Text('Complete'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(
                                                    0xFF065F46,
                                                  ),
                                                  side: const BorderSide(
                                                    color: Color(0xFF10B981),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 12,
                                                  ),
                                                  shape:
                                                      RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      10,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        else // PENDING
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _submitTestResult(test),
                                                  icon: const Icon(
                                                    Icons.play_arrow_rounded,
                                                    size: 18,
                                                  ),
                                                  label:
                                                      const Text('Take Test'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppTheme.primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _updateLabTestStatus(
                                                  test,
                                                  'IN_PROGRESS',
                                                ),
                                                icon: const Icon(
                                                  Icons.hourglass_top_rounded,
                                                  size: 16,
                                                ),
                                                label: const Text('Start'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(
                                                    0xFF6B21A8,
                                                  ),
                                                  side: const BorderSide(
                                                    color: Color(0xFF8B5CF6),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 12,
                                                  ),
                                                  shape:
                                                      RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      10,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
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
// Submit Test Result Modal Bottom Sheet (Supports Multiple Files & Status Choice)
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
  String _selectedStatus = 'COMPLETED'; // 'COMPLETED' or 'IN_PROGRESS'
  final List<PlatformFile> _pickedFiles = [];
  bool _submitting = false;
  String? _error;

  static const _allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'jpg',
    'jpeg',
    'png',
  ];
  static const _maxFileSizeBytes = 10 * 1024 * 1024;
  static const _maxFiles = 5;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_pickedFiles.length >= _maxFiles) {
      setState(() {
        _error = 'You can attach up to $_maxFiles files';
      });
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final valid = <PlatformFile>[];
      String? validationError;

      for (final file in result.files) {
        if (file.bytes == null) continue;
        if (file.size > _maxFileSizeBytes) {
          validationError = '${file.name} is larger than 10MB';
          continue;
        }
        final ext = file.extension?.toLowerCase();
        if (ext == null || !_allowedExtensions.contains(ext)) {
          validationError = '${file.name} has an unsupported format';
          continue;
        }
        valid.add(file);
      }

      if (_pickedFiles.length + valid.length > _maxFiles) {
        setState(() {
          _error = 'You can attach a maximum of $_maxFiles files in total';
        });
        return;
      }

      setState(() {
        _pickedFiles.addAll(valid);
        _error = validationError;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to pick files: $e';
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final description = _descriptionCtrl.text.trim();
    if (description.isEmpty) {
      setState(() {
        _error = 'Test result description is required.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final testId = widget.test['id'] as int;

      // Map picked files into TestResultUploadFile
      final uploadFiles = _pickedFiles
          .map(
            (f) => TestResultUploadFile(
              bytes: f.bytes!,
              name: f.name,
              mimeType: TestResultsApiService.mimeTypeFor(f.name),
            ),
          )
          .toList();

      await TestResultsApiService.create(
        labTestId: testId,
        patientId: widget.patientId,
        technicianId: widget.currentUser.id,
        testResultDescription: description,
        technicianNotes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        files: uploadFiles,
      );

      // Apply the chosen status to lab-test-service
      if (_selectedStatus == 'COMPLETED') {
        try {
          await LabTestApiService.completeTest(testId);
        } catch (_) {
          try {
            await LabTestApiService.updateStatus(testId, {
              'status': 'COMPLETED',
            });
          } catch (_) {}
        }
      } else {
        try {
          await LabTestApiService.updateStatus(testId, {
            'status': 'IN_PROGRESS',
          });
        } catch (_) {
          try {
            await LabTestApiService.startTest(testId);
          } catch (_) {}
        }
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
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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

            // Header
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
                          'Record findings, upload reports, and set test status',
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

            // Scrollable Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context Banner (Matches media_1791093034637.png)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.biotech_rounded,
                              color: Color(0xFF2563EB),
                              size: 22,
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
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Test ID: #$testId  •  Consultation #$consultId  •  ${widget.patientName}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF3B82F6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Status Selection Option
                    const Text(
                      'Test Status',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose whether to finalize as completed or keep in progress',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _statusChoiceCard(
                            title: 'Completed',
                            subtitle: 'Finalize & complete test',
                            value: 'COMPLETED',
                            icon: Icons.check_circle_rounded,
                            activeColor: const Color(0xFF10B981),
                            bgActive: const Color(0xFFD1FAE5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statusChoiceCard(
                            title: 'In Progress',
                            subtitle: 'Save findings & continue',
                            value: 'IN_PROGRESS',
                            icon: Icons.hourglass_top_rounded,
                            activeColor: const Color(0xFF8B5CF6),
                            bgActive: const Color(0xFFEDE9FE),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Error Banner
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
                              size: 18,
                            ),
                            const SizedBox(width: 8),
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

                    // Field 1: Test Result Description *
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
                        hintText: 'Enter detailed test results...',
                        hintStyle: const TextStyle(
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

                    // Field 2: Technician Notes (Optional)
                    const Row(
                      children: [
                        Text(
                          'Technician Notes',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesCtrl,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Additional notes...',
                        hintStyle: const TextStyle(
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

                    // Field 3: Upload Files (Optional, up to 5)
                    _buildFilesSection(),
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _selectedStatus == 'COMPLETED'
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.save_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedStatus == 'COMPLETED'
                                        ? 'Submit Result'
                                        : 'Save Findings',
                                    style: const TextStyle(
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

  Widget _statusChoiceCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color activeColor,
    required Color bgActive,
  }) {
    final isSelected = _selectedStatus == value;
    return InkWell(
      onTap: _submitting ? null : () => setState(() => _selectedStatus = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? bgActive : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.border,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? activeColor : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesSection() {
    final count = _pickedFiles.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Text(
                  'Upload Files',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  '(Optional, up to 5)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (count > 0)
              Text(
                '$count / $_maxFiles',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Upload Drop/Tap Area (Matches web's SubmitTestResultModal)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _submitting || count >= _maxFiles ? null : _pickFiles,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: count >= _maxFiles
                    ? const Color(0xFFF3F4F6)
                    : AppTheme.primaryLight.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: count >= _maxFiles
                      ? const Color(0xFFD1D5DB)
                      : AppTheme.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: count >= _maxFiles
                          ? const Color(0xFFE5E7EB)
                          : AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      color: count >= _maxFiles ? Colors.grey : AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    count >= _maxFiles
                        ? 'Maximum of $_maxFiles files reached'
                        : 'Click to upload or select files',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: count >= _maxFiles
                          ? AppTheme.textSecondary
                          : AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'PDF, DOC, DOCX, JPG, PNG (max 10MB each)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Picked Files List
        if (_pickedFiles.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._pickedFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            final ext = file.extension?.toLowerCase();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getFileColor(ext).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileIcon(ext),
                      color: _getFileColor(ext),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatFileSize(file.size),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _submitting ? null : () => _removeFile(index),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Test Result Modal Bottom Sheet (Matches media_1791093141747.png)
// ─────────────────────────────────────────────────────────────────────────────

class _EditTestResultSheet extends StatefulWidget {
  final Map<String, dynamic> test;
  final String patientName;
  final int patientId;
  final Map<String, dynamic> testResult;
  final User currentUser;

  const _EditTestResultSheet({
    required this.test,
    required this.patientName,
    required this.patientId,
    required this.testResult,
    required this.currentUser,
  });

  @override
  State<_EditTestResultSheet> createState() => _EditTestResultSheetState();
}

class _EditTestResultSheetState extends State<_EditTestResultSheet> {
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _notesCtrl;
  late String _selectedStatus;
  final List<Map<String, dynamic>> _keptFiles = [];
  final List<int> _removedFileIds = [];
  final List<PlatformFile> _newFiles = [];
  bool _updating = false;
  String? _error;

  static const _allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'jpg',
    'jpeg',
    'png',
  ];
  static const _maxFileSizeBytes = 10 * 1024 * 1024;
  static const _maxFiles = 5;

  @override
  void initState() {
    super.initState();
    _descriptionCtrl = TextEditingController(
      text: widget.testResult['testResultDescription']?.toString() ?? '',
    );
    _notesCtrl = TextEditingController(
      text: widget.testResult['technicianNotes']?.toString() ?? '',
    );
    _selectedStatus =
        widget.test['status']?.toString().toUpperCase() ?? 'COMPLETED';

    if (widget.testResult['files'] is List) {
      for (final f in (widget.testResult['files'] as List)) {
        if (f is Map) {
          _keptFiles.add(Map<String, dynamic>.from(f));
        }
      }
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _totalCount => _keptFiles.length + _newFiles.length;

  Future<void> _pickNewFiles() async {
    if (_totalCount >= _maxFiles) {
      setState(() {
        _error = 'You can attach up to $_maxFiles files';
      });
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final valid = <PlatformFile>[];
      String? validationError;

      for (final file in result.files) {
        if (file.bytes == null) continue;
        if (file.size > _maxFileSizeBytes) {
          validationError = '${file.name} is larger than 10MB';
          continue;
        }
        final ext = file.extension?.toLowerCase();
        if (ext == null || !_allowedExtensions.contains(ext)) {
          validationError = '${file.name} has an unsupported format';
          continue;
        }
        valid.add(file);
      }

      if (_totalCount + valid.length > _maxFiles) {
        setState(() {
          _error = 'You can attach a maximum of $_maxFiles files in total';
        });
        return;
      }

      setState(() {
        _newFiles.addAll(valid);
        _error = validationError;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to pick files: $e';
      });
    }
  }

  void _removeExistingFile(int index) {
    setState(() {
      final file = _keptFiles.removeAt(index);
      final id = file['id'] as int?;
      if (id != null) {
        _removedFileIds.add(id);
      }
    });
  }

  void _removeNewFile(int index) {
    setState(() {
      _newFiles.removeAt(index);
    });
  }

  Future<void> _update() async {
    final description = _descriptionCtrl.text.trim();
    if (description.isEmpty) {
      setState(() {
        _error = 'Test result description is required.';
      });
      return;
    }

    setState(() {
      _updating = true;
      _error = null;
    });

    try {
      final resultId = widget.testResult['id'] as int;
      final testId = widget.test['id'] as int;

      final uploadFiles = _newFiles
          .map(
            (f) => TestResultUploadFile(
              bytes: f.bytes!,
              name: f.name,
              mimeType: TestResultsApiService.mimeTypeFor(f.name),
            ),
          )
          .toList();

      await TestResultsApiService.update(
        resultId,
        testResultDescription: description,
        technicianNotes: _notesCtrl.text.trim(),
        files: uploadFiles,
        removeFileIds: _removedFileIds,
      );

      // Apply selected status
      if (_selectedStatus == 'COMPLETED') {
        try {
          await LabTestApiService.completeTest(testId);
        } catch (_) {
          try {
            await LabTestApiService.updateStatus(testId, {
              'status': 'COMPLETED',
            });
          } catch (_) {}
        }
      } else {
        try {
          await LabTestApiService.updateStatus(testId, {
            'status': 'IN_PROGRESS',
          });
        } catch (_) {
          try {
            await LabTestApiService.startTest(testId);
          } catch (_) {}
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updating = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final testName = widget.test['testName']?.toString() ?? 'Lab Test';
    final testId = widget.test['id']?.toString() ?? '-';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Test Result',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Update findings, notes, files, and status',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _updating
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

            // Scrollable Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFF2563EB),
                              size: 22,
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
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Test ID: #$testId  •  ${widget.patientName}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF3B82F6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Status Selector
                    const Text(
                      'Test Status',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _statusChoiceCard(
                            title: 'Completed',
                            subtitle: 'Finalize & complete test',
                            value: 'COMPLETED',
                            icon: Icons.check_circle_rounded,
                            activeColor: const Color(0xFF10B981),
                            bgActive: const Color(0xFFD1FAE5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statusChoiceCard(
                            title: 'In Progress',
                            subtitle: 'Save findings & continue',
                            value: 'IN_PROGRESS',
                            icon: Icons.hourglass_top_rounded,
                            activeColor: const Color(0xFF8B5CF6),
                            bgActive: const Color(0xFFEDE9FE),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Error Banner
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
                              size: 18,
                            ),
                            const SizedBox(width: 8),
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

                    // Description *
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
                        hintText: 'Enter detailed test results...',
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

                    // Technician Notes
                    const Row(
                      children: [
                        Text(
                          'Technician Notes',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesCtrl,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Additional notes...',
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

                    // Files section (Existing + New up to 5)
                    _buildEditFilesSection(),
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
                        onPressed: _updating
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
                        onPressed: _updating ? null : _update,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _updating
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
                                    'Updating...',
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
                                  Icon(Icons.check_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Update Result',
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

  Widget _statusChoiceCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color activeColor,
    required Color bgActive,
  }) {
    final isSelected = _selectedStatus == value;
    return InkWell(
      onTap: _updating ? null : () => setState(() => _selectedStatus = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? bgActive : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.border,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? activeColor : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditFilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Files (up to 5)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              '$_totalCount / $_maxFiles',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Kept Existing Files
        if (_keptFiles.isNotEmpty) ...[
          ..._keptFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            final fileName = file['fileName']?.toString() ?? 'File';
            final ext = fileName.split('.').last.toLowerCase();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getFileColor(ext).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileIcon(ext),
                      color: _getFileColor(ext),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Existing Attachment',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _updating
                        ? null
                        : () => _removeExistingFile(index),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
          }),
        ],

        // Upload zone for adding more files
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _updating || _totalCount >= _maxFiles ? null : _pickNewFiles,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: _totalCount >= _maxFiles
                    ? const Color(0xFFF3F4F6)
                    : AppTheme.primaryLight.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _totalCount >= _maxFiles
                      ? const Color(0xFFD1D5DB)
                      : AppTheme.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _totalCount >= _maxFiles
                          ? const Color(0xFFE5E7EB)
                          : AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      color: _totalCount >= _maxFiles
                          ? Colors.grey
                          : AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _totalCount >= _maxFiles
                        ? 'Maximum of $_maxFiles files reached'
                        : 'Click to add more files',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _totalCount >= _maxFiles
                          ? AppTheme.textSecondary
                          : AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'PDF, DOC, DOCX, JPG, PNG (max 10MB each)',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Newly added files
        if (_newFiles.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._newFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            final ext = file.extension?.toLowerCase();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getFileColor(ext).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileIcon(ext),
                      color: _getFileColor(ext),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatFileSize(file.size)}  •  New',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _updating ? null : () => _removeNewFile(index),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View Test Result Modal Bottom Sheet (Files list, Download/Preview, Edit, Delete)
// ─────────────────────────────────────────────────────────────────────────────

class _ViewTestResultSheet extends StatefulWidget {
  final Map<String, dynamic> test;
  final String patientName;
  final int patientId;
  final User currentUser;

  const _ViewTestResultSheet({
    required this.test,
    required this.patientName,
    required this.patientId,
    required this.currentUser,
  });

  @override
  State<_ViewTestResultSheet> createState() => _ViewTestResultSheetState();
}

class _ViewTestResultSheetState extends State<_ViewTestResultSheet> {
  Map<String, dynamic>? _testResult;
  bool _loading = true;
  String? _error;
  int? _downloadingFileId;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadResult();
  }

  Future<void> _loadResult() async {
    final id = widget.test['id'] as int?;
    if (id == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await TestResultsApiService.getByLabTestId(id);
      if (!mounted) return;
      setState(() {
        _testResult = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _toggleStatus() async {
    final currentStatus =
        widget.test['status']?.toString().toUpperCase() ?? 'COMPLETED';
    final targetStatus =
        currentStatus == 'COMPLETED' ? 'IN_PROGRESS' : 'COMPLETED';
    final id = widget.test['id'] as int;

    try {
      if (targetStatus == 'IN_PROGRESS') {
        try {
          await LabTestApiService.startTest(id);
        } catch (_) {
          await LabTestApiService.updateStatus(id, {'status': 'IN_PROGRESS'});
        }
      } else {
        try {
          await LabTestApiService.completeTest(id);
        } catch (_) {
          await LabTestApiService.updateStatus(id, {'status': 'COMPLETED'});
        }
      }

      if (!mounted) return;
      setState(() {
        widget.test['status'] = targetStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Test marked as ${targetStatus.replaceAll('_', ' ')}',
          ),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _downloadOrPreviewFile(Map<String, dynamic> file) async {
    final resultId = _testResult?['id'] as int?;
    final fileId = file['id'] as int?;
    final fileName = file['fileName']?.toString() ?? 'report';
    if (resultId == null || fileId == null) return;

    setState(() => _downloadingFileId = fileId);

    try {
      final bytes = await TestResultsApiService.downloadFile(resultId, fileId);
      if (!mounted) return;

      final ext = fileName.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png'].contains(ext)) {
        _showImagePreview(context, fileName, bytes);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully downloaded $fileName (${_formatFileSize(bytes.length)})',
            ),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download file: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingFileId = null);
      }
    }
  }

  void _showImagePreview(
    BuildContext context,
    String fileName,
    List<int> bytes,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.primary,
              child: Row(
                children: [
                  const Icon(
                    Icons.image_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              maxScale: 4.0,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: Image.memory(
                  Uint8List.fromList(bytes),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditModal() async {
    if (_testResult == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditTestResultSheet(
        test: widget.test,
        patientName: widget.patientName,
        patientId: widget.patientId,
        testResult: _testResult!,
        currentUser: widget.currentUser,
      ),
    );

    if (updated == true && mounted) {
      await _loadResult();
    }
  }

  Future<void> _confirmDelete() async {
    final resultId = _testResult?['id'] as int?;
    if (resultId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Test Result?'),
        content: const Text(
          'This will permanently delete the test result and any attached files. '
          'The test status will revert to In Progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      await TestResultsApiService.delete(resultId);

      // Revert test status back to IN_PROGRESS
      try {
        await LabTestApiService.startTest(widget.test['id'] as int);
      } catch (_) {
        try {
          await LabTestApiService.updateStatus(widget.test['id'] as int, {
            'status': 'IN_PROGRESS',
          });
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete result: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.test['id'] as int?;
    final testName = widget.test['testName']?.toString() ?? 'Lab Test';
    final consultId = widget.test['consultationId']?.toString() ?? '-';
    final currentStatus =
        widget.test['status']?.toString().toUpperCase() ?? 'COMPLETED';

    return Container(
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

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lab Test Result Details',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Completed test details, clinical findings, and attachments',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(true),
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

          // Content
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(36),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _testResult == null
                    ? Padding(
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
                            const Text(
                              'No result has been recorded for this test yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Test Banner
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.biotech_rounded,
                                      color: Color(0xFF2563EB),
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
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: #$id  •  Consultation #$consultId  •  ${widget.patientName}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF3B82F6),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Status Card with Quick Toggle
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Status: ',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: currentStatus == 'COMPLETED'
                                              ? const Color(0xFFD1FAE5)
                                              : const Color(0xFFEDE9FE),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          currentStatus.replaceAll('_', ' '),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: currentStatus == 'COMPLETED'
                                                ? const Color(0xFF065F46)
                                                : const Color(0xFF6B21A8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: _toggleStatus,
                                    icon: Icon(
                                      currentStatus == 'COMPLETED'
                                          ? Icons.hourglass_top_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: 15,
                                    ),
                                    label: Text(
                                      currentStatus == 'COMPLETED'
                                          ? 'Switch to In Progress'
                                          : 'Mark as Completed',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor:
                                          currentStatus == 'COMPLETED'
                                              ? const Color(0xFF6B21A8)
                                              : const Color(0xFF065F46),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Findings & Description
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
                              child: SelectableText(
                                _testResult!['testResultDescription']
                                        ?.toString() ??
                                    '-',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),

                            // Technician Notes (if any)
                            if ((_testResult!['technicianNotes'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
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
                                child: SelectableText(
                                  _testResult!['technicianNotes'].toString(),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.45,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],

                            // Attached Files List
                            if (_testResult!['files'] is List &&
                                (_testResult!['files'] as List).isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text(
                                'Attached Files (${(_testResult!['files'] as List).length})',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...(_testResult!['files'] as List)
                                  .whereType<Map>()
                                  .map((rawFile) {
                                final file =
                                    Map<String, dynamic>.from(rawFile);
                                final fileName =
                                    file['fileName']?.toString() ?? 'File';
                                final ext =
                                    fileName.split('.').last.toLowerCase();
                                final isImage =
                                    ['jpg', 'jpeg', 'png'].contains(ext);
                                final size = file['fileSize'] as int? ?? 0;
                                final fileId = file['id'] as int?;
                                final isDownloading =
                                    _downloadingFileId == fileId;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: _getFileColor(ext)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getFileIcon(ext),
                                          color: _getFileColor(ext),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileName,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatFileSize(size),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isImage)
                                        TextButton.icon(
                                          onPressed: isDownloading
                                              ? null
                                              : () =>
                                                  _downloadOrPreviewFile(file),
                                          icon: isDownloading
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 1.8,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.visibility_outlined,
                                                  size: 15,
                                                ),
                                          label: const Text('Preview'),
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            foregroundColor: AppTheme.primary,
                                          ),
                                        ),
                                      IconButton(
                                        onPressed: isDownloading
                                            ? null
                                            : () =>
                                                _downloadOrPreviewFile(file),
                                        icon: const Icon(
                                          Icons.download_rounded,
                                          size: 19,
                                          color: AppTheme.primary,
                                        ),
                                        tooltip: 'Download file',
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            const SizedBox(height: 24),

                            // Action Buttons Row: Edit / Delete
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _openEditModal,
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      size: 17,
                                    ),
                                    label: const Text('Edit Result'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed:
                                      _deleting ? null : _confirmDelete,
                                  icon: _deleting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFDC2626),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 17,
                                        ),
                                  label: const Text('Delete'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(
                                      color: Color(0xFFFCA5A5),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                  onPressed: () => Navigator.of(context).pop(true),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared Helper Methods for File Type & Formatting
// ─────────────────────────────────────────────────────────────────────────────

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
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(2)} KB';
}
