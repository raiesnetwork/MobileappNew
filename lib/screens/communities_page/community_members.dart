import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../providers/communities_provider.dart';
import '../../constants/constants.dart';

class CommunityMembersScreen extends StatefulWidget {
  final String communityId;

  const CommunityMembersScreen({super.key, required this.communityId});

  @override
  State<CommunityMembersScreen> createState() => _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> {
  bool isViewerAdmin = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    provider.fetchCommunityUsers(widget.communityId).then((_) {
      String currentUserId = '667ef2f47487c7d72afd9645'; // Placeholder: replace with actual currentUserId
      final membersList = (provider.communityUsers['data'] as List<dynamic>?) ?? [];
      for (var member in membersList) {
        if (member['userId']['_id'] == currentUserId) {
          setState(() {
            isViewerAdmin = member['isAdmin'] as bool? ?? false;
          });
          break;
        }
      }
    });
  }

  void _showSnackBar(BuildContext context, String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CommunityProvider>(context);
    final membersList = (provider.communityUsers['data'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          'Community Members',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Primary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: provider.isLoading && membersList.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Primary),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Loading community members...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : provider.error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: ${provider.error}',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : membersList.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No members found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Header Stats
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Primary.withOpacity(0.1), Primary.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.people,
                  label: 'Total Members',
                  value: membersList.length.toString(),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Primary.withOpacity(0.3),
                ),
                _buildStatItem(
                  icon: Icons.admin_panel_settings,
                  label: 'Admins',
                  value: membersList.where((m) => m['isAdmin'] == true).length.toString(),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Primary.withOpacity(0.3),
                ),
                _buildStatItem(
                  icon: Icons.check_circle,
                  label: 'Active',
                  value: membersList.where((m) => m['status'] == 'ACCEPTED').length.toString(),
                ),
              ],
            ),
          ),

          // Members List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: membersList.length,
              itemBuilder: (context, index) {
                final member = membersList[index] as Map<String, dynamic>;
                final user = member['userId'] as Map<String, dynamic>? ?? {};
                final profile = user['profile'] as Map<String, dynamic>? ?? {};
                final userName = profile['name'] as String? ?? 'Unknown User';
                final userRole = member['userRole'] as String? ?? 'Member';
                final isAdmin = member['isAdmin'] as bool? ?? false;
                final status = member['status'] as String? ?? 'UNKNOWN';
                final profileImage = profile['profileImage'] as String? ?? '';
                final userEmail = user['email'] as String? ?? '';
                final userMobile = user['mobile'] as String? ?? '';
                final createdAt = member['createdAt'] as String? ?? '';
                final isFamilyHead = profile['isFamilyHead'] as bool? ?? false;
                final superAdmin = member['superAdmin'] as bool? ?? false;
                final userId = user['_id'] as String? ?? '';

                String currentUserId = '667ef2f47487c7d72afd9645'; // Placeholder

                bool showMenu = isViewerAdmin && userId != currentUserId && !superAdmin;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Header Row with Avatar and Basic Info
                            Row(
                              children: [
                                // Enhanced Avatar with Status Indicator
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          width: 0.2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 32,
                                        backgroundImage: profileImage.isNotEmpty
                                            ? profileImage.startsWith('data:image')
                                            ? MemoryImage(
                                          Uri.parse(profileImage).data!.contentAsBytes(),
                                        )
                                            : NetworkImage(profileImage) as ImageProvider
                                            : null,
                                        child: profileImage.isEmpty
                                            ? Text(
                                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        )
                                            : null,
                                      ),
                                    ),
                                    // Status Indicator
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: Icon(
                                          _getStatusIcon(status),
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),

                                // Name and Role
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              userName,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (superAdmin)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.purple,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'SUPER',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          if (isAdmin && !superAdmin)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Primary,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'ADMIN',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          userRole,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Divider
                            Container(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),

                            const SizedBox(height: 16),

                            // Member Details in Grid
                            Column(
                              children: [
                                if (userEmail.isNotEmpty || userMobile.isNotEmpty)
                                  Row(
                                    children: [
                                      if (userEmail.isNotEmpty)
                                        Expanded(
                                          child: _buildEnhancedInfoItem(
                                            icon: Icons.email_outlined,
                                            label: 'Email',
                                            value: userEmail,
                                            iconColor: Colors.blue,
                                          ),
                                        ),
                                      if (userEmail.isNotEmpty && userMobile.isNotEmpty)
                                        const SizedBox(width: 12),
                                      if (userMobile.isNotEmpty)
                                        Expanded(
                                          child: _buildEnhancedInfoItem(
                                            icon: Icons.phone_outlined,
                                            label: 'Phone',
                                            value: userMobile,
                                            iconColor: Colors.green,
                                          ),
                                        ),
                                    ],
                                  ),

                                if ((userEmail.isNotEmpty || userMobile.isNotEmpty) &&
                                    (profile['birthdate'] != null || profile['location'] != null))
                                  const SizedBox(height: 12),

                                if (profile['birthdate'] != null || profile['location'] != null)
                                  Row(
                                    children: [
                                      if (profile['birthdate'] != null)
                                        Expanded(
                                          child: _buildEnhancedInfoItem(
                                            icon: Icons.cake_outlined,
                                            label: 'Birthday',
                                            value: _formatDate(profile['birthdate']),
                                            iconColor: Colors.orange,
                                          ),
                                        ),
                                      if (profile['birthdate'] != null && profile['location'] != null)
                                        const SizedBox(width: 12),
                                      if (profile['location'] != null)
                                        Expanded(
                                          child: _buildEnhancedInfoItem(
                                            icon: Icons.location_on_outlined,
                                            label: 'Location',
                                            value: profile['location'],
                                            iconColor: Colors.red,
                                          ),
                                        ),
                                    ],
                                  ),

                                if (profile['address'] != null) ...[
                                  const SizedBox(height: 12),
                                  _buildEnhancedInfoItem(
                                    icon: Icons.home_outlined,
                                    label: 'Address',
                                    value: profile['address'],
                                    iconColor: Colors.indigo,
                                    fullWidth: true,
                                  ),
                                ],

                                // Member Status and Dates
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildEnhancedInfoItem(
                                        icon: Icons.person_outline,
                                        label: 'Status',
                                        value: status,
                                        iconColor: _getStatusColor(status),
                                      ),
                                    ),
                                    if (createdAt.isNotEmpty) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildEnhancedInfoItem(
                                          icon: Icons.calendar_today_outlined,
                                          label: 'Joined',
                                          value: _formatDate(createdAt),
                                          iconColor: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (showMenu)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (value) async {
                              if (value == 'toggle_admin') {
                                final result = await provider.updateAdminStatusProvider(
                                  widget.communityId,
                                  userId,
                                  !isAdmin,
                                );
                                if (mounted) {
                                  _showSnackBar(
                                    context,
                                    result['message'] as String,
                                    result['error'] as bool,
                                  );
                                }
                              } else if (value == 'remove') {
                                bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirm Removal'),
                                    content: const Text('Are you sure you want to remove this user from the community?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final result = await provider.removeUserFromCommunityProvider(
                                    widget.communityId,
                                    userId,
                                  );
                                  if (mounted) {
                                    _showSnackBar(
                                      context,
                                      result['message'] as String,
                                      result['error'] as bool,
                                    );
                                  }
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'toggle_admin',
                                child: Text(isAdmin ? 'Remove Admin' : 'Make Admin'),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove from Community'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Primary, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: fullWidth ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACCEPTED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACCEPTED':
        return Icons.check;
      case 'PENDING':
        return Icons.schedule;
      case 'REJECTED':
        return Icons.close;
      default:
        return Icons.help;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}