import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/comment_provider.dart';
import '../../providers/coupon_provider.dart';
import '../../providers/communities_provider.dart';

class SendCouponScreen extends StatefulWidget {
  final Map<String, dynamic> coupon;

  const SendCouponScreen({Key? key, required this.coupon}) : super(key: key);

  @override
  State<SendCouponScreen> createState() => _SendCouponScreenState();
}

class _SendCouponScreenState extends State<SendCouponScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String? _selectedUserId;
  String? _selectedCommunityId;
  String? _selectedCommunityName;
  final _searchCtrl = TextEditingController();
  final _communitySearchCtrl = TextEditingController();
  String _searchQuery = '';
  String _communitySearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ← replace fetchUserList with this
      context.read<CommentProvider>().fetchAllUsers(pageNo: 1);
      context.read<CommunityProvider>().fetchMyCommunities();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    _communitySearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send Coupon',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              widget.coupon['name'] ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Coupon code badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Primary.withOpacity(0.2)),
            ),
            child: Text(
              widget.coupon['code'] ?? '',
              style: TextStyle(
                color: Primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[500],
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w400, fontSize: 13),
                indicator: BoxDecoration(
                  color: Primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_rounded, size: 14),
                        SizedBox(width: 6),
                        Text('User'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups_rounded, size: 14),
                        SizedBox(width: 6),
                        Text('Community'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildUserTab(), _buildCommunityTab()],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // USER TAB
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildUserTab() {
    return Consumer<CommentProvider>(builder: (context, provider, _) {
      if (provider.isLoadingUsers && provider.allUsers.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Primary, strokeWidth: 2),
              const SizedBox(height: 12),
              Text('Loading users...',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                setState(() => _searchQuery = v);
                // ← search via API
                context.read<CommentProvider>().fetchAllUsers(
                  search: v.isEmpty ? null : v,
                  pageNo: 1,
                );
              },
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon:
                Icon(Icons.search_rounded, color: Colors.grey[400], size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                    context
                        .read<CommentProvider>()
                        .fetchAllUsers(pageNo: 1);
                  },
                  child: Icon(Icons.close_rounded,
                      color: Colors.grey[400], size: 16),
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Primary, width: 1.5),
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          // Selected banner
          if (_selectedUserId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '1 user selected',
                      style: TextStyle(
                          color: Primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // User list
          Expanded(
            child: provider.allUsers.isEmpty
                ? Center(
              child: Text('No users found',
                  style:
                  TextStyle(color: Colors.grey[400], fontSize: 13)),
            )
                : NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                // ← pagination on scroll
                if (scroll.metrics.pixels >=
                    scroll.metrics.maxScrollExtent - 200 &&
                    !provider.isLoadingUsers &&
                    provider.currentUserPage < provider.totalUserPages) {
                  context.read<CommentProvider>().fetchAllUsers(
                    search: _searchQuery.isEmpty
                        ? null
                        : _searchQuery,
                    pageNo: provider.currentUserPage + 1,
                    isLoadMore: true,
                  );
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: provider.allUsers.length +
                    (provider.isLoadingUsers ? 1 : 0),
                itemBuilder: (_, i) {
                  // Loading indicator at bottom
                  if (i == provider.allUsers.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: Primary, strokeWidth: 2),
                      ),
                    );
                  }

                  final user = provider.allUsers[i];
                  final uid = user['_id']?.toString() ?? '';
                  final isSelected = _selectedUserId == uid;
                  final name = _getUserName(user);
                  final email = _getUserEmail(user);
                  final image =
                      user['profile']?['profileImage']?.toString() ?? '';

                  return GestureDetector(
                    onTap: () => setState(() => _selectedUserId = uid),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Primary.withOpacity(0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Primary.withOpacity(0.4)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(
                              image, name.substring(0, 1), isSelected),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    )),
                                if (email.isNotEmpty)
                                  Text(email,
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11)),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: Primary, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 12),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Send button
          _bottomSendButton(
            label: 'Send to User',
            enabled: _selectedUserId != null,
            onTap: _sendToUser,
          ),
        ],
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMMUNITY TAB
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCommunityTab() {
    return Consumer<CommunityProvider>(builder: (context, provider, _) {
      // Flatten all communities including subCommunities
      final allCommunities = _flattenCommunities(
          provider.myCommunities['data'] as List<dynamic>? ?? []);

      if (provider.isLoadingMy) {
        return Center(
          child: CircularProgressIndicator(color: Primary, strokeWidth: 2),
        );
      }

      if (allCommunities.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_rounded, color: Colors.grey[300], size: 48),
              const SizedBox(height: 12),
              Text('No communities found',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ],
          ),
        );
      }

      // Filter by search
      final filtered = allCommunities.where((c) {
        final name = c['name']?.toString().toLowerCase() ?? '';
        return name.contains(_communitySearchQuery.toLowerCase());
      }).toList();

      return Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _communitySearchCtrl,
              onChanged: (v) => setState(() => _communitySearchQuery = v),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search communities...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.grey[400], size: 18),
                suffixIcon: _communitySearchQuery.isNotEmpty
                    ? GestureDetector(
                  onTap: () {
                    _communitySearchCtrl.clear();
                    setState(() => _communitySearchQuery = '');
                  },
                  child: Icon(Icons.close_rounded,
                      color: Colors.grey[400], size: 16),
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Primary, width: 1.5),
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          // Selected banner
          if (_selectedCommunityId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selected: $_selectedCommunityName',
                        style: TextStyle(
                            color: Primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Community list
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Text('No communities found',
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 13)),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final community = filtered[i];
                final cid = community['_id']?.toString() ?? '';
                final isSelected = _selectedCommunityId == cid;
                final name =
                    community['name']?.toString() ?? 'Unknown';
                final image =
                    community['profileImage']?.toString() ?? '';
                final memberCount =
                    community['userCount'] ?? community['memberCount'] ?? 0;
                final isSubCommunity =
                    community['_isSubCommunity'] == true;

                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCommunityId = cid;
                    _selectedCommunityName = name;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Primary.withOpacity(0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Primary.withOpacity(0.4)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Indent subcommunities
                        if (isSubCommunity)
                          const SizedBox(width: 16),
                        _buildAvatar(
                            image, name.substring(0, 1), isSelected),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isSubCommunity)
                                    Container(
                                      margin: const EdgeInsets.only(
                                          right: 6),
                                      padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius:
                                        BorderRadius.circular(4),
                                      ),
                                      child: Text('Sub',
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 9,
                                              fontWeight:
                                              FontWeight.w600)),
                                    ),
                                  Expanded(
                                    child: Text(name,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        )),
                                  ),
                                ],
                              ),
                              Text('$memberCount members',
                                  style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                                color: Primary, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 12),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Send button
          _bottomSendButton(
            label: 'Send to Community',
            enabled: _selectedCommunityId != null,
            onTap: _sendToCommunity,
          ),
        ],
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BOTTOM SEND BUTTON (fixed at bottom)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _bottomSendButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Consumer<CouponProvider>(builder: (_, provider, __) {
      final loading = provider.isSending;
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (!loading && enabled) ? onTap : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[200],
              disabledForegroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
                : Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Flatten community tree including subCommunities
  List<Map<String, dynamic>> _flattenCommunities(List<dynamic> communities) {
    final result = <Map<String, dynamic>>[];
    for (final c in communities) {
      final community = Map<String, dynamic>.from(c as Map);
      community['_isSubCommunity'] = false;
      result.add(community);

      final subs = community['subCommunities'] as List<dynamic>? ?? [];
      for (final sub in subs) {
        final subMap = Map<String, dynamic>.from(sub as Map);
        subMap['_isSubCommunity'] = true;
        result.add(subMap);
      }
    }
    return result;
  }

  String _getUserName(Map<String, dynamic> user) {
    return user['profile']?['name']?.toString() ??
        user['username']?.toString() ??
        user['name']?.toString() ??
        'Unknown';
  }

  String _getUserEmail(Map<String, dynamic> user) {
    return user['email']?.toString() ??
        user['profile']?['email']?.toString() ??
        '';
  }

  void _sendToUser() async {
    if (_selectedUserId == null) return;
    final provider = context.read<CouponProvider>();
    final success = await provider.sendCouponToUser(
      couponId: widget.coupon['_id'],
      receiverId: _selectedUserId!,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Coupon sent successfully! 🎉'
            : (provider.sendErrorMessage ?? 'Failed to send')),
        backgroundColor: success ? Primary : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  void _sendToCommunity() async {
    if (_selectedCommunityId == null) return;
    final provider = context.read<CouponProvider>();

    final success = await provider.sendCouponToGroup(
      couponId: widget.coupon['_id'],
      groupId: _selectedCommunityId!, // this is actually communityId
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Coupon sent to $_selectedCommunityName! 🎉'
            : (provider.sendErrorMessage ?? 'Failed to send')),
        backgroundColor: success ? Primary : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  Widget _buildAvatar(String imageUrl, String fallbackLetter, bool isSelected) {
    final isBase64 = imageUrl.startsWith('data:');
    final isValid = imageUrl.isNotEmpty && !isBase64;

    return CircleAvatar(
      radius: 20,
      backgroundColor:
      isSelected ? Primary.withOpacity(0.15) : Colors.grey.shade100,
      backgroundImage: isValid ? NetworkImage(imageUrl) : null,
      child: !isValid
          ? Text(
        fallbackLetter.toUpperCase(),
        style: TextStyle(
          color: isSelected ? Primary : Colors.grey[600],
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      )
          : null,
    );
  }
}