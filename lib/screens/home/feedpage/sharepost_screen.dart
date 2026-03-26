import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/comment_provider.dart';
import '../../../providers/group_provider.dart';

class SharePostScreen extends StatefulWidget {
  final String postId;
  final String shareContext;
  final String? contextId;

  const SharePostScreen({
    Key? key,
    required this.postId,
    this.shareContext = 'feed',
    this.contextId,
  }) : super(key: key);

  @override
  State<SharePostScreen> createState() => _SharePostScreenState();
}

class _SharePostScreenState extends State<SharePostScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Users tab state ───────────────────────────────────────────────────
  final TextEditingController _userSearchController = TextEditingController();
  String _userSearchQuery = '';
  bool _isUserSearching = false;
  int _currentUserPage = 1;
  final ScrollController _userScrollController = ScrollController();

  // ── Groups tab state ──────────────────────────────────────────────────
  final TextEditingController _groupSearchController = TextEditingController();
  String _groupSearchQuery = '';
  final ScrollController _groupScrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _loadGroups();
    });
    _userScrollController.addListener(_onUserScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    _groupSearchController.dispose();
    _userScrollController.dispose();
    _groupScrollController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<CommentProvider>(context, listen: false).clearUsersList();
      }
    });
    super.dispose();
  }

  // ── Users ─────────────────────────────────────────────────────────────
  void _loadUsers({bool isLoadMore = false}) {
    final provider = Provider.of<CommentProvider>(context, listen: false);
    if (isLoadMore) {
      if (_currentUserPage < provider.totalUserPages) {
        _currentUserPage++;
        provider.fetchAllUsers(
          search: _userSearchQuery.isEmpty ? null : _userSearchQuery,
          pageNo: _currentUserPage,
          isLoadMore: true,
        );
      }
    } else {
      _currentUserPage = 1;
      provider.fetchAllUsers(
        search: _userSearchQuery.isEmpty ? null : _userSearchQuery,
        pageNo: _currentUserPage,
      );
    }
  }

  void _onUserScroll() {
    if (_userScrollController.position.pixels >=
        _userScrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<CommentProvider>(context, listen: false);
      if (!provider.isLoadingUsers &&
          _currentUserPage < provider.totalUserPages) {
        _loadUsers(isLoadMore: true);
      }
    }
  }

  void _onUserSearchChanged(String value) {
    setState(() {
      _userSearchQuery = value;
      _isUserSearching = value.isNotEmpty;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_userSearchQuery == value) _loadUsers();
    });
  }

  Future<void> _shareToUser(String userId, String userName) async {
    final provider = Provider.of<CommentProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await provider.sharePost(
      context: context,
      postId: widget.postId,
      type: 'user',
      userId: userId,
      shareContext: widget.shareContext,
      contextId: widget.contextId,
    );

    if (mounted) Navigator.pop(context);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post shared with $userName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── Groups ────────────────────────────────────────────────────────────
  void _loadGroups() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<GroupChatProvider>(context, listen: false);
      provider.fetchMyGroups();
    });
  }

  void _onGroupSearchChanged(String value) {
    setState(() => _groupSearchQuery = value);
  }

  Future<void> _shareToGroup(String groupId, String groupName) async {
    final provider = Provider.of<CommentProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await provider.sharePost(
      context: context,
      postId: widget.postId,
      type: 'group',
      userId: groupId, // API uses userId field for both user and group ID
      shareContext: widget.shareContext,
      contextId: widget.contextId,
    );

    if (mounted) Navigator.pop(context);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post shared to $groupName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            Provider.of<CommentProvider>(context, listen: false)
                .clearUsersList();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Share Post',
          style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6200EE),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6200EE),
          indicatorWeight: 2.5,
          labelStyle:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'People'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildGroupsTab(),
        ],
      ),
    );
  }

  // ── USERS TAB ─────────────────────────────────────────────────────────
  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildSearchField(
            controller: _userSearchController,
            hint: 'Search people...',
            onChanged: _onUserSearchChanged,
            onClear: () {
              _userSearchController.clear();
              _onUserSearchChanged('');
            },
          ),
        ),
        Expanded(
          child: Consumer<CommentProvider>(
            builder: (context, provider, _) {
              if (provider.isLoadingUsers && provider.allUsers.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.allUsers.isEmpty) {
                return _buildEmptyState(
                    Icons.people_outline,
                    _isUserSearching ? 'No people found' : 'No people available');
              }
              return ListView.separated(
                controller: _userScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: provider.allUsers.length +
                    (provider.isLoadingUsers ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == provider.allUsers.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final user = provider.allUsers[index];
                  final profile = user['profile'] as Map<String, dynamic>?;
                  final userName = profile?['name'] ?? 'Unknown User';
                  final profileImage = profile?['profileImage'] as String?;
                  final email = user['email'] ?? '';
                  final userId = user['_id'] ?? '';

                  return _buildShareTile(
                    avatar: _buildAvatar(profileImage, userName),
                    title: userName,
                    subtitle: email.isNotEmpty ? email : null,
                    onSend: () => _shareToUser(userId, userName),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── GROUPS TAB ────────────────────────────────────────────────────────
  Widget _buildGroupsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildSearchField(
            controller: _groupSearchController,
            hint: 'Search groups...',
            onChanged: _onGroupSearchChanged,
            onClear: () {
              _groupSearchController.clear();
              _onGroupSearchChanged('');
            },
          ),
        ),
        Expanded(
          child: Consumer<GroupChatProvider>(
            builder: (context, provider, _) {
              if (provider.isLoadingMyGroups && provider.myGroups.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final groups = _groupSearchQuery.isEmpty
                  ? provider.myGroups
                  : provider.myGroups.where((g) {
                final name =
                (g['name'] ?? '').toString().toLowerCase();
                return name
                    .contains(_groupSearchQuery.toLowerCase());
              }).toList();

              if (groups.isEmpty) {
                return _buildEmptyState(
                    Icons.group_outlined,
                    _groupSearchQuery.isNotEmpty
                        ? 'No groups found'
                        : 'No groups available');
              }

              return ListView.separated(
                controller: _groupScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final groupName = group['name'] ?? 'Unnamed Group';
                  final groupId = group['_id'] ?? '';
                  final profileImage = group['profileImage'] as String?;
                  final members =
                      (group['members'] as List<dynamic>?)?.length ?? 0;

                  return _buildShareTile(
                    avatar: _buildGroupAvatar(profileImage, groupName),
                    title: groupName,
                    subtitle: '$members members',
                    onSend: () => _shareToGroup(groupId, groupName),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── SHARED WIDGETS ────────────────────────────────────────────────────
  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, color: Colors.grey),
          onPressed: onClear,
        )
            : null,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildShareTile({
    required Widget avatar,
    required String title,
    String? subtitle,
    required VoidCallback onSend,
  }) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      leading: avatar,
      title: Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle,
          style:
          TextStyle(fontSize: 13, color: Colors.grey[600]))
          : null,
      trailing: ElevatedButton(
        onPressed: onSend,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6200EE),
          foregroundColor: Colors.white,
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: const Text('Send',
            style:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAvatar(String? profileImage, String name) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.grey[300],
      backgroundImage:
      profileImage != null && profileImage.isNotEmpty
          ? NetworkImage(profileImage)
          : null,
      child: profileImage == null || profileImage.isEmpty
          ? Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
      )
          : null,
    );
  }

  Widget _buildGroupAvatar(String? profileImage, String name) {
    final hasImage = profileImage != null && profileImage.isNotEmpty;
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF8A2BE2),
      backgroundImage: hasImage ? NetworkImage(profileImage!) : null,
      child: !hasImage
          ? const Icon(Icons.group, color: Colors.white, size: 22)
          : null,
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey[350]),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}