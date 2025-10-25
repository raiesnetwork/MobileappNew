import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/service_request_provider.dart';

class ServiceRequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic>? initialData;

  const ServiceRequestDetailsScreen({
    Key? key,
    required this.requestId,
    this.initialData,
  }) : super(key: key);

  @override
  State<ServiceRequestDetailsScreen> createState() => _ServiceRequestDetailsScreenState();
}

class _ServiceRequestDetailsScreenState extends State<ServiceRequestDetailsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialData == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ServiceRequestProvider>(context, listen: false)
            .getServiceRequestById(widget.requestId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Request Details', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        scrolledUnderElevation: 0,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: Consumer<ServiceRequestProvider>(
        builder: (context, provider, child) {
          final request = widget.initialData ?? provider.currentRequest;

          if (provider.isLoading && widget.initialData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && widget.initialData == null) {
            return _buildErrorState(provider.error!);
          }

          if (request == null) {
            return _buildNotFoundState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildHeaderCard(request),
                const SizedBox(height: 12),
                _buildInfoCard(request),
                const SizedBox(height: 12),
                _buildDescriptionCard(request),
                const SizedBox(height: 12),
                _buildAssignmentCard(request),
                const SizedBox(height: 12),
                _buildTimelineCard(request),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text('Error loading request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
          const SizedBox(height: 6),
          Text(error, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Provider.of<ServiceRequestProvider>(context, listen: false).getServiceRequestById(widget.requestId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('Request not found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'Unknown';
    final priority = request['priority'] ?? 'Medium';
    final statusColor = _getStatusColor(status);
    final priorityColor = _getPriorityColor(priority);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REQUEST ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      Text(request['requestId'] ?? 'N/A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blue[700])),
                    ],
                  ),
                ),
                _buildStatusBadge(status, statusColor),
              ],
            ),
            const SizedBox(height: 16),
            Text(request['subject'] ?? 'No Subject', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildPriorityBadge(priority, priorityColor),
                const SizedBox(width: 12),
                _buildCategoryBadge(request['category'] ?? 'Uncategorized'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> request) {
    return _buildSectionCard(
      'Request Information',
      Icons.info_outline,
      Colors.blue,
      [
        _buildInfoRow('Category', request['category'] ?? 'Uncategorized'),
        _buildInfoRow('Priority', request['priority'] ?? 'N/A'),
        _buildInfoRow('Status', request['status'] ?? 'N/A'),
        if (request['community'] != null) _buildInfoRow('Community', request['community']['name'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildDescriptionCard(Map<String, dynamic> request) {
    final description = request['description'] ?? '';
    return _buildSectionCard(
      'Description',
      Icons.description_outlined,
      Colors.green,
      [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            description.isEmpty ? 'No description provided' : description,
            style: TextStyle(
              fontSize: 14,
              color: description.isEmpty ? Colors.grey[500] : Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> request) {
    return _buildSectionCard(
      'Assignment Details',
      Icons.people_outline,
      Colors.purple,
      [
        _buildInfoRow('Raised By', _getUserName(request['raisedBy'])),
        if (request['raisedBy']?['email'] != null) _buildInfoRow('Contact Email', request['raisedBy']['email']),
        _buildInfoRow('Assigned To', request['assignedTo'] != null ? _getUserName(request['assignedTo']) : 'Not assigned yet'),
        if (request['completedBy'] != null) _buildInfoRow('Completed By', _getUserName(request['completedBy'])),
      ],
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> request) {
    return _buildSectionCard(
      'Timeline',
      Icons.schedule_outlined,
      Colors.orange,
      [
        _buildTimelineItem('Created', _formatDetailedDate(request['createdAt']), Icons.add_circle_outline, Colors.blue),
        if (request['updatedAt'] != null && request['updatedAt'] != request['createdAt'])
          _buildTimelineItem('Last Updated', _formatDetailedDate(request['updatedAt']), Icons.update, Colors.orange),
        if (request['completedAt'] != null)
          _buildTimelineItem('Completed', _formatDetailedDate(request['completedAt']), Icons.check_circle_outline, Colors.green),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
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
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
    );
  }

  Widget _buildPriorityBadge(String priority, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 16, color: color),
          const SizedBox(width: 6),
          Text(_getPriorityLabel(priority), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_outlined, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(category, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open': return Colors.orange;
      case 'In Progress': return Colors.purple;
      case 'Completed': return Colors.green;
      case 'Closed': return Colors.grey;
      default: return Colors.blue;
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

  String _formatDetailedDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      String timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      String dateStr = '${date.day}/${date.month}/${date.year}';

      if (difference.inDays == 0) {
        return 'Today at $timeStr';
      } else if (difference.inDays == 1) {
        return 'Yesterday at $timeStr';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago at $timeStr';
      } else {
        return '$dateStr at $timeStr';
      }
    } catch (e) {
      return dateString;
    }
  }
}