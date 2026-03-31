import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/campaign_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FIX: Same search bug as CampaignMembersScreen — converted to StatefulWidget
// ─────────────────────────────────────────────────────────────────────────────
class UnpaidCommunityMembersScreen extends StatefulWidget {
  final String communityId;
  final String campaignId;

  const UnpaidCommunityMembersScreen({
    super.key,
    required this.communityId,
    required this.campaignId,
  });

  @override
  State<UnpaidCommunityMembersScreen> createState() =>
      _UnpaidCommunityMembersScreenState();
}

class _UnpaidCommunityMembersScreenState
    extends State<UnpaidCommunityMembersScreen>
    with SingleTickerProviderStateMixin {
  late Future<void> _membersFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    final provider = Provider.of<CampaignProvider>(context, listen: false);
    _membersFuture = provider.fetchUnpaidCommunityMembers(
        widget.communityId, widget.campaignId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Color(0xFF1A1A2E), size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Unpaid Members',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: FutureBuilder<void>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading();
          }

          final provider = Provider.of<CampaignProvider>(context);

          if (snapshot.hasError || provider.unpaidMembersError != null) {
            return _buildError(provider);
          }

          final members =
              provider.unpaidMembers['data'] as List<dynamic>? ?? [];

          if (!_animController.isCompleted) _animController.forward();

          // FIX: proper setState-based search
          final filtered = _searchQuery.isEmpty
              ? members
              : members.where((m) {
            final name =
            (m['userId']?['profile']?['name'] ?? '')
                .toString()
                .toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          return FadeTransition(
            opacity: _fadeAnim,
            child: RefreshIndicator(
              onRefresh: () async {
                final p = Provider.of<CampaignProvider>(context, listen: false);
                await p.fetchUnpaidCommunityMembers(
                    widget.communityId, widget.campaignId);
                setState(() {});
              },
              color: Primary,
              child: members.isEmpty
                  ? _buildAllPaid()
                  : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildSearchBar(),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildHeaderBar(filtered.length),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildNoResults()
                        : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildMemberCard(filtered[index]),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search unpaid members...',
          hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF9CA3AF), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF9CA3AF), size: 18),
            onPressed: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
            }),
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_off_outlined,
                color: Color(0xFFE53935), size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            '$count Unpaid ${count == 1 ? 'Member' : 'Members'}',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(dynamic member) {
    final userId = member['userId'] ?? {};
    final profile = userId['profile'] ?? {};
    final profileImage = profile['profileImage'] ?? '';
    final isFamilyHead = profile['isFamilyHead'] == true;
    final userRole = member['userRole'] ?? 'Member';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UnpaidMemberDetailsScreen(member: member),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFFFEEEE),
              backgroundImage: profileImage.isNotEmpty
                  ? (profileImage.startsWith('data:image')
                  ? MemoryImage(
                  Uri.parse(profileImage).data!.contentAsBytes())
                  : NetworkImage(profileImage))
              as ImageProvider
                  : null,
              child: profileImage.isEmpty
                  ? Text(
                (profile['name'] ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE53935)),
              )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile['name'] ?? 'Unknown User',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    children: [
                      _chip(userRole, Primary),
                      if (isFamilyHead)
                        _chip('Family Head', const Color(0xFFF59E0B)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Primary, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Loading members...',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError(CampaignProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFE53935)),
            ),
            const SizedBox(height: 20),
            Text(
              provider.unpaidMembersError ?? 'Failed to load members',
              style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _membersFuture = provider.fetchUnpaidCommunityMembers(
                      widget.communityId, widget.campaignId);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Try Again',
                  style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllPaid() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  size: 56, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 24),
            const Text('All Caught Up!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            const Text('Every member has paid for this campaign.',
                style: TextStyle(
                    fontSize: 15, color: Color(0xFF6B7280), height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 48, color: Primary),
            ),
            const SizedBox(height: 20),
            const Text('No members found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            const Text('Try a different name',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unpaid Member Details Screen
// ─────────────────────────────────────────────────────────────────────────────
class UnpaidMemberDetailsScreen extends StatelessWidget {
  final dynamic member;
  const UnpaidMemberDetailsScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final userId = member['userId'] ?? {};
    final profile = userId['profile'] ?? {};
    final profileImage = profile['profileImage'] ?? '';
    final isFamilyHead = profile['isFamilyHead'] == true;
    final userRole = member['userRole'] ?? 'Member';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Color(0xFF1A1A2E), size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Member Details',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
                letterSpacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Profile card ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFFFFEEEE),
                    backgroundImage: profileImage.isNotEmpty
                        ? (profileImage.startsWith('data:image')
                        ? MemoryImage(Uri.parse(profileImage)
                        .data!
                        .contentAsBytes())
                        : NetworkImage(profileImage))
                    as ImageProvider
                        : null,
                    child: profileImage.isEmpty
                        ? Text(
                      (profile['name'] ?? 'U')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE53935)),
                    )
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profile['name'] ?? 'Unknown User',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: -0.3),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _badge(userRole, Primary),
                      if (isFamilyHead)
                        _badge('Family Head', const Color(0xFFF59E0B)),
                      _badge('Unpaid', const Color(0xFFE53935)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Contact card ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact Information',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 16),
                  _row(Icons.email_outlined, 'Email',
                      userId['email'] ?? 'Not provided'),
                  _row(Icons.phone_outlined, 'Phone',
                      userId['mobile'] ?? 'Not provided'),
                  _row(Icons.location_on_outlined, 'Location',
                      profile['location'] ?? 'Not provided'),
                  _row(Icons.home_outlined, 'Address',
                      profile['address'] ?? 'Not provided'),
                  _row(Icons.cake_outlined, 'Birthday',
                      _formatDate(profile['birthdate'])),
                  _row(Icons.calendar_today_outlined, 'Member Since',
                      _formatDate(userId['createdAt']),
                      showDivider: false),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _row(IconData icon, String label, String value,
      {bool showDivider = true}) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF3F4F6), height: 1),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  String _formatDate(String? v) {
    if (v == null) return 'Not provided';
    try {
      final d = DateTime.parse(v);
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${d.day} ${m[d.month - 1]}, ${d.year}';
    } catch (_) {
      return 'Not provided';
    }
  }
}