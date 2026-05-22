import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/service_request_provider.dart';
import 'create_service_request.dart';
import 'service_request_deatils_page.dart';

class AllServiceRequestsScreen extends StatefulWidget {
  final String communityId;
  final bool isUserMode;
  final int initialTabIndex;
  const AllServiceRequestsScreen({
    Key? key,
    required this.communityId,
    this.isUserMode = false,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<AllServiceRequestsScreen> createState() =>
      _AllServiceRequestsScreenState();
}

class _AllServiceRequestsScreenState extends State<AllServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String selectedStatus = 'All';
  String selectedPriority = 'All';
  String searchQuery = '';
  String? currentUserId;
  bool _isDeleting = false;
  String? _deletingRequestId;

  final List<String> statusOptions = [
    'All',
    'Open',
    'In Progress',
    'Completed',
    'Closed'
  ];
  final List<String> priorityOptions = [
    'All',
    'Critical – Business/essential function is blocked',
    'High – Needs action soon, moderate impact',
    'Medium – Needs attention within a few hours',
    'Low – Not urgent, can wait',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex, // ✅ lands on correct tab
    );
    _loadCurrentUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
      Provider.of<ServiceRequestProvider>(context, listen: false);
      if (widget.isUserMode) {
        provider.fetchServiceRequests(userId: widget.communityId); // ✅ userId-based
      } else {
        provider.fetchServiceRequests(communityId: widget.communityId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getString('user_id') ?? '';
    });
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      floatingActionButton: _buildFAB(),
      body: Consumer<ServiceRequestProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C5CE7)));
          }
          if (provider.error != null) {
            return _buildErrorState(provider);
          }

          // ✅ In user mode: assignedRequests has the data (from userAssignedRequests)
          //    In community mode: requests has the data
          final myRequests = _filterRequests(provider.requests);
          final assignedRequests = widget.isUserMode
              ? _filterRequests(provider.assignedRequests)  // ✅ correct source
              : _filterRequests(provider.assignedRequests);

          return Column(
            children: [
              _buildFiltersSection(),
              _buildStatsSection(
                widget.isUserMode
                    ? provider.assignedRequests
                    : provider.requests,
              ),
              _buildTabBar(), // ✅ hidden in user mode
              Expanded(
                child: widget.isUserMode
                    ? _buildListView(assignedRequests, provider) // ✅ direct list
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListView(myRequests, provider),
                    _buildListView(assignedRequests, provider),
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
      title: const Text(
        'Service Requests',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A2E),
      scrolledUnderElevation: 0,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFEEEEF5)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FAB
  // ─────────────────────────────────────────────
  Widget _buildFAB() {
    if (widget.isUserMode) return const SizedBox.shrink(); // ✅ hide FAB
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CreateServiceRequestScreen(communityId: widget.communityId),
          ),
        );
        if (result == true && mounted) {
          Provider.of<ServiceRequestProvider>(context, listen: false)
              .fetchServiceRequests(communityId: widget.communityId);
        }
      },
      backgroundColor: const Color(0xFF6C5CE7),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add, size: 20),
      label: const Text('New Request',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      elevation: 4,
    );
  }

  // ─────────────────────────────────────────────
  // FILTERS
  // ─────────────────────────────────────────────
  Widget _buildFiltersSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          // Search
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by subject, ID or description...',
              hintStyle:
              TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon:
              Icon(Icons.search_rounded, size: 20, color: Colors.grey[400]),
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
                borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F8FC),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (v) => setState(() => searchQuery = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Status',
                  value: selectedStatus,
                  options: statusOptions,
                  onChanged: (v) => setState(() => selectedStatus = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  label: 'Priority',
                  value: selectedPriority,
                  options: priorityOptions,
                  onChanged: (v) => setState(() => selectedPriority = v!),
                  truncate: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required void Function(String?) onChanged,
    bool truncate = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.4)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
              const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
            ),
            filled: true,
            fillColor: const Color(0xFFF8F8FC),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: options
              .map((o) => DropdownMenuItem(
            value: o,
            child: Text(
              truncate && o != 'All'
                  ? _truncate(o, 14)
                  : o,
              style: const TextStyle(fontSize: 12),
            ),
          ))
              .toList(),
          onChanged: onChanged,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[500], size: 18),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // STATS BAR
  // ─────────────────────────────────────────────
  Widget _buildStatsSection(List<Map<String, dynamic>> requests) {
    final total = requests.length;
    final open = requests.where((r) => r['status'] == 'Open').length;
    final inProgress =
        requests.where((r) => r['status'] == 'In Progress').length;
    final completed =
        requests.where((r) => r['status'] == 'Completed').length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          _statChip('Total', total, const Color(0xFF6C5CE7)),
          const SizedBox(width: 8),
          _statChip('Open', open, const Color(0xFFFF7043)),
          const SizedBox(width: 8),
          _statChip('In Progress', inProgress, const Color(0xFF9B59B6)),
          const SizedBox(width: 8),
          _statChip('Done', completed, const Color(0xFF00B894)),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: Column(
          children: [
            Text(count.toString(),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.8),
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────
  Widget _buildTabBar() {
    if (widget.isUserMode) return const SizedBox.shrink(); // ✅ hide tabs
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF6C5CE7),
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: const Color(0xFF6C5CE7),
        indicatorWeight: 2.5,
        labelStyle:
        const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(text: 'My Requests'),
          Tab(text: 'Assigned to Me'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LIST VIEW
  // ─────────────────────────────────────────────
  Widget _buildListView(
      List<Map<String, dynamic>> requests, ServiceRequestProvider provider) {
    return RefreshIndicator(
      color: const Color(0xFF6C5CE7),
      onRefresh: () => widget.isUserMode
          ? provider.fetchServiceRequests(userId: widget.communityId)
          : provider.fetchServiceRequests(communityId: widget.communityId),
      child: requests.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
        itemCount: requests.length,
        itemBuilder: (_, i) => _buildRequestCard(requests[i]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // REQUEST CARD
  // ─────────────────────────────────────────────
  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'Unknown';
    final priority = request['priority'] ?? '';
    final statusColor = _statusColor(status);
    final priorityColor = _priorityColor(priority);
    final isCreator = currentUserId != null &&
        request['raisedBy']?['_id'] == currentUserId;
    final canEditOrDelete = isCreator && status != 'Completed';
    final hasFiles =
        (request['files'] as List?)?.isNotEmpty ?? false;
    final hasNotes =
        (request['workingNotes'] as List?)?.isNotEmpty ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetails(request),
        child: Stack(
          children: [
            // Left accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: ID + Status + Menu
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tag,
                                size: 11,
                                color: const Color(0xFF6C5CE7)),
                            const SizedBox(width: 3),
                            Text(
                              request['requestId'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6C5CE7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withOpacity(0.3), width: 1),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (canEditOrDelete) ...[
                        const SizedBox(width: 4),
                        _buildCardMenu(request),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Subject
                  Text(
                    request['subject'] ?? 'No Subject',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Description
                  if ((request['description'] ?? '').toString().isNotEmpty)
                    Text(
                      request['description'],
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 10),
                  // Priority + Category chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(
                        icon: Icons.flag_rounded,
                        label: _priorityLabel(priority),
                        color: priorityColor,
                      ),
                      _chip(
                        icon: Icons.category_outlined,
                        label: request['category'] ?? 'Uncategorized',
                        color: Colors.grey[600]!,
                        bgColor: Colors.grey[100]!,
                      ),
                      if (hasFiles)
                        _chip(
                          icon: Icons.attach_file_rounded,
                          label: '${(request['files'] as List).length} file(s)',
                          color: Colors.teal,
                          bgColor: Colors.teal.withOpacity(0.08),
                        ),
                      if (hasNotes)
                        _chip(
                          icon: Icons.notes_rounded,
                          label: 'Notes',
                          color: Colors.amber[700]!,
                          bgColor: Colors.amber.withOpacity(0.08),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8FC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _infoItem(
                                Icons.person_outline_rounded,
                                'RAISED BY',
                                _userName(request['raisedBy']),
                                const Color(0xFF6C5CE7),
                              ),
                            ),
                            if (request['assignedTo'] != null) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _infoItem(
                                  Icons.assignment_ind_outlined,
                                  'ASSIGNED TO',
                                  _userName(request['assignedTo']),
                                  const Color(0xFF00B894),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _infoItem(
                                Icons.schedule_outlined,
                                'CREATED',
                                _formatDate(request['createdAt']),
                                Colors.grey[500]!,
                              ),
                            ),
                            if (request['dueDate'] != null) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _infoItem(
                                  Icons.event_outlined,
                                  'DUE DATE',
                                  _formatDate(request['dueDate']),
                                  const Color(0xFFFF7043),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Deleting overlay
            if (_isDeleting && _deletingRequestId == request['_id'])
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C5CE7))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMenu(Map<String, dynamic> request) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey[500]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (v) {
        if (v == 'edit') _openEdit(request);
        if (v == 'delete') _confirmDelete(request);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6C5CE7)),
              SizedBox(width: 10),
              Text('Edit', style: TextStyle(fontSize: 14)),
            ])),
        const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red),
              SizedBox(width: 10),
              Text('Delete',
                  style: TextStyle(fontSize: 14, color: Colors.red)),
            ])),
      ],
    );
  }

  Widget _chip({
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

  Widget _infoItem(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 11, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 0.3)),
              const SizedBox(height: 1),
              Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // EMPTY / ERROR STATES
  // ─────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_outlined,
                size: 40, color: const Color(0xFF6C5CE7).withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text('No requests found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700])),
          const SizedBox(height: 6),
          Text('Try adjusting your filters',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(provider.error!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.fetchServiceRequests(
                communityId: widget.communityId),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────
  void _openDetails(Map<String, dynamic> request) {
    Provider.of<ServiceRequestProvider>(context, listen: false)
        .clearCurrentRequest();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceRequestDetailsScreen(
          requestId: request['_id'] ?? '',
          initialData: request,
          communityId: widget.communityId,
        ),
      ),
    ).then((_) {
      if (mounted) {
        Provider.of<ServiceRequestProvider>(context, listen: false)
            .fetchServiceRequests(communityId: widget.communityId);
      }
    });
  }

  void _openEdit(Map<String, dynamic> request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateServiceRequestScreen(
          communityId: widget.communityId,
          request: request,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        Provider.of<ServiceRequestProvider>(context, listen: false)
            .fetchServiceRequests(communityId: widget.communityId);
      }
    });
  }

  void _confirmDelete(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Request',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to delete "${request['subject']}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRequest(request['_id']);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRequest(String requestId) async {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
      _deletingRequestId = requestId;
    });
    try {
      final provider =
      Provider.of<ServiceRequestProvider>(context, listen: false);
      final result = await provider.deleteServiceRequest(requestId,
          communityId: widget.communityId);
      if (!mounted) return;
      _showSnack(
        result['error'] == false
            ? 'Service request deleted successfully'
            : (result['message'] ?? 'Failed to delete'),
        result['error'] == false ? Colors.green : Colors.red,
      );
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _deletingRequestId = null;
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  List<Map<String, dynamic>> _filterRequests(
      List<Map<String, dynamic>> requests) {
    return requests.where((r) {
      final q = searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          (r['subject']?.toLowerCase().contains(q) ?? false) ||
          (r['description']?.toLowerCase().contains(q) ?? false) ||
          (r['requestId']?.toLowerCase().contains(q) ?? false);
      final matchStatus =
          selectedStatus == 'All' || r['status'] == selectedStatus;
      final matchPriority =
          selectedPriority == 'All' || r['priority'] == selectedPriority;
      return matchSearch && matchStatus && matchPriority;
    }).toList();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Open': return const Color(0xFFFF7043);
      case 'In Progress': return const Color(0xFF9B59B6);
      case 'Completed': return const Color(0xFF00B894);
      case 'Closed': return Colors.grey;
      default: return const Color(0xFF6C5CE7);
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
    return 'UNKNOWN';
  }

  String _userName(Map<String, dynamic>? u) {
    if (u == null) return 'N/A';
    return u['profile']?['name'] ?? u['email'] ?? 'Unknown';
  }

  String _formatDate(String? d) {
    if (d == null) return 'N/A';
    try {
      final date = DateTime.parse(d);
      final diff = DateTime.now().difference(date);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return d;
    }
  }

  String _truncate(String text, int max) {
    return text.length <= max ? text : '${text.substring(0, max)}...';
  }
}