import 'package:flutter/material.dart';
import 'package:ixes.app/screens/chats_page/group_chat/group_request.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../providers/group_provider.dart';

import 'create_group.dart';
import 'group_chat_detail.dart';

class MyGroupsScreen extends StatefulWidget {
  final String? communityId;

  const MyGroupsScreen({
    Key? key,
    this.communityId,
  }) : super(key: key);

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _filteredGroups = [];
  bool _isSearching = false;
  bool _hasInitialized = false; // Add this to track initialization

  // Pagination variables
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _setupScrollListener();
  }

  void _initializeScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GroupChatProvider>();

      // Check if we already have groups data to avoid unnecessary API calls
      if (provider.myGroups.isNotEmpty && !_hasInitialized) {
        setState(() {
          _filteredGroups = provider.myGroups;
          _hasInitialized = true;
        });
      } else if (!_hasInitialized) {
        _fetchMyGroups();
      }
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreGroups();
      }
    });
  }

  Future<void> _fetchMyGroups({bool reset = true}) async {
    final provider = context.read<GroupChatProvider>();

    if (reset) {
      _currentPage = 1;
      _hasMoreData = true;
    }

    await provider.fetchMyGroups(communityId: widget.communityId);

    if (mounted) {
      setState(() {
        _filteredGroups = provider.myGroups;
        _hasInitialized = true;
        // Simulate pagination for now - you can modify this based on your API
        _hasMoreData = provider.myGroups.length >= _pageSize;
      });
    }
  }

  Future<void> _loadMoreGroups() async {
    if (_isLoadingMore || !_hasMoreData || _isSearching) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simulate pagination - replace with actual paginated API call
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _currentPage++;
      _isLoadingMore = false;
      // For now, we'll just stop loading more after first page
      _hasMoreData = false;
    });
  }

  void _onSearchChanged(String query) {
    final provider = context.read<GroupChatProvider>();

    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredGroups = provider.filterMyGroups(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    final provider = context.read<GroupChatProvider>();

    setState(() {
      _isSearching = false;
      _filteredGroups = provider.myGroups;
    });
  }

  Future<void> _refreshGroups() async {
    await _fetchMyGroups(reset: true);
  }

  void _navigateToGroupChat(Map<String, dynamic> group) {
    final provider = context.read<GroupChatProvider>();
    provider.setCurrentGroup(group['_id']);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatDetailPage(
          groupId: group['_id'] ?? '',
          groupName: group['name'] ?? 'Unknown Group',
          isAdmin: group['isAdmin'] == true, // ✅ Pass admin flag
        ),
      ),
    );
  }


  void _navigateToCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );
  }

  void _navigateToRequests() {
    Navigator.pushNamed(context, '/group-requests');
  }

  void _showGroupOptions(Map<String, dynamic> group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GroupOptionsBottomSheet(group: group),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSearching
                      ? Icons.search_off_rounded
                      : Icons.group_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isSearching ? 'No groups found' : 'No groups yet',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSearching
                    ? 'Try different search terms'
                    : 'Create or join a group to start chatting',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              if (!_isSearching) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _navigateToCreateGroup,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Create Group',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshGroups,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final members = group['members'] as List<dynamic>? ?? [];
    final memberCount = members.length;
    final lastMessage = group['lastMessage'] as Map<String, dynamic>?;
    final hasUnreadMessages =
        group['unreadCount'] != null && group['unreadCount'] > 0;
    final unreadCount = group['unreadCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToGroupChat(group),
          onLongPress: () => _showGroupOptions(group),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Group Avatar - Fixed to always show first letter when no image
                _buildGroupAvatar(group),
                const SizedBox(width: 12),

                // Group Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group name and admin badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group['name'] ?? 'Unnamed Group',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (group['isAdmin'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.orange[200]!, width: 0.5),
                              ),
                              child: Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange[700],
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Last message or description
                      if (lastMessage != null)
                        Text(
                          '${lastMessage['sender']?['profile']?['name'] ?? 'Someone'}: ${lastMessage['text'] ?? 'Sent a file'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: hasUnreadMessages
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (group['description'] != null &&
                          group['description'].toString().isNotEmpty)
                        Text(
                          group['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 6),

                      // Member count
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          if (hasUnreadMessages)
                            Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[500],
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Separate method for building group avatar to ensure proper fallback
  Widget _buildGroupAvatar(Map<String, dynamic> group) {
    final groupName = group['name'] ?? 'G';
    final firstLetter = groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G';
    final profileImage = group['profileImage'];

    // Check if we have a valid profile image
    bool hasValidImage = profileImage != null &&
        profileImage.toString().isNotEmpty &&
        profileImage.toString() != 'null';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: !hasValidImage
            ? LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
      ),
      child: hasValidImage
          ? CircleAvatar(
        radius: 24,
        backgroundColor: Colors.transparent,
        backgroundImage: _getImageProvider(profileImage),
        onBackgroundImageError: (exception, stackTrace) {
          // If image fails to load, rebuild with fallback
          if (mounted) {
            setState(() {
              group['profileImage'] = null;
            });
          }
        },
        child: null,
      )
          : CircleAvatar(
        radius: 24,
        backgroundColor: Colors.transparent,
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading more groups...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getImageProvider(String? imageData) {
    if (imageData == null || imageData.isEmpty || imageData == 'null') {
      return null;
    }

    try {
      if (imageData.startsWith('data:image') ||
          imageData.startsWith('/9j/') ||
          imageData.startsWith('iVBORw0KGgo')) {
        String base64String = imageData;
        if (imageData.startsWith('data:image')) {
          base64String = imageData.split(',')[1];
        }
        return MemoryImage(base64Decode(base64String));
      } else {
        return NetworkImage(imageData);
      }
    } catch (e) {
      print('Error creating image provider: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Groups',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupRequestScreen(),
                ),
              );
            },
            child: Text(
              'Requests',
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<GroupChatProvider>(
        builder: (context, provider, child) {
          // Modified loading condition to prevent flash of empty state
          if (provider.isLoadingMyGroups && !_hasInitialized) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 16),
                  Text(
                    'Loading groups...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.myGroupsError != null) {
            return _buildErrorState(provider.myGroupsError!);
          }

          // Use _filteredGroups which is managed by local state
          final groupsToDisplay = _filteredGroups;

          return Column(
            children: [
              // Search Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search groups...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: Colors.grey[500],
                          size: 18,
                        ),
                        onPressed: _clearSearch,
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),

              // Groups List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshGroups,
                  color: Colors.blue[600],
                  backgroundColor: Colors.white,
                  child: groupsToDisplay.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount:
                    groupsToDisplay.length + (_isLoadingMore ? 1 : 0),
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemBuilder: (context, index) {
                      if (index >= groupsToDisplay.length) {
                        return _buildLoadingMoreIndicator();
                      }

                      final group = groupsToDisplay[index];
                      return _buildGroupCard(group);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGroup,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add_rounded, size: 24),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _GroupOptionsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> group;

  const _GroupOptionsBottomSheet({required this.group});

  @override
  Widget build(BuildContext context) {
    final isAdmin = group['isAdmin'] == true;
    final members = group['members'] as List<dynamic>? ?? [];
    final memberCount = members.length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Group header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _buildBottomSheetAvatar(group),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['name'] ?? 'Unnamed Group',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey[200]),

            // Options
            _OptionTile(
              icon: Icons.info_outline_rounded,
              title: 'Group Info',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/group-info', arguments: group);
              },
            ),

            _OptionTile(
              icon: Icons.people_outline_rounded,
              title: 'Members',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/group-members',
                    arguments: group);
              },
            ),

            if (isAdmin) ...[
              _OptionTile(
                icon: Icons.settings_outlined,
                title: 'Group Settings',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/group-settings',
                      arguments: group);
                },
              ),
              _OptionTile(
                icon: Icons.person_add_outlined,
                title: 'Manage Requests',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/group-requests',
                      arguments: group);
                },
              ),
            ],

            _OptionTile(
              icon: Icons.exit_to_app_rounded,
              title: 'Leave Group',
              textColor: Colors.red[600],
              onTap: () {
                Navigator.pop(context);
                _showLeaveGroupDialog(context, group);
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Separate avatar builder for bottom sheet
  Widget _buildBottomSheetAvatar(Map<String, dynamic> group) {
    final groupName = group['name'] ?? 'G';
    final firstLetter = groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G';
    final profileImage = group['profileImage'];

    bool hasValidImage = profileImage != null &&
        profileImage.toString().isNotEmpty &&
        profileImage.toString() != 'null';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: !hasValidImage
            ? LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
      ),
      child: hasValidImage
          ? CircleAvatar(
        radius: 22,
        backgroundColor: Colors.transparent,
        backgroundImage: _getImageProvider(profileImage),
        child: null,
      )
          : CircleAvatar(
        radius: 22,
        backgroundColor: Colors.transparent,
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  ImageProvider? _getImageProvider(String? imageData) {
    if (imageData == null || imageData.isEmpty || imageData == 'null') {
      return null;
    }

    try {
      if (imageData.startsWith('data:image') ||
          imageData.startsWith('/9j/') ||
          imageData.startsWith('iVBORw0KGgo')) {
        String base64String = imageData;
        if (imageData.startsWith('data:image')) {
          base64String = imageData.split(',')[1];
        }
        return MemoryImage(base64Decode(base64String));
      } else {
        return NetworkImage(imageData);
      }
    } catch (e) {
      print('Error creating image provider: $e');
      return null;
    }
  }

  void _showLeaveGroupDialog(BuildContext context, Map<String, dynamic> group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Group',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to leave "${group['name']}"? You won\'t be able to see new messages.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                  Text('Leave group functionality not implemented yet'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              'Leave',
              style: TextStyle(
                color: Colors.red[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? Colors.grey[700],
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      dense: true,
    );
  }
}