import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/service_request_provider.dart';

class ServiceRequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic>? initialData;
  final String? communityId;

  const ServiceRequestDetailsScreen({
    Key? key,
    required this.requestId,
    this.initialData,
    this.communityId,
  }) : super(key: key);

  @override
  State<ServiceRequestDetailsScreen> createState() =>
      _ServiceRequestDetailsScreenState();
}

class _ServiceRequestDetailsScreenState
    extends State<ServiceRequestDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nextActionController = TextEditingController();
  final _picker = ImagePicker();

  List<File> _pendingFiles = [];
  bool _isUpdatingStatus = false;
  bool _isSavingNote = false;
  bool _isUploadingFiles = false;

  static const _accent = Color(0xFF6C5CE7);

  final List<String> _statusOptions = [
    'Open',
    'In Progress',
    'Completed',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialData == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ServiceRequestProvider>(context, listen: false)
            .getServiceRequestById(widget.requestId);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nextActionController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: Consumer<ServiceRequestProvider>(
        builder: (context, provider, _) {
          final request = provider.currentRequest ?? widget.initialData;

          if (provider.isLoading && widget.initialData == null) {
            return const Center(
                child:
                CircularProgressIndicator(color: _accent));
          }
          if (provider.error != null && widget.initialData == null) {
            return _buildErrorState(provider);
          }
          if (request == null) return _buildNotFound();

          return Column(
            children: [
              _buildHeader(request),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(request),
                    _buildActivityTab(request),
                    _buildAttachmentsTab(request),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Request Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A2E),
      scrolledUnderElevation: 0,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFEEEEF5)),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: () => Provider.of<ServiceRequestProvider>(context,
              listen: false)
              .getServiceRequestById(widget.requestId),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HEADER (status + priority + subject)
  // ─────────────────────────────────────────────
  Widget _buildHeader(Map<String, dynamic> request) {
    final status = request['status'] ?? 'Unknown';
    final priority = request['priority'] ?? '';
    final statusColor = _statusColor(status);
    final priorityColor = _priorityColor(priority);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ID row
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Icon(Icons.tag, size: 11, color: _accent),
                  const SizedBox(width: 3),
                  Text(request['requestId'] ?? 'N/A',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _accent)),
                ]),
              ),
              const Spacer(),
              // Status dropdown
              _buildStatusDropdown(request, statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request['subject'] ?? 'No Subject',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
                height: 1.3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _badge(
                  icon: Icons.flag_rounded,
                  label: _priorityLabel(priority),
                  color: priorityColor),
              _badge(
                  icon: Icons.category_outlined,
                  label: request['category'] ?? 'Uncategorized',
                  color: Colors.grey[600]!,
                  bgColor: Colors.grey[100]!),
              if (request['source'] != null)
                _badge(
                    icon: Icons.input_outlined,
                    label: request['source'],
                    color: Colors.teal,
                    bgColor: Colors.teal.withOpacity(0.08)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(
      Map<String, dynamic> request, Color statusColor) {
    final status = request['status'] ?? 'Open';
    return GestureDetector(
      onTap: () => _showStatusPicker(request),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border:
          Border.all(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isUpdatingStatus)
              SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: statusColor))
            else
              Text(status.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.4)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: statusColor),
          ],
        ),
      ),
    );
  }
