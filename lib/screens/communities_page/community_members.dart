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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(BuildContext context, String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
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

  List<dynamic> _getFilteredMembers(List<dynamic> membersList) {
    if (_searchQuery.isEmpty) {
      return membersList;
    }

    return membersList.where((member) {
      final user = member['userId'] as Map<String, dynamic>? ?? {};
      final profile = user['profile'] as Map<String, dynamic>? ?? {};
      final userName = (profile['name'] as String? ?? '').toLowerCase();
      final userRole = (member['userRole'] as String? ?? '').toLowerCase();
      final userMobile = (user['mobile'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();

      return userName.contains(query) ||
          userRole.contains(query) ||
          userMobile.contains(query);
    }).toList();
  }

  void _showMemberDetails(BuildContext context, Map<String, dynamic> member) {
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
    final superAdmin = member['superAdmin'] as bool? ?? false;
    final userId = user['_id'] as String? ?? '';
    String currentUserId = '667ef2f47487c7d72afd9645';
    bool showMenu = isViewerAdmin && userId != currentUserId && !superAdmin;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header with Avatar
                    Stack(
                      children: [
                        Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Primary,
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
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
                                        fontSize: 32,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                    ),
                                    child: Icon(
                                      _getStatusIcon(status),
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                                const SizedBox(width: 8),
                                if (superAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.purple,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'SUPER ADMIN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else if (isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'ADMIN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (showMenu)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              onSelected: (value) async {
                                final provider = Provider.of<CommunityProvider>(context, listen: false);
                                if (value == 'toggle_admin') {
                                  final result = await provider.updateAdminStatusProvider(
                                    widget.communityId,
                                    userId,
                                    !isAdmin,
                                  );
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _showSnackBar(
                                      context,
                                      result['message'] as String,
                                      result['error'] as bool,
                                    );
                                  }
                                } else if (value == 'remove') {
                                  Navigator.pop(context);
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

                    const SizedBox(height: 32),

                    // Details Section
                    Column(
                      children: [
                        if (userEmail.isNotEmpty)
                          _buildDetailItem(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: userEmail,
                            iconColor: Colors.blue,
                          ),

                        if (userMobile.isNotEmpty)
                          _buildDetailItem(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: userMobile,
                            iconColor: Colors.green,
                          ),

                        if (profile['birthdate'] != null)
                          _buildDetailItem(
                            icon: Icons.cake_outlined,
                            label: 'Birthday',
                            value: _formatDate(profile['birthdate']),
                            iconColor: Colors.orange,
                          ),

                        if (profile['location'] != null)
                          _buildDetailItem(
                            icon: Icons.location_on_outlined,
                            label: 'Location',
                            value: profile['location'],
                            iconColor: Colors.red,
                          ),

                        if (profile['address'] != null)
                          _buildDetailItem(
                            icon: Icons.home_outlined,
                            label: 'Address',
                            value: profile['address'],
                            iconColor: Colors.indigo,
                          ),

                        _buildDetailItem(
                          icon: Icons.person_outline,
                          label: 'Status',
                          value: status,
                          iconColor: _getStatusColor(status),
                        ),

                        if (createdAt.isNotEmpty)
                          _buildDetailItem(
                            icon: Icons.calendar_today_outlined,
                            label: 'Joined',
                            value: _formatDate(createdAt),
                            iconColor: Colors.indigo,
                            showDivider: false,
                          ),
                      ],
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

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            color: Colors.grey.shade200,
            height: 1,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CommunityProvider>(context);
    final membersList = (provider.communityUsers['data'] as List<dynamic>?) ?? [];
    final filteredMembers = _getFilteredMembers(membersList);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          'Community Members',
          style: TextStyle(
            fontSize: 20,
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

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by name, role, or phone...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade400),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Members List
          Expanded(
            child: filteredMembers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
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
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index] as Map<String, dynamic>;
                final user = member['userId'] as Map<String, dynamic>? ?? {};
                final profile = user['profile'] as Map<String, dynamic>? ?? {};
                final userName = profile['name'] as String? ?? 'Unknown User';
                final userRole = member['userRole'] as String? ?? 'Member';
                final isAdmin = member['isAdmin'] as bool? ?? false;
                final superAdmin = member['superAdmin'] as bool? ?? false;
                final profileImage = profile['profileImage'] as String? ?? '';
                final userMobile = user['mobile'] as String? ?? '';

                final userId = user['_id'] as String? ?? '';
                final status = member['status'] as String? ?? 'UNKNOWN';
                String currentUserId = '667ef2f47487c7d72afd9645';
                bool showMenu = isViewerAdmin && userId != currentUserId && !superAdmin;

                return GestureDetector(
                  onTap: () => _showMemberDetails(context, member),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            // Avatar
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Primary.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 28,
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Name and Role
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userRole,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 40),
                          ],
                        ),

                        // Three Dots Menu on Top Right
                        if (showMenu)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              onSelected: (value) async {
                                final provider = Provider.of<CommunityProvider>(context, listen: false);
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

                        // Badge on Bottom Right
                        if (superAdmin || isAdmin)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: superAdmin
                                ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'SUPER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                                : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
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