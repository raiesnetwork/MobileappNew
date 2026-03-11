import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/group_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GroupMemberManagementScreen  (fixed)
//
// Fixes:
//   • Uses a local mutable _liveMembers list so Add/Remove reflects
//     immediately without re-navigating
//   • _existingMemberIds is derived from _liveMembers, so "Member" badge
//     and duplicate-add guard always reflect the current truth
//   • Remove fetches the real member list from provider on init so the
//     "Current" tab shows up-to-date data
//   • Remove option wired into GroupChatDetail popup menu (see companion fix)
// ═══════════════════════════════════════════════════════════════════════════
class GroupMemberManagementScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  /// currentMembers can be:
  ///   - List<String>  (just IDs)
  ///   - List<Map>     (full user objects with _id, profile, etc.)
  ///   - mixed
  final List<dynamic> currentMembers;

  /// 0 = Add Members tab (default for admins), 1 = Current Members tab
  final int initialTabIndex;

  const GroupMemberManagementScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.currentMembers,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<GroupMemberManagementScreen> createState() =>
      _GroupMemberManagementScreenState();
}

class _GroupMemberManagementScreenState
    extends State<GroupMemberManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Add Members tab ──────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _usersScrollController = ScrollController();
  Timer? _debounce;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  List<dynamic> _loadedUsers = [];
  int _totalPages = 1;
  String _searchQuery = '';
  final Set<String> _addingIds = {};

  // ── Remove Members tab ───────────────────────────────────────────────────
  final Set<String> _removingIds = {};

  // ── LIVE member list — mutable, source of truth for both tabs ────────────
  late List<dynamic> _liveMembers;

  // Derived from _liveMembers; always up-to-date
  Set<String> get _existingMemberIds =>
      _liveMembers.map(_extractId).where((id) => id.isNotEmpty).toSet();

  // ════════════════════════════════════════════════════════════════════════
  //  SAFE MEMBER FIELD EXTRACTORS
  // ════════════════════════════════════════════════════════════════════════
  String _extractId(dynamic member) {
    if (member == null) return '';
    if (member is String) return member;
    if (member is Map) {
      final v = member['_id'] ??
          member['userId'] ??
          member['id'] ??
          (member['user'] is Map ? member['user']['_id'] : null) ??
          '';
      return v.toString();
    }
    return '';
  }

  String _extractName(dynamic member) {
    if (member is Map) {
      final profile = member['profile'];
      if (profile is Map) {
        final n = profile['name']?.toString() ?? '';
        if (n.isNotEmpty) return n;
      }
      return (member['name'] ?? member['mobile'] ?? member['username'] ?? '')
          .toString();
    }
    return '';
  }

  String _extractMobile(dynamic member) {
    if (member is Map) {
      return (member['mobile'] ??
          (member['profile'] is Map ? member['profile']['mobile'] : null) ??
          '')
          .toString();
    }
    return '';
  }

  String? _extractAvatar(dynamic member) {
    if (member is Map) {
      final profile = member['profile'];
      if (profile is Map) {
        final img = profile['profileImage']?.toString();
        if (img != null && img.isNotEmpty && img != 'null') return img;
      }
    }
    return null;
  }

  bool _isAdmin(dynamic member) {
    if (member is Map) {
      return member['isAdmin'] == true || member['role'] == 'admin';
    }
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);

    // Seed live members from whatever was passed in
    _liveMembers = List<dynamic>.from(widget.currentMembers);

    _usersScrollController.addListener(_onUsersScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers(reset: true);
      _refreshMembersFromServer(); // fetch fresh member list immediately
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _usersScrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  FETCH FRESH MEMBER LIST FROM SERVER
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _refreshMembersFromServer() async {
    final provider = context.read<GroupChatProvider>();
    // Re-use getGroupById / getMyGroupById which already have up-to-date data.
    // If you have a dedicated "fetch group members" API, call it here instead.
    final group = provider.getGroupById(widget.groupId) ??
        provider.getMyGroupById(widget.groupId);
    final fresh = (group?['members'] as List<dynamic>?) ?? [];
    if (fresh.isNotEmpty && mounted) {
      setState(() => _liveMembers = List<dynamic>.from(fresh));
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DATA LOADING
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _loadUsers({bool reset = false}) async {
    if (_isLoadingMore && !reset) return;

    final provider = context.read<GroupChatProvider>();

    if (reset) {
      setState(() {
        _currentPage = 1;
        _loadedUsers = [];
        _totalPages = 1;
        _isLoadingMore = true;
      });
    } else {
      if (_currentPage >= _totalPages) return;
      setState(() => _isLoadingMore = true);
      _currentPage++;
    }

    await provider.fetchAllUsers(
      page: _currentPage,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );

    if (mounted) {
      final newUsers = List<dynamic>.from(provider.allUsers);
      setState(() {
        if (reset) {
          _loadedUsers = newUsers;
        } else {
          final existingIds =
          _loadedUsers.map((u) => u['_id']?.toString() ?? '').toSet();
          for (final u in newUsers) {
            final uid = u['_id']?.toString() ?? '';
            if (!existingIds.contains(uid)) _loadedUsers.add(u);
          }
        }
        _totalPages = provider.allUsersTotalPages;
        _isLoadingMore = false;
      });
    }
  }

  void _onUsersScroll() {
    if (_usersScrollController.position.pixels >=
        _usersScrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _totalPages) _loadUsers();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      setState(() => _searchQuery = query);
      _loadUsers(reset: true);
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ACTIONS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _addMember(
      String userId, String userName, Map<String, dynamic> userObj) async {
    // Guard: prevent duplicate add if already a member
    if (_existingMemberIds.contains(userId)) {
      _showToast('$userName is already a member', Colors.orange[700]!);
      return;
    }
    if (_addingIds.contains(userId)) return;

    setState(() => _addingIds.add(userId));

    final provider = context.read<GroupChatProvider>();
    await provider.addMembersToGroup(
      groupId: widget.groupId,
      memberIds: [userId],
    );

    if (mounted) {
      final msg = provider.addMemberMessage;
      final success = msg.isNotEmpty &&
          !msg.toLowerCase().contains('error') &&
          !msg.toLowerCase().contains('fail');

      setState(() {
        _addingIds.remove(userId);
        if (success) {
          // Add to live members so both tabs update immediately
          _liveMembers.add(userObj);
        }
      });

      _showToast(
        success
            ? '✓ ${userName.isNotEmpty ? userName : 'User'} added to group'
            : msg,
        success ? const Color(0xFF00C896) : Colors.red[400]!,
      );
    }
  }

  Future<void> _removeMember(String userId, String userName) async {
    final displayName = userName.isNotEmpty ? userName : 'this member';
    final confirmed = await _showConfirmDialog(
      'Remove Member',
      'Remove $displayName from ${widget.groupName}?',
    );
    if (!confirmed) return;

    setState(() => _removingIds.add(userId));

    final provider = context.read<GroupChatProvider>();
    final ok = await provider.removeMemberFromGroup(
      groupId: widget.groupId,
      userId: userId,
    );

    if (mounted) {
      setState(() {
        _removingIds.remove(userId);
        if (ok) {
          // Remove from live members so both tabs update immediately
          _liveMembers.removeWhere((m) => _extractId(m) == userId);
        }
      });
      _showToast(
        ok ? '✓ $displayName removed' : provider.removeMessage,
        ok ? const Color(0xFF00C896) : Colors.red[400]!,
      );
    }
  }

  Future<bool> _showConfirmDialog(String title, String body) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
            Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAddMembersTab(),
                _buildCurrentMembersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1D2E),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage Members',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D2E))),
          Text(widget.groupName,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6C5CE7),
                  fontWeight: FontWeight.w500)),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFEEEFF4)),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF6C5CE7),
        unselectedLabelColor: const Color(0xFF9DA3B4),
        labelStyle:
        const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        indicator: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFF6C5CE7), width: 2.5)),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        tabs: [
          const Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_rounded, size: 16),
              SizedBox(width: 6),
              Text('Add Members'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.group_rounded, size: 16),
              const SizedBox(width: 6),
              const Text('Current'),
              const SizedBox(width: 4),
              // Badge count is now always live
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_existingMemberIds.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6C5CE7)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── ADD MEMBERS TAB ───────────────────────────────────────────────────────
  Widget _buildAddMembersTab() {
    return Column(children: [
      _buildSearchBar(),
      Expanded(child: _buildUsersList()),
    ]);
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1A1D2E),
            fontWeight: FontWeight.w400),
        decoration: InputDecoration(
          hintText: 'Search users by name or number...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF6C5CE7), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close_rounded,
                color: Colors.grey[400], size: 18),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          )
              : null,
          filled: true,
          fillColor: const Color(0xFFF7F8FC),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: Color(0xFFEEEFF4), width: 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: Color(0xFF6C5CE7), width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoadingMore && _loadedUsers.isEmpty) {
      return _buildLoadingState('Loading users...');
    }
    if (_loadedUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: _searchQuery.isEmpty ? 'No users found' : 'No results',
        subtitle: _searchQuery.isEmpty
            ? 'There are no users to add'
            : 'Try a different search term',
      );
    }

    return ListView.builder(
      controller: _usersScrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _loadedUsers.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _loadedUsers.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                ),
              ),
            ),
          );
        }

        final user = _loadedUsers[i];
        final userId = user['_id']?.toString() ?? '';
        final name = (user['profile']?['name']?.toString() ??
            user['mobile']?.toString() ??
            'Unknown')
            .trim();
        final mobile = user['mobile']?.toString() ?? '';
        final avatar = user['profile']?['profileImage']?.toString();

        // Always check live set — prevents duplicate adds
        final alreadyMember = _existingMemberIds.contains(userId);
        final isAdding = _addingIds.contains(userId);

        // Build a minimal Map for the live list when adding
        final userObj = <String, dynamic>{
          '_id': userId,
          'mobile': mobile,
          'profile': {'name': name, 'profileImage': avatar},
        };

        return _buildAddUserTile(
          userId: userId,
          name: name,
          subtitle: mobile,
          avatar: avatar,
          alreadyMember: alreadyMember,
          isAdding: isAdding,
          onAdd: (alreadyMember || isAdding)
              ? null
              : () => _addMember(userId, name, userObj),
        );
      },
    );
  }

  Widget _buildAddUserTile({
    required String userId,
    required String name,
    required String subtitle,
    String? avatar,
    required bool alreadyMember,
    required bool isAdding,
    VoidCallback? onAdd,
  }) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alreadyMember
              ? const Color(0xFF00C896).withOpacity(0.3)
              : const Color(0xFFEEEFF4),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: _buildAvatar(initials, avatar, size: 42),
        title: Text(name,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: alreadyMember
                    ? const Color(0xFF9DA3B4)
                    : const Color(0xFF1A1D2E))),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle,
            style:
            const TextStyle(fontSize: 12, color: Color(0xFF9DA3B4)))
            : null,
        trailing: alreadyMember
            ? Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF00C896).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 14, color: Color(0xFF00C896)),
                SizedBox(width: 4),
                Text('Member',
                    style: TextStyle(
                        color: Color(0xFF00C896),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
        )
            : isAdding
            ? const SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                      Color(0xFF6C5CE7))),
            ),
          ),
        )
            : GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B7CF6), Color(0xFF6C5CE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF6C5CE7).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: const Icon(Icons.add_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  // ── CURRENT MEMBERS TAB ───────────────────────────────────────────────────
  Widget _buildCurrentMembersTab() {
    // Always read from _liveMembers — mutable & up-to-date
    final members =
    _liveMembers.where((m) => _extractId(m).isNotEmpty).toList();

    if (members.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group_off_rounded,
        title: 'No members yet',
        subtitle: 'Add members using the Add Members tab',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final member = members[i];
        final userId = _extractId(member);
        final name = _extractName(member);
        final mobile = _extractMobile(member);
        final avatar = _extractAvatar(member);
        final adminMember = _isAdmin(member);
        final isRemoving = _removingIds.contains(userId);
        final displayName = name.isNotEmpty ? name : mobile;
        final initials =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEEEFF4)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Stack(children: [
              _buildAvatar(initials, avatar, size: 42),
              if (adminMember)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB347),
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.star_rounded,
                        size: 9, color: Colors.white),
                  ),
                ),
            ]),
            title: Text(
              displayName.isNotEmpty ? displayName : 'Member',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF1A1D2E)),
            ),
            subtitle: Row(children: [
              if (adminMember)
                Container(
                  margin: const EdgeInsets.only(right: 6, top: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Admin',
                      style: TextStyle(
                          color: Color(0xFFE08500),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              if (mobile.isNotEmpty && mobile != displayName)
                Text(mobile,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9DA3B4))),
            ]),
            trailing: adminMember
                ? Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Admin',
                  style: TextStyle(
                      color: Color(0xFFE08500),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            )
                : isRemoving
                ? const SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation(Colors.red)),
                ),
              ),
            )
                : GestureDetector(
              onTap: () => _removeMember(userId, displayName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.red[200]!, width: 1),
                ),
                child: Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.red[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── SHARED HELPERS ────────────────────────────────────────────────────────
  Widget _buildAvatar(String initials, String? imageUrl, {double size = 40}) {
    final hasImg =
        imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: !hasImg
            ? const LinearGradient(
            colors: [Color(0xFF9B8FF5), Color(0xFF6C5CE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
            : null,
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.transparent,
        backgroundImage: hasImg ? NetworkImage(imageUrl!) : null,
        child: !hasImg
            ? Text(initials,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.38))
            : null,
      ),
    );
  }

  Widget _buildLoadingState(String label) {
    return Center(
      child:
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Color(0xFF6C5CE7))),
        ),
        const SizedBox(height: 16),
        Text(label,
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.08),
                    shape: BoxShape.circle),
                child:
                Icon(icon, size: 36, color: const Color(0xFF6C5CE7)),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D2E))),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9DA3B4)),
                  textAlign: TextAlign.center),
            ]),
      ),
    );
  }
}