// ✅ NEW _updateStatus
  Future<void> _updateStatus(
      Map<String, dynamic> request, String newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final provider =
      Provider.of<ServiceRequestProvider>(context, listen: false);
      final result = await provider.updateServiceRequest(
        requestId: widget.requestId,
        status: newStatus,
        communityId: widget.communityId,
      );
      if (mounted) {
        _showSnack(
          result['error'] == false
              ? 'Status updated to $newStatus'
              : (result['message'] ?? 'Failed to update status'),
          result['error'] == false ? Colors.green : Colors.red,
        );
        // ✅ No getServiceRequestById needed — provider already has fresh data
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // ─────────────────────────────────────────────
  // STATUS PICKER BOTTOM SHEET
  // ─────────────────────────────────────────────
  void _showStatusPicker(Map<String, dynamic> request) {
    final current = request['status'] ?? 'Open';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Update Status',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ..._statusOptions.map((s) {
              final color = _statusColor(s);
              final isCurrent = s == current;
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon(s), size: 18, color: color),
                ),
                title: Text(s,
                    style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500)),
                trailing: isCurrent
                    ? Icon(Icons.check_circle_rounded,
                    color: color, size: 20)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  if (!isCurrent) await _updateStatus(request, s);
                },
              );
            }).toList(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }



  // ─────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _accent,
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: _accent,
        indicatorWeight: 2.5,
        labelStyle:
        const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Activity'),
          Tab(text: 'Attachments'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB 1: OVERVIEW
  // ─────────────────────────────────────────────
  Widget _buildOverviewTab(Map<String, dynamic> request) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(
        children: [
          // Description
          _sectionCard(
            title: 'Description',
            icon: Icons.description_outlined,
            color: Colors.green,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                (request['description'] ?? '').toString().isEmpty
                    ? 'No description provided'
                    : request['description'],
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Request Info
          _sectionCard(
            title: 'Request Information',
            icon: Icons.info_outline_rounded,
            color: Colors.blue,
            child: Column(
              children: [
                _infoRow('Status', request['status'] ?? 'N/A'),
                _infoRow('Category', request['category'] ?? 'N/A'),
                _infoRow('Priority', _priorityLabel(request['priority'] ?? '')),
                _infoRow('Source', request['source'] ?? 'Manual'),
                if (request['email'] != null && (request['email'] as String).isNotEmpty)
                  _infoRow('Email', request['email']),
                if (request['community'] != null)
                  _infoRow('Community', request['community']['name'] ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Assignment
          _sectionCard(
            title: 'Assignment',
            icon: Icons.people_outline_rounded,
            color: Colors.purple,
            child: Column(
              children: [
                _infoRow('Raised By', _userName(request['raisedBy'])),
                if (request['raisedBy']?['email'] != null)
                  _infoRow('Contact', request['raisedBy']['email']),
                _infoRow(
                    'Assigned To',
                    request['assignedTo'] != null
                        ? _userName(request['assignedTo'])
                        : 'Not assigned'),
                if (request['completedBy'] != null)
                  _infoRow('Completed By',
                      _userName(request['completedBy'])),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Timeline
          _sectionCard(
            title: 'Timeline',
            icon: Icons.schedule_outlined,
            color: Colors.orange,
            child: Column(
              children: [
                _timelineItem('Created',
                    _formatDetailed(request['createdAt']),
                    Icons.add_circle_outline, Colors.blue),
                if (request['dueDate'] != null)
                  _timelineItem('Due Date',
                      _formatDetailed(request['dueDate']),
                      Icons.event_outlined, const Color(0xFFFF7043)),
                if (request['updatedAt'] != null &&
                    request['updatedAt'] != request['createdAt'])
                  _timelineItem('Last Updated',
                      _formatDetailed(request['updatedAt']),
                      Icons.update_rounded, Colors.orange),
                if (request['completedAt'] != null)
                  _timelineItem('Completed',
                      _formatDetailed(request['completedAt']),
                      Icons.check_circle_outline, Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Next Action Input
          _buildNextActionCard(),
        ],
      ),
    );
  }

  Widget _buildNextActionCard() {
    return _sectionCard(
      title: 'Add Working Note',
      icon: Icons.edit_note_rounded,
      color: Colors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nextActionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe the next action or note...',
              hintStyle:
              TextStyle(color: Colors.grey[400], fontSize: 13),
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
                borderSide:
                const BorderSide(color: _accent, width: 1.5),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F8FC),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSavingNote ? null : _saveNextAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isSavingNote
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save Note',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW _saveNextAction
  Future<void> _saveNextAction() async {
    final note = _nextActionController.text.trim();
    if (note.isEmpty) {
      _showSnack('Please enter a note', Colors.orange);
      return;
    }
    setState(() => _isSavingNote = true);
    try {
      final provider =
      Provider.of<ServiceRequestProvider>(context, listen: false);
      final result = await provider.updateServiceRequest(
        requestId: widget.requestId,
        nextAction: note,
        communityId: widget.communityId,
      );
      if (mounted) {
        if (result['error'] == false) {
          _nextActionController.clear();
          _showSnack('Note saved successfully', Colors.green);
          // ✅ No getServiceRequestById needed — provider already has fresh data
        } else {
          _showSnack(result['message'] ?? 'Failed to save note', Colors.red);
        }
      }
    } finally {
      if (mounted) setState(() => _isSavingNote = false);
    }
  }

  // ─────────────────────────────────────────────
  // TAB 2: ACTIVITY (history + working notes)
  // ─────────────────────────────────────────────
  Widget _buildActivityTab(Map<String, dynamic> request) {
    final history = List<Map<String, dynamic>>.from(
        (request['history'] as List? ?? []));
    final notes = List<Map<String, dynamic>>.from(
        (request['workingNotes'] as List? ?? []));

    // Merge and sort by date
    final allActivity = [
      ...history.map((h) => {...h, '_type': 'history'}),
      ...notes.map((n) => {...n, '_type': 'note'}),
    ];
    allActivity.sort((a, b) {
      try {
        final da = DateTime.parse(a['date'].toString());
        final db = DateTime.parse(b['date'].toString());
        return db.compareTo(da);
      } catch (_) {
        return 0;
      }
    });

    if (allActivity.isEmpty) {
      return _buildEmptyTab(
          Icons.history_rounded, 'No activity yet', 'History and notes will appear here');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: allActivity.length,
      itemBuilder: (_, i) {
        final item = allActivity[i];
        return item['_type'] == 'note'
            ? _buildNoteCard(item)
            : _buildHistoryCard(item);
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final changes = List<String>.from(item['changes'] ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
              Icon(Icons.update_rounded, size: 16, color: _accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item['title'] ?? 'Updated',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E))),
                      const Spacer(),
                      Text(_formatDetailed(item['date']?.toString()),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  if (item['name'] != null) ...[
                    const SizedBox(height: 3),
                    Text('by ${item['name']}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ],
                  if (changes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: changes
                          .map((c) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.08),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: Text(c,
                            style: TextStyle(
                                fontSize: 11,
                                color: _accent,
                                fontWeight: FontWeight.w600)),
                      ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notes_rounded,
                  size: 16, color: Colors.amber[700]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Working Note',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber[700])),
                      const Spacer(),
                      Text(_formatDetailed(item['date']?.toString()),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  if (item['name'] != null) ...[
                    const SizedBox(height: 2),
                    Text('by ${item['name']}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ],
                  const SizedBox(height: 8),
                  Text(item['nextAction'] ?? '',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB 3: ATTACHMENTS
  // ─────────────────────────────────────────────
  Widget _buildAttachmentsTab(Map<String, dynamic> request) {
    final files =
    List<Map<String, dynamic>>.from(request['files'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upload area
          _buildUploadArea(),
          const SizedBox(height: 16),
          // Existing files
          if (files.isEmpty && _pendingFiles.isEmpty)
            _buildEmptyTab(Icons.attach_file_rounded, 'No attachments',
                'Upload photos or files to add attachments')
          else ...[
            if (files.isNotEmpty) ...[
              Text('Uploaded Files',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[700])),
              const SizedBox(height: 10),
              ...files.map((f) => _buildFileItem(f)).toList(),
              const SizedBox(height: 16),
            ],
            if (_pendingFiles.isNotEmpty) ...[
              Text('Pending Upload (${_pendingFiles.length})',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange[700])),
              const SizedBox(height: 10),
              ..._pendingFiles
                  .asMap()
                  .entries
                  .map((e) => _buildPendingFile(e.key, e.value))
                  .toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploadingFiles ? null : _uploadFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isUploadingFiles
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(
                    _isUploadingFiles
                        ? 'Uploading...'
                        : 'Upload ${_pendingFiles.length} file(s)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _showFilePicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.04),
          border: Border.all(
              color: _accent.withOpacity(0.3),
              width: 1.5,
              style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_photo_alternate_outlined,
                  size: 28, color: _accent),
            ),
            const SizedBox(height: 10),
            Text('Tap to add photos or files',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _accent)),
            const SizedBox(height: 4),
            Text('Camera, gallery, or files',
                style:
                TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  void _showFilePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Add Attachment',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_outlined,
                    color: Colors.blue, size: 20),
              ),
              title: const Text('Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Use camera',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.photo_library_outlined,
                    color: Colors.purple, size: 20),
              ),
              title: const Text('Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Pick from photos',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null) {
        setState(() => _pendingFiles.add(File(picked.path)));
        _tabController.animateTo(2); // Switch to attachments tab
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to pick image: $e', Colors.red);
    }
  }

  // ✅ NEW _uploadFiles
  Future<void> _uploadFiles() async {
    if (_pendingFiles.isEmpty) return;
    setState(() => _isUploadingFiles = true);
    try {
      final provider =
      Provider.of<ServiceRequestProvider>(context, listen: false);
      final result = await provider.updateServiceRequest(
        requestId: widget.requestId,
        files: _pendingFiles,
        communityId: widget.communityId,
      );

      // ── DEBUG PRINTS ──────────────────────────────
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📥 [UPLOAD] result error = ${result['error']}');
      debugPrint('📥 [UPLOAD] result message = ${result['message']}');
      debugPrint('📥 [UPLOAD] result data = ${result['data']}');
      debugPrint('📥 [UPLOAD] result data files = ${result['data']?['files']}');
      debugPrint('──────────────────────────────────');
      debugPrint('📦 [PROVIDER] currentRequest = ${provider.currentRequest}');
      debugPrint('📦 [PROVIDER] currentRequest files = ${provider.currentRequest?['files']}');
      debugPrint('📦 [PROVIDER] files count = ${(provider.currentRequest?['files'] as List?)?.length}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // ── END DEBUG ─────────────────────────────────

      if (mounted) {
        if (result['error'] == false) {
          setState(() => _pendingFiles.clear());
          _showSnack('Files uploaded successfully', Colors.green);
        } else {
          _showSnack(result['message'] ?? 'Upload failed', Colors.red);
        }
      }
    } finally {
      if (mounted) setState(() => _isUploadingFiles = false);
    }
  }


  Widget _buildFileItem(Map<String, dynamic> file) {
    final name = file['fileName'] ?? 'Unknown file';
    final url = file['fileUrl'] ?? '';
    final uploadedBy = file['uploadedBy'] ?? '';
    final isImage = name.toLowerCase().endsWith('.jpg') ||
        name.toLowerCase().endsWith('.jpeg') ||
        name.toLowerCase().endsWith('.png') ||
        name.toLowerCase().endsWith('.gif') ||
        name.toLowerCase().endsWith('.webp');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isImage
                  ? Colors.blue.withOpacity(0.08)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: isImage && url.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.image_outlined,
                      color: Colors.blue[400],
                      size: 22)),
            )
                : Icon(
              isImage
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined,
              color: isImage ? Colors.blue[400] : Colors.grey[500],
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (uploadedBy.isNotEmpty)
                  Text('by $uploadedBy',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          if (url.isNotEmpty)
            IconButton(
              icon: Icon(Icons.open_in_new_rounded,
                  size: 18, color: _accent),
              onPressed: () async {
                try {
                  await launchUrl(Uri.parse(url));
                } catch (_) {
                  _showSnack('Cannot open file', Colors.red);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPendingFile(int index, File file) {
    final name = file.path.split('/').last;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.image_outlined,
                      color: Colors.orange[400],
                      size: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('Ready to upload',
                    style: TextStyle(
                        fontSize: 11, color: Colors.orange[600])),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline,
                size: 18, color: Colors.red[400]),
            onPressed: () =>
                setState(() => _pendingFiles.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(
      String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(time,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
    Color? bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 36, color: _accent.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700])),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ServiceRequestProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text('Something went wrong',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800])),
          const SizedBox(height: 6),
          Text(provider.error!,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.getServiceRequestById(widget.requestId),
            style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('Request not found',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Open': return const Color(0xFFFF7043);
      case 'In Progress': return const Color(0xFF9B59B6);
      case 'Completed': return const Color(0xFF00B894);
      case 'Closed': return Colors.grey;
      default: return _accent;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Open': return Icons.radio_button_unchecked_rounded;
      case 'In Progress': return Icons.autorenew_rounded;
      case 'Completed': return Icons.check_circle_outline_rounded;
      case 'Closed': return Icons.lock_outline_rounded;
      default: return Icons.circle_outlined;
    }
  }

  Color _priorityColor(String p) {
    if (p.contains('Critical')) return const Color(0xFFE74C3C);
    if (p.contains('High')) return const Color(0xFFFF7043);
    if (p.contains('Medium')) return const Color(0xFF3498DB);
    if (p.contains('Low')) return const Color(0xFF00B894);
    return Colors.grey;
  }

  String _priorityLabel(String p) {
    if (p.contains('Critical')) return 'CRITICAL';
    if (p.contains('High')) return 'HIGH';
    if (p.contains('Medium')) return 'MEDIUM';
    if (p.contains('Low')) return 'LOW';
    return p.isEmpty ? 'UNKNOWN' : p.toUpperCase();
  }

  String _userName(Map<String, dynamic>? u) {
    if (u == null) return 'N/A';
    return u['profile']?['name'] ?? u['email'] ?? 'Unknown';
  }

  String _formatDetailed(String? d) {
    if (d == null) return 'N/A';
    try {
      final date = DateTime.parse(d);
      final diff = DateTime.now().difference(date);
      final time =
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      if (diff.inDays == 0) return 'Today at $time';
      if (diff.inDays == 1) return 'Yesterday at $time';
      if (diff.inDays < 7) return '${diff.inDays}d ago at $time';
      return '${date.day}/${date.month}/${date.year} at $time';
    } catch (_) {
      return d;
    }
  }
}

