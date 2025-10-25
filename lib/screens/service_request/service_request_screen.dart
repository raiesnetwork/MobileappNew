import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/service_request_provider.dart';
import 'create_service_request.dart';
import 'service_request_deatils_page.dart';

class AllServiceRequestsScreen extends StatefulWidget {
  final String communityId;
  const AllServiceRequestsScreen({Key? key, required this.communityId}) : super(key: key);

  @override
  State<AllServiceRequestsScreen> createState() => _AllServiceRequestsScreenState();
}

class _AllServiceRequestsScreenState extends State<AllServiceRequestsScreen> {
  String selectedStatus = 'All';
  String selectedPriority = 'All';
  String searchQuery = '';
  String? currentUserId;
  bool _isDeleting = false;

  final List<String> statusOptions = ['All', 'Open', 'In Progress', 'Completed', 'Closed'];
  final List<String> priorityOptions = [
    'All',
    'Critical – Business/essential function is blocked',
    'High – Needs action soon, moderate impact',
    'Medium – Needs attention within a few hours',
    'Low – Not urgent, can wait'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ServiceRequestProvider>(context, listen: false).fetchServiceRequests(communityId: widget.communityId);
    });
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getString('user_id') ?? '65ec4cd00b6a74864052699c'; // Fallback to Raja's ID
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Service Requests', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        scrolledUnderElevation: 0,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateServiceRequestScreen(communityId: widget.communityId),
            ),
          );
          if (result == true && mounted) {
            Provider.of<ServiceRequestProvider>(context, listen: false).fetchServiceRequests(communityId: widget.communityId);
          }
        },
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Consumer<ServiceRequestProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text('Error loading requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                  const SizedBox(height: 6),
                  Text(provider.error!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchServiceRequests(communityId: widget.communityId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filteredRequests = _filterRequests(provider.requests);

          return Column(
            children: [
              _buildFiltersSection(),
              _buildStatsSection(provider.requests),
              Expanded(
                child: filteredRequests.isEmpty ? _buildEmptyState() : _buildRequestsList(filteredRequests),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search requests...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue)),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) => setState(() => searchQuery = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildFilterDropdown('Status', selectedStatus, statusOptions, (value) => setState(() => selectedStatus = value!))),
              const SizedBox(width: 8),
              Expanded(child: _buildFilterDropdown('Priority', selectedPriority, priorityOptions, (value) => setState(() => selectedPriority = value!))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> options, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey[600])),
        const SizedBox(height: 3),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          items: options.map((option) => DropdownMenuItem(
            value: option,
            child: Text(option == 'All' ? option : _truncateText(option, 15), style: const TextStyle(fontSize: 12)),
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildStatsSection(List<Map<String, dynamic>> requests) {
    final stats = _calculateStats(requests);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildStatCard('Total', stats['total']!, Colors.blue),
          const SizedBox(width: 8),
          _buildStatCard('Open', stats['open']!, Colors.orange),
          const SizedBox(width: 8),
          _buildStatCard('In Progress', stats['inProgress']!, Colors.purple),
          const SizedBox(width: 8),
          _buildStatCard('Completed', stats['completed']!, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(List<Map<String, dynamic>> requests) {
    return RefreshIndicator(
      onRefresh: () async => await Provider.of<ServiceRequestProvider>(context, listen: false).fetchServiceRequests(communityId: widget.communityId),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: requests.length,
        itemBuilder: (context, index) => _buildRequestCard(requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'Unknown';
    final priority = request['priority'] ?? 'Medium';
    final statusColor = _getStatusColor(status);
    final priorityColor = _getPriorityColor(priority);
    final isCreator = currentUserId != null && request['raisedBy']?['_id'] == currentUserId;
    final canEditOrDelete = isCreator && status != 'Completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToRequestDetails(request),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Icon(Icons.confirmation_number_outlined, size: 12, color: Colors.blue[700]),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('REQUEST ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[500], letterSpacing: 0.5)),
                                  Text(request['requestId'] ?? 'N/A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue[700]), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                            ),
                            child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.3)),
                          ),
                          if (canEditOrDelete) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _navigateToEditRequest(request);
                                } else if (value == 'delete') {
                                  _showDeleteConfirmation(request);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit', style: TextStyle(fontSize: 14)),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(fontSize: 14, color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Subject
                  Text(
                    request['subject'] ?? 'No Subject',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Description
                  if (request['description'] != null && request['description'].toString().isNotEmpty)
                    Text(
                      request['description'],
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 10),
                  // Priority and Category
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: priorityColor.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flag, size: 12, color: priorityColor),
                            const SizedBox(width: 3),
                            Text(_getPriorityLabel(priority), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: priorityColor, letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.category_outlined, size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  request['category'] ?? 'Uncategorized',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Bottom info
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildInfoItem(Icons.person_outline, 'RAISED BY', _getUserName(request['raisedBy']), Colors.blue[600]!)),
                            if (request['community'] != null) ...[
                              const SizedBox(width: 12),
                              Expanded(child: _buildInfoItem(Icons.group_outlined, 'COMMUNITY', request['community']['name'] ?? 'N/A', Colors.purple[600]!)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildInfoItem(Icons.schedule_outlined, 'CREATED', _formatDate(request['createdAt']), Colors.grey[600]!)),
                            if (request['assignedTo'] != null) ...[
                              const SizedBox(width: 12),
                              Expanded(child: _buildInfoItem(Icons.assignment_ind_outlined, 'ASSIGNED', _getUserName(request['assignedTo']), Colors.green[600]!)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isDeleting && request['_id'] == _deletingRequestId)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _deletingRequestId;

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
          child: Icon(icon, size: 11, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.3)),
              const SizedBox(height: 1),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No service requests found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text('Try adjusting your filters or search terms', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _navigateToRequestDetails(Map<String, dynamic> request) {
    Provider.of<ServiceRequestProvider>(context, listen: false).clearCurrentRequest();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceRequestDetailsScreen(
          requestId: request['_id'] ?? '', // Use _id for details
          initialData: request,
        ),
      ),
    );
  }

  void _navigateToEditRequest(Map<String, dynamic> request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateServiceRequestScreen(
          communityId: widget.communityId,
          request: request,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        Provider.of<ServiceRequestProvider>(context, listen: false).fetchServiceRequests(communityId: widget.communityId);
      }
    });
  }

  void _showDeleteConfirmation(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: Text('Are you sure you want to delete "${request['subject']}" (ID: ${request['requestId']})? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRequest(request['_id']);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
      final provider = Provider.of<ServiceRequestProvider>(context, listen: false);
      final result = await provider.deleteServiceRequest(requestId);
      if (!mounted) return;
      if (result['error'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await provider.fetchServiceRequests(communityId: widget.communityId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete service request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _deletingRequestId = null;
        });
      }
    }
  }

  List<Map<String, dynamic>> _filterRequests(List<Map<String, dynamic>> requests) {
    return requests.where((request) {
      final matchesSearch = searchQuery.isEmpty ||
          (request['subject']?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
          (request['description']?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
          (request['requestId']?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
      final matchesStatus = selectedStatus == 'All' || request['status'] == selectedStatus;
      final matchesPriority = selectedPriority == 'All' || request['priority'] == selectedPriority;
      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();
  }

  Map<String, int> _calculateStats(List<Map<String, dynamic>> requests) {
    return {
      'total': requests.length,
      'open': requests.where((r) => r['status'] == 'Open').length,
      'inProgress': requests.where((r) => r['status'] == 'In Progress').length,
      'completed': requests.where((r) => r['status'] == 'Completed').length,
    };
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.orange;
      case 'In Progress':
        return Colors.purple;
      case 'Completed':
        return Colors.green;
      case 'Closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getPriorityColor(String priority) {
    if (priority.contains('Critical')) return Colors.red;
    if (priority.contains('High')) return Colors.orange;
    if (priority.contains('Medium')) return Colors.blue;
    if (priority.contains('Low')) return Colors.green;
    return Colors.grey;
  }

  String _getPriorityLabel(String priority) {
    if (priority.contains('Critical')) return 'CRITICAL';
    if (priority.contains('High')) return 'HIGH';
    if (priority.contains('Medium')) return 'MEDIUM';
    if (priority.contains('Low')) return 'LOW';
    return 'UNKNOWN';
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) return 'N/A';
    return user['profile']?['name'] ?? user['email'] ?? 'Unknown User';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inDays == 0) {
        return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}