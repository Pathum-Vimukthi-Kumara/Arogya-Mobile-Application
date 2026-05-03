import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../services/lab_test_api_service.dart';
import '../services/consultation_api_service.dart';
import '../services/user_api_service.dart';

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
      final data = await LabTestApiService.list();
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
      await Future.wait([_hydratePatientDetails(tests)], eagerError: false);

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
                  : _filteredTests.isEmpty
                  ? Center(
                      child: Text(
                        'No lab tests found',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
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
                                          onPressed: () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'Take Test - Coming Soon',
                                                ),
                                                backgroundColor:
                                                    AppTheme.primary,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
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
                                          onPressed: () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'View Result - Coming Soon',
                                                ),
                                                backgroundColor:
                                                    AppTheme.primary,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
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
          ],
        ),
      ),
    );
  }
}
