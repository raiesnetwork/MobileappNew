import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/communities_provider.dart';
import '../../providers/service_request_provider.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  final String? communityId;
  final Map<String, dynamic>? request;

  const CreateServiceRequestScreen(
      {Key? key, this.communityId, this.request})
      : super(key: key);

  @override
  State<CreateServiceRequestScreen> createState() =>
      _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState
    extends State<CreateServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedCategory = '';
  String _selectedPriority = '';
  String _selectedAssignedTo = '';
  String _selectedSource = 'Manual';
  DateTime? _selectedDueDate;

  bool _isSubmitting = false;
  bool _isLoadingMembers = true;
  List<Map<String, dynamic>> _communityMembers = [];

  static const _accent = Color(0xFF6C5CE7);

  final List<String> _categories = [
    'Access_Request',
    'Billing / Payment',
    'Cleaning',
    'Complaint an issue',
    'Electrical',
    'Feedback',
    'Internet / Network',
    'Maintenance',
    'Others',
    'Plumbing',
    'Security',
    'Software / IT',
  ];

  final List<Map<String, String>> _priorities = [
    {
      'value': 'Critical – Business/essential function is blocked',
      'label': 'Critical',
      'description': 'Business/essential function is blocked',
    },
    {
      'value': 'High – Needs action soon, moderate impact',
      'label': 'High',
      'description': 'Needs action soon, moderate impact',
    },
    {
      'value': 'Medium – Needs attention within a few hours',
      'label': 'Medium',
      'description': 'Needs attention within a few hours',
    },
    {
      'value': 'Low – Not urgent, can wait',
      'label': 'Low',
      'description': 'Not urgent, can wait',
    },
  ];

  final List<String> _sources = ['Manual', 'Email', 'Call'];

  @override
  void initState() {
    super.initState();
    if (widget.request != null) {
      final r = widget.request!;
      _subjectController.text = r['subject'] ?? '';
      _descriptionController.text = r['description'] ?? '';
      _emailController.text = r['email'] ?? '';
      _selectedCategory = r['category'] ?? '';
      _selectedPriority = r['priority'] ?? '';
      _selectedAssignedTo = r['assignedTo']?['_id'] ?? '';
      _selectedSource = r['source'] ?? 'Manual';
      if (r['dueDate'] != null) {
        try {
          _selectedDueDate = DateTime.parse(r['dueDate']);
        } catch (_) {}
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  Future<void> _loadMembers() async {
    if (widget.communityId == null) {
      setState(() => _isLoadingMembers = false);
      return;
    }
    try {
      final result = await Provider.of<CommunityProvider>(context,
          listen: false)
          .fetchCommunityUsers(widget.communityId!);
      if (result['error'] == false && result['data'] != null) {
        setState(() {
          _communityMembers =
          List<Map<String, dynamic>>.from(result['data']);
          _isLoadingMembers = false;
        });
      } else {
        setState(() => _isLoadingMembers = false);
      }
    } catch (_) {
      setState(() => _isLoadingMembers = false);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.request != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Request' : 'New Service Request',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        scrolledUnderElevation: 0,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEF5)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section 1: Request Details
              _sectionCard(
                title: 'Request Details',
                icon: Icons.assignment_outlined,
                children: [
                  _buildTextField(
                    controller: _subjectController,
                    label: 'Subject',
                    required: true,
                    hint: 'Brief title of the issue',
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    required: true,
                    maxLines: 4,
                    hint: 'Describe the issue in detail',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Section 2: Classification
              _sectionCard(
                title: 'Classification',
                icon: Icons.tune_outlined,
                children: [
                  _buildCategorySelector(),
                  const SizedBox(height: 14),
                  _buildPrioritySelector(),
                ],
              ),
              const SizedBox(height: 14),

              // ── Section 3: Assignment & Schedule
              _sectionCard(
                title: 'Assignment & Schedule',
                icon: Icons.people_outline,
                children: [
                  _buildAssignedToSelector(),
                  const SizedBox(height: 14),
                  _buildDueDatePicker(),
                ],
              ),
              const SizedBox(height: 14),

              // ── Section 4: Source Info
              _sectionCard(
                title: 'Source Information',
                icon: Icons.input_outlined,
                children: [
                  _buildSourceSelector(),
                  if (_selectedSource == 'Email') ...[
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      required: false,
                      hint: 'Requester email (optional)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // ── Submit Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.grey[700])),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                          : Text(
                        isEditing ? 'Update Request' : 'Create Request',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SECTION CARD WRAPPER
  // ─────────────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: _accent),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E))),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TEXT FIELD
  // ─────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool required,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, required: required),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: _inputDecoration(hint: hint),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty)
              ? '$label is required'
              : null
              : null,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // CATEGORY DROPDOWN
  // ─────────────────────────────────────────────
  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Category', required: true),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedCategory.isEmpty ? null : _selectedCategory,
          decoration: _inputDecoration(hint: 'Select a category'),
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v ?? ''),
          validator: (v) =>
          (v == null || v.isEmpty) ? 'Category is required' : null,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // PRIORITY SELECTOR (tap cards)
  // ─────────────────────────────────────────────
  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Priority', required: true),
        const SizedBox(height: 8),
        ..._priorities.map((p) {
          final isSelected = _selectedPriority == p['value'];
          final color = _priorityColor(p['label']!);
          return GestureDetector(
            onTap: () => setState(() => _selectedPriority = p['value']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.08) : Colors.white,
                border: Border.all(
                  color: isSelected ? color : Colors.grey[200]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Radio circle
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.transparent,
                      border: Border.all(
                          color: isSelected ? color : Colors.grey[400]!,
                          width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                        size: 10, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag_rounded, size: 13, color: color),
                            const SizedBox(width: 5),
                            Text(p['label']!,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? color
                                        : const Color(0xFF1A1A2E))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(p['description']!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        if (_selectedPriority.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Priority is required',
                style: TextStyle(fontSize: 11, color: Colors.red[700])),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ASSIGNED TO
  // ─────────────────────────────────────────────
  Widget _buildAssignedToSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Assign To', required: false),
        const SizedBox(height: 6),
        _isLoadingMembers
            ? _loadingField()
            : DropdownButtonFormField<String>(
          value: _selectedAssignedTo.isEmpty
              ? null
              : _selectedAssignedTo,
          decoration: _inputDecoration(
              hint: 'Select a member (optional)',
              prefixIcon: Icons.person_outline),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[500]),
          items: [
            const DropdownMenuItem<String>(
                value: '', child: Text('Unassigned')),
            ..._communityMembers.map((m) {
              final userData =
              m['userId'] as Map<String, dynamic>?;
              String name = 'Unknown User';
              if (userData != null) {
                final profile = userData['profile']
                as Map<String, dynamic>?;
                if (profile?['name'] != null &&
                    profile!['name'].toString().trim().isNotEmpty) {
                  name = profile['name'].toString().trim();
                } else if (userData['email'] != null) {
                  name = userData['email']
                      .toString()
                      .split('@')
                      .first;
                }
              }
              final userId = userData?['_id']?.toString() ??
                  m['_id']?.toString() ??
                  '';
              return DropdownMenuItem<String>(
                value: userId,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundImage:
                      _profileImage(userData),
                      backgroundColor: Colors.grey[200],
                      child: _profileImage(userData) == null
                          ? Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w700),
                      )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (v) =>
              setState(() => _selectedAssignedTo = v ?? ''),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // DUE DATE PICKER
  // ─────────────────────────────────────────────
  Widget _buildDueDatePicker() {
    final hasDate = _selectedDueDate != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Due Date', required: false),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDueDate,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FC),
              border: Border.all(
                  color: hasDate
                      ? _accent.withOpacity(0.5)
                      : Colors.grey[200]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: hasDate ? _accent : Colors.grey[400],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasDate
                        ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                        : 'Select due date (optional)',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasDate
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey[400],
                    ),
                  ),
                ),
                if (hasDate)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _selectedDueDate = null),
                    child: Icon(Icons.close,
                        size: 16, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
      _selectedDueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDueDate = picked);
  }

  // ─────────────────────────────────────────────
  // SOURCE SELECTOR
  // ─────────────────────────────────────────────
  Widget _buildSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Source', required: false),
        const SizedBox(height: 8),
        Row(
          children: _sources.map((s) {
            final isSelected = _selectedSource == s;
            final icon = s == 'Manual'
                ? Icons.edit_outlined
                : s == 'Email'
                ? Icons.email_outlined
                : Icons.call_outlined;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedSource = s;
                  if (s != 'Email') _emailController.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(
                      right: s != _sources.last ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _accent.withOpacity(0.1)
                        : const Color(0xFFF8F8FC),
                    border: Border.all(
                      color: isSelected
                          ? _accent
                          : Colors.grey[200]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(icon,
                          size: 20,
                          color: isSelected
                              ? _accent
                              : Colors.grey[500]),
                      const SizedBox(height: 4),
                      Text(s,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? _accent
                                : Colors.grey[600],
                          )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SUBMIT
  // ─────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedPriority.isEmpty) {
      if (_selectedPriority.isEmpty) {
        _showSnack('Please select a priority level', Colors.red);
      }
      return;
    }
    if (_selectedCategory.isEmpty) {
      _showSnack('Please select a category', Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider =
      Provider.of<ServiceRequestProvider>(context, listen: false);

      final dueDateStr = _selectedDueDate?.toIso8601String();

      Map<String, dynamic> result;

      if (widget.request != null) {
        result = await provider.updateServiceRequest(
          requestId: widget.request!['_id'],
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          assignedTo: _selectedAssignedTo.isEmpty
              ? null
              : _selectedAssignedTo,
          status: widget.request!['status'],
          dueDate: dueDateStr,
          communityId: widget.communityId,
        );
      } else {
        result = await provider.createServiceRequest(
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          assignedTo: _selectedAssignedTo.isEmpty
              ? null
              : _selectedAssignedTo,
          communityId: widget.communityId,
          dueDate: dueDateStr,
          source: _selectedSource,
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
        );
      }

      if (result['error'] == false && mounted) {
        _showSnack(
          result['message'] ??
              (widget.request != null
                  ? 'Request updated successfully'
                  : 'Request created successfully'),
          Colors.green,
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        _showSnack(
            result['message'] ?? 'Something went wrong', Colors.red);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  Widget _fieldLabel(String label, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700]),
        children: required
            ? const [
          TextSpan(
              text: ' *', style: TextStyle(color: Colors.red))
        ]
            : null,
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18, color: Colors.grey[400])
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      filled: true,
      fillColor: const Color(0xFFF8F8FC),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _loadingField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FC),
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _accent),
          ),
          const SizedBox(width: 10),
          Text('Loading members...',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }

  ImageProvider? _profileImage(Map<String, dynamic>? userData) {
    if (userData == null) return null;
    final url =
    (userData['profile'] as Map?)? ['profileImage']?.toString();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('data:image')) {
      final uri = UriData.parse(url);
      return MemoryImage(uri.contentAsBytes());
    }
    return null;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'critical': return const Color(0xFFE74C3C);
      case 'high': return const Color(0xFFFF7043);
      case 'medium': return const Color(0xFF3498DB);
      case 'low': return const Color(0xFF00B894);
      default: return Colors.grey;
    }
  }
}