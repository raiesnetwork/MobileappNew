import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ixes.app/screens/chats_page/group_chat/group_request.dart';
import 'package:provider/provider.dart';

import '../../../providers/group_provider.dart';

import 'create_group.dart';
import 'getall_groups.dart';
import 'group_chat_detail.dart';

const Color kPrimary      = Color(0xFF8A2BE2);
const Color kPrimaryLight = Color(0xFFF3EAFD);
const Color kBg           = Color(0xFFF8F6FC);
const Color kSurface      = Colors.white;
const Color kTextDark     = Color(0xFF1A1025);
const Color kTextMid      = Color(0xFF6B6080);
const Color kTextLight    = Color(0xFFB0A8C0);
const Color kBorder       = Color(0xFFEDE8F5);

class MyGroupsScreen extends StatefulWidget {
  final String? communityId;
  const MyGroupsScreen({Key? key, this.communityId}) : super(key: key);
  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController      _scrollController = ScrollController();
  AnimationController?        _fadeController;

  List<Map<String, dynamic>> _filteredGroups   = [];
  bool   _isSearching     = false;
  bool   _hasInitialized  = false;
  bool   _isLoadingMore   = false;
  String _activeSearchQuery = '';   // tracks what was last sent to API
  Timer? _debounce;

  // kept for backward-compat but driven by provider now
  bool _hasMoreData = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _initializeScreen();
    _setupScrollListener();
  }

  void _initializeScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GroupChatProvider>();
      if (provider.myGroups.isNotEmpty && !_hasInitialized) {
        setState(() {
          _filteredGroups = provider.myGroups;
          _hasInitialized = true;
          _hasMoreData    = provider.myGroupsHasMore;
        });
        _fadeController?.forward();
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

  // ── FETCH (page 1 / reset) ────────────────────────────────────────────
  Future<void> _fetchMyGroups({bool reset = true}) async {
    final provider = context.read<GroupChatProvider>();
    await provider.fetchMyGroups(
      communityId: widget.communityId,
      search: _isSearching && _activeSearchQuery.isNotEmpty
          ? _activeSearchQuery
          : null,
    );
    if (mounted) {
      setState(() {
        _filteredGroups = provider.myGroups;
        _hasInitialized = true;
        _hasMoreData    = provider.myGroupsHasMore;
      });
      _fadeController?.forward();
    }
  }

  // ── LOAD MORE (infinite scroll) ───────────────────────────────────────
  Future<void> _loadMoreGroups() async {
    final provider = context.read<GroupChatProvider>();
    if (_isLoadingMore || !provider.myGroupsHasMore) return;

    setState(() => _isLoadingMore = true);
    await provider.loadMoreMyGroups(
      search: _isSearching && _activeSearchQuery.isNotEmpty
          ? _activeSearchQuery
          : null,
    );
    if (mounted) {
      setState(() {
        _filteredGroups = provider.myGroups;
        _isLoadingMore  = false;
        _hasMoreData    = provider.myGroupsHasMore;
      });
    }
  }

  // ── SEARCH ────────────────────────────────────────────────────────────
  void _onSearchChanged(String query) {
    _activeSearchQuery = query;
    final provider = context.read<GroupChatProvider>();

    if (query.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _isSearching    = false;
        _filteredGroups = provider.myGroups;
      });
      _fetchMyGroups(reset: true);
      return;
    }

    setState(() {
      _isSearching    = true;
      // Optimistic local filter while API call is in-flight
      _filteredGroups = provider.filterMyGroups(query);
    });

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _fetchMyGroups(reset: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  Future<void> _refreshGroups() async => _fetchMyGroups(reset: true);

  // ── NAVIGATION ────────────────────────────────────────────────────────
  void _navigateToGroupChat(Map<String, dynamic> group) async {
    context.read<GroupChatProvider>().setCurrentGroup(group['_id']);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatDetailPage(
          groupId:   group['_id']  ?? '',
          groupName: group['name'] ?? 'Unknown Group',
          isAdmin:   group['isAdmin'] == true,
        ),
      ),
    );

    // Re-sync after returning so badge is visually gone
    if (mounted) {
      final provider = context.read<GroupChatProvider>();
      setState(() => _filteredGroups = provider.myGroups); // instant local clear
      await provider.fetchMyGroups(communityId: widget.communityId); // server sync
      if (mounted) setState(() => _filteredGroups = provider.myGroups);
    }
  }

  void _navigateToCreateGroup() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
  }

  void _showGroupOptions(Map<String, dynamic> group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupOptionsBottomSheet(group: group),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                      color: kPrimaryLight, shape: BoxShape.circle),
                  child: Icon(
                      _isSearching
                          ? Icons.search_off_rounded
                          : Icons.group_outlined,
                      size: 40,
                      color: kPrimary),
                ),
                const SizedBox(height: 20),
                Text(
                    _isSearching ? 'No groups found' : 'No groups yet',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kTextDark)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    _isSearching
                        ? 'Try different search terms'
                        : 'Create or join a group to get started',
                    style: const TextStyle(fontSize: 14, color: kTextMid),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!_isSearching) ...[
                  const SizedBox(height: 32),
                  _PrimaryButton(
                      label: 'Create Group',
                      icon: Icons.add_rounded,
                      onTap: _navigateToCreateGroup),
                ],
              ]),
        ),
      ),
    );
  }

  // ── ERROR STATE ────────────────────────────────────────────────────────
  Widget _buildErrorState(String error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFEEEE), shape: BoxShape.circle),
                  child: const Icon(Icons.error_outline_rounded,
                      size: 40, color: Color(0xFFE53935)),
                ),
                const SizedBox(height: 20),
                const Text('Something went wrong',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kTextDark)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(error,
                      style: const TextStyle(fontSize: 14, color: kTextMid),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 28),
                _PrimaryButton(
                    label: 'Try Again',
                    icon: Icons.refresh_rounded,
                    onTap: _refreshGroups),
              ]),
        ),
      ),
    );
  }

  // ── GROUP CARD ─────────────────────────────────────────────────────────
  Widget _buildGroupCard(Map<String, dynamic> group, int index) {
    final members     = group['members'] as List<dynamic>? ?? [];
    final memberCount = members.length;
    final lastMessage = group['lastMessage'] as Map<String, dynamic>?;
    final unreadCount = group['unreadCount'] ?? 0;
    final hasUnread   = unreadCount > 0;
    final isAdmin     = group['isAdmin'] == true;

    final animation = _fadeController != null
        ? CurvedAnimation(
      parent: _fadeController!,
      curve: Interval(
        (index * 0.05).clamp(0.0, 0.8),
        ((index * 0.05) + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
    )
        : const AlwaysStoppedAnimation<double>(1.0);

    return FadeTransition(
      opacity: animation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _navigateToGroupChat(group),
            onLongPress: () => _showGroupOptions(group),
            borderRadius: BorderRadius.circular(16),
            splashColor: kPrimaryLight,
            highlightColor: kPrimaryLight.withOpacity(0.5),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasUnread ? kPrimary.withOpacity(0.3) : kBorder,
                  width: hasUnread ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                _buildGroupAvatar(group),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              group['name'] ?? 'Unnamed Group',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: kTextDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: kPrimaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('ADMIN',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: kPrimary,
                                      letterSpacing: 0.5)),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        if (lastMessage != null)
                          Text(
                            '${lastMessage['sender']?['profile']?['name'] ?? 'Someone'}: ${lastMessage['text'] ?? 'Sent a file'}',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                              hasUnread ? kTextDark : kTextMid,
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (group['description'] != null &&
                            group['description'].toString().isNotEmpty)
                          Text(group['description'],
                              style: const TextStyle(
                                  fontSize: 13, color: kTextMid),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.people_alt_rounded,
                              size: 13, color: kTextLight),
                          const SizedBox(width: 4),
                          Text(
                            '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: kTextLight,
                                fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          if (hasUnread)
                            Container(
                              constraints:
                              const BoxConstraints(minWidth: 20),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: kPrimary,
                                  borderRadius:
                                  BorderRadius.circular(10)),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : '$unreadCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ]),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── GROUP AVATAR ───────────────────────────────────────────────────────
  Widget _buildGroupAvatar(Map<String, dynamic> group) {
    final profileImage  = group['profileImage'];
    final hasValidImage = profileImage != null &&
        profileImage.toString().isNotEmpty &&
        profileImage.toString() != 'null';

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: !hasValidImage
            ? const LinearGradient(
            colors: [Color(0xFFB06EF5), kPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
            : null,
      ),
      child: hasValidImage
          ? CircleAvatar(
        radius: 25,
        backgroundColor: Colors.transparent,
        backgroundImage: _getImageProvider(profileImage),
        onBackgroundImageError: (_, __) {
          if (mounted) setState(() => group['profileImage'] = null);
        },
      )
          : const CircleAvatar(
        radius: 25,
        backgroundColor: Colors.transparent,
        child: Icon(Icons.group_rounded,
            color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(kPrimary)),
        ),
      ),
    );
  }

  ImageProvider? _getImageProvider(String? imageData) {
    if (imageData == null || imageData.isEmpty || imageData == 'null')
      return null;
    try {
      if (imageData.startsWith('data:image') ||
          imageData.startsWith('/9j/') ||
          imageData.startsWith('iVBORw0KGgo')) {
        final b64 = imageData.startsWith('data:image')
            ? imageData.split(',')[1]
            : imageData;
        return MemoryImage(base64Decode(b64));
      }
      return NetworkImage(imageData);
    } catch (_) {
      return null;
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      body: Consumer<GroupChatProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingMyGroups && !_hasInitialized) {
            return const Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                            AlwaysStoppedAnimation(kPrimary))),
                    SizedBox(height: 16),
                    Text('Loading groups...',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: kTextMid)),
                  ]),
            );
          }

          if (provider.myGroupsError != null)
            return _buildErrorState(provider.myGroupsError!);

          return Column(children: [
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshGroups,
                color: kPrimary,
                backgroundColor: kSurface,
                child: _filteredGroups.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                  const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: _filteredGroups.length +
                      (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _filteredGroups.length)
                      return _buildLoadingMoreIndicator();
                    return _buildGroupCard(
                        _filteredGroups[index], index);
                  },
                ),
              ),
            ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGroup,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 20,
      title: const Text('My Groups',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: kTextDark,
              letterSpacing: -0.3)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kBorder),
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const GroupListScreen())),
          icon: const Icon(Icons.explore_outlined,
              color: kPrimary, size: 22),
          tooltip: 'Discover Groups',
        ),
        TextButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => GroupRequestScreen())),
          style: TextButton.styleFrom(
              foregroundColor: kPrimary,
              padding:
              const EdgeInsets.symmetric(horizontal: 12)),
          child: const Text('Requests',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: kSurface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 15, color: kTextDark),
        decoration: InputDecoration(
          hintText: 'Search groups...',
          hintStyle: const TextStyle(color: kTextLight, fontSize: 14),
          prefixIcon:
          const Icon(Icons.search_rounded, color: kPrimary, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: kTextLight, size: 18),
              onPressed: _clearSearch)
              : null,
          filled: true,
          fillColor: kBg,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: kPrimary, width: 1.5)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _fadeController?.dispose();
    super.dispose();
  }
}

