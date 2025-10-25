
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:provider/provider.dart';
import '../../providers/announcement_provider.dart';
import 'package:intl/intl.dart';

import 'create_announcement_screen.dart';

class AnnouncementScreen extends StatefulWidget {
  final String communityId;

  const AnnouncementScreen({super.key, required this.communityId});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnnouncementProvider>(context, listen: false)
          .fetchAnnouncements(communityId: widget.communityId);
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return 'N/A';
    return timeString;
  }

  String _formatCreatedDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  List<dynamic> _filterAnnouncements(List<dynamic> announcements) {
    if (_searchQuery.isEmpty) return announcements;

    return announcements.where((announcement) {
      final announcementMap = announcement as Map<String, dynamic>;
      final title = (announcementMap['title'] ?? '').toLowerCase();
      final description = (announcementMap['description'] ?? '').toLowerCase();
      final location = (announcementMap['location'] ?? '').toLowerCase();
      final contactInfo = (announcementMap['contactInfo'] ?? '').toLowerCase();
      final createdBy = (announcementMap['createUserName'] ?? '').toLowerCase();

      return title.contains(_searchQuery) ||
          description.contains(_searchQuery) ||
          location.contains(_searchQuery) ||
          contactInfo.contains(_searchQuery) ||
          createdBy.contains(_searchQuery);
    }).toList();
  }

  void _navigateToCreateAnnouncement({Map<String, dynamic>? announcement}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAnnouncementScreen(
          communityId: widget.communityId,
          announcement: announcement,
        ),
      ),
    );

    if (result == true && mounted) {
      Provider.of<AnnouncementProvider>(context, listen: false)
          .fetchAnnouncements(communityId: widget.communityId);
    }
  }

  void _showAnnouncementDetails(Map<String, dynamic> announcement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnnouncementDetailSheet(announcement: announcement),
    );
  }

  void _confirmDeleteAnnouncement(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final provider = Provider.of<AnnouncementProvider>(context, listen: false);
              final result = await provider.deleteAnnouncement(
                id: id,
                communityId: widget.communityId,
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: result['error'] ? Colors.red : Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,color: Primary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.add, color: Primary, size: 28),
              onPressed: () => _navigateToCreateAnnouncement(),
            ),
          ),
        ],



      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search announcements...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF800080)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF800080), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          // Announcements List
          Expanded(
            child: Consumer<AnnouncementProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF800080)));
                }

                if (provider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          provider.errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.fetchAnnouncements(communityId: widget.communityId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF800080),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ],
                    ),
                  );
                }

                final filteredAnnouncements = _filterAnnouncements(provider.announcements);

                if (filteredAnnouncements.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.announcement, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ? 'No announcements found for "$_searchQuery"' : 'No announcements available',
                          style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            child: const Text('Clear search', style: TextStyle(color: Color(0xFF800080))),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFF800080),
                  onRefresh: () => provider.fetchAnnouncements(communityId: widget.communityId),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredAnnouncements.length,
                    itemBuilder: (context, index) {
                      final announcement = filteredAnnouncements[index] as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => _showAnnouncementDetails(announcement),
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.grey.shade50],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF800080).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _getAnnouncementIcon(announcement),
                                          color: const Color(0xFF800080),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              announcement['title'] ?? 'Untitled',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'by ${announcement['createUserName'] ?? 'Unknown'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _navigateToCreateAnnouncement(announcement: announcement);
                                          } else if (value == 'delete') {
                                            _confirmDeleteAnnouncement(announcement['_id']);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, color: Colors.blue, size: 20),
                                                SizedBox(width: 8),
                                                Text('Edit', style: TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.red, size: 20),
                                                SizedBox(width: 8),
                                                Text('Delete', style: TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    announcement['description'] ?? 'No description provided',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      if (announcement['location'] != null && announcement['location'].isNotEmpty) ...[
                                        Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            announcement['location'],
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      if (announcement['startDate'] != null && announcement['startDate'].isNotEmpty) ...[
                                        if (announcement['location'] != null && announcement['location'].isNotEmpty)
                                          const SizedBox(width: 16),
                                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(announcement['startDate']),
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF800080).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Tap for details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: const Color(0xFF800080),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateAnnouncement(),
        backgroundColor: const Color(0xFF800080),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  IconData _getAnnouncementIcon(Map<String, dynamic> announcement) {
    final title = (announcement['title'] ?? '').toString().toLowerCase();
    final description = (announcement['description'] ?? '').toString().toLowerCase();

    if (title.contains('job') || title.contains('opportunity') || title.contains('hiring')) {
      return Icons.work;
    } else if (title.contains('event') || title.contains('meeting') || title.contains('workshop')) {
      return Icons.event;
    } else if (title.contains('news') || title.contains('update') || title.contains('info')) {
      return Icons.info;
    } else if (title.contains('sale') || title.contains('offer') || title.contains('discount')) {
      return Icons.local_offer;
    } else {
      return Icons.announcement;
    }
  }
}

class AnnouncementDetailSheet extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementDetailSheet({super.key, required this.announcement});

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _formatCreatedDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF800080).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF800080),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.announcement, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement['title'] ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created ${_formatCreatedDate(announcement['createdAt'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailCard(
                    'Description',
                    announcement['description'] ?? 'No description provided',
                    Icons.description,
                  ),
                  if (announcement['createUserName'] != null && announcement['createUserName'].isNotEmpty)
                    _buildDetailCard(
                      'Created By',
                      announcement['createUserName'],
                      Icons.person,
                    ),
                  if (announcement['startDate'] != null && announcement['startDate'].isNotEmpty)
                    _buildDetailCard(
                      'Start Date',
                      _formatDate(announcement['startDate']),
                      Icons.calendar_today,
                    ),
                  if (announcement['endDate'] != null && announcement['endDate'].isNotEmpty)
                    _buildDetailCard(
                      'End Date',
                      _formatDate(announcement['endDate']),
                      Icons.calendar_month,
                    ),
                  if (announcement['time'] != null && announcement['time'].isNotEmpty)
                    _buildDetailCard(
                      'Time',
                      announcement['time'],
                      Icons.access_time,
                    ),
                  if (announcement['endTime'] != null && announcement['endTime'].isNotEmpty)
                    _buildDetailCard(
                      'End Time',
                      announcement['endTime'],
                      Icons.schedule,
                    ),
                  if (announcement['location'] != null && announcement['location'].isNotEmpty)
                    _buildDetailCard(
                      'Location',
                      announcement['location'],
                      Icons.location_on,
                    ),
                  if (announcement['contactInfo'] != null && announcement['contactInfo'].isNotEmpty)
                    _buildDetailCard(
                      'Contact Information',
                      announcement['contactInfo'],
                      Icons.contact_mail,
                    ),
                  if (announcement['company'] != null && announcement['company'].isNotEmpty)
                    _buildDetailCard(
                      'Company',
                      announcement['company'],
                      Icons.business,
                    ),
                  if (announcement['experience'] != null && announcement['experience'].isNotEmpty)
                    _buildDetailCard(
                      'Experience Required',
                      announcement['experience'],
                      Icons.work_history,
                    ),
                  if (announcement['employmentType'] != null && announcement['employmentType'].isNotEmpty)
                    _buildDetailCard(
                      'Employment Type',
                      announcement['employmentType'],
                      Icons.work,
                    ),
                  if (announcement['salaryRange'] != null && announcement['salaryRange'].isNotEmpty)
                    _buildDetailCard(
                      'Salary Range',
                      '${announcement['currency'] ?? ''} ${announcement['salaryRange']}',
                      Icons.payments,
                    ),
                  if (announcement['url'] != null && announcement['url'].isNotEmpty)
                    _buildDetailCard(
                      'URL',
                      announcement['url'],
                      Icons.link,
                      isUrl: true,
                    ),
                  _buildDetailCard(
                    'Template Type',
                    _capitalizeString(announcement['templateType'] ?? 'event'),
                    Icons.category,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizeString(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget _buildDetailCard(String title, String content, IconData icon, {bool isUrl = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF800080)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF800080),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade800,
              height: 1.4,
              decoration: isUrl ? TextDecoration.underline : null,
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}