// ── PRIMARY BUTTON ─────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPrimary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}

// ── GROUP OPTIONS BOTTOM SHEET ─────────────────────────────────────────────
class _GroupOptionsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> group;
  const _GroupOptionsBottomSheet({required this.group});

  @override
  Widget build(BuildContext context) {
    final isAdmin     = group['isAdmin'] == true;
    final members     = group['members'] as List<dynamic>? ?? [];
    final memberCount = members.length;

    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              _buildAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group['name'] ?? 'Unnamed Group',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: kTextDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                          '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: kTextMid,
                              fontWeight: FontWeight.w500)),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: kBorder),
          const SizedBox(height: 4),
          _OptionTile(
              icon: Icons.info_outline_rounded,
              title: 'Group Info',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/group-info',
                    arguments: group);
              }),
          _OptionTile(
              icon: Icons.people_outline_rounded,
              title: 'Members',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/group-members',
                    arguments: group);
              }),
          if (isAdmin) ...[
            _OptionTile(
                icon: Icons.settings_outlined,
                title: 'Group Settings',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/group-settings',
                      arguments: group);
                }),
            _OptionTile(
                icon: Icons.person_add_outlined,
                title: 'Manage Requests',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/group-requests',
                      arguments: group);
                }),
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
        ]),
      ),
    );
  }

  Widget _buildAvatar() {
    final profileImage  = group['profileImage'];
    final hasValidImage = profileImage != null &&
        profileImage.toString().isNotEmpty &&
        profileImage.toString() != 'null';

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: !hasValidImage
            ? const LinearGradient(
            colors: [Color(0xFFB06EF5), kPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
            : null,
      ),
      child: hasValidImage
          ? CircleAvatar(
          radius: 23,
          backgroundColor: Colors.transparent,
          backgroundImage: _getImageProvider(profileImage))
          : const CircleAvatar(
        radius: 23,
        backgroundColor: Colors.transparent,
        child: Icon(Icons.group_rounded,
            color: Colors.white, size: 22),
      ),
    );
  }

  ImageProvider? _getImageProvider(String? imageData) {
    if (imageData == null || imageData.isEmpty || imageData == 'null')
      return null;
    try {
      if (imageData.startsWith('data:image') ||
          imageData.startsWith('/9j/') ||
          imageData.startsWith('iVBORw0KGgo')) {
        final b64 = imageData.startsWith('data:image')
            ? imageData.split(',')[1]
            : imageData;
        return MemoryImage(base64Decode(b64));
      }
      return NetworkImage(imageData);
    } catch (_) {
      return null;
    }
  }

  void _showLeaveGroupDialog(
      BuildContext context, Map<String, dynamic> group) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Group',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kTextDark)),
        content: Text(
            'Are you sure you want to leave "${group['name']}"? You won\'t be able to see new messages.',
            style: const TextStyle(fontSize: 14, color: kTextMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: kTextMid,
                      fontWeight: FontWeight.w500))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Leave group functionality not implemented yet'),
                      behavior: SnackBarBehavior.floating));
            },
            child: Text('Leave',
                style: TextStyle(
                    color: Colors.red[600],
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── OPTION TILE ────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _OptionTile(
      {required this.icon,
        required this.title,
        required this.onTap,
        this.textColor});

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? kTextDark;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: textColor != null
              ? Colors.red.withOpacity(0.08)
              : kPrimaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(title,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      onTap: onTap,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      dense: true,
    );
  }
}