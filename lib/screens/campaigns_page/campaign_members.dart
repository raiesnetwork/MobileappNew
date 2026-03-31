import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/campaign_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FIX BUG 6: Convert to StatefulWidget so search works properly.
// markNeedsBuild() is an anti-pattern — replaced with setState.
// ─────────────────────────────────────────────────────────────────────────────
class CampaignMembersScreen extends StatefulWidget {
  final String campaignId;
  const CampaignMembersScreen({super.key, required this.campaignId});

  @override
  State<CampaignMembersScreen> createState() => _CampaignMembersScreenState();
}

class _CampaignMembersScreenState extends State<CampaignMembersScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _membersFuture;
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
    _membersFuture = provider.getCampaignMembers(widget.campaignId);
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
          'Campaign Members',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading();
          }
          if (snapshot.hasError || snapshot.data?['error'] == true) {
            return _buildError(snapshot.data?['message']);
          }

          final data =
              snapshot.data?['data'] as Map<String, dynamic>? ?? {};
          final members = data['members'] as List<dynamic>? ?? [];
          final isCampaignPaid = data['isCampaignPaid'] as bool? ?? false;

          if (!_animController.isCompleted) _animController.forward();

          // FIX BUG 6: use _searchQuery state variable, not controller.text
          final filteredMembers = _searchQuery.isEmpty
              ? members
              : members.where((m) {
            final name = (m['userId']?['profile']?['name'] ?? '')
                .toString()
                .toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          return FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // ── Search bar ─────────────────────────────────
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildSearchBar(),
                ),

                // ── Header chip ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildHeaderBar(
                      filteredMembers.length, isCampaignPaid),
                ),
                const SizedBox(height: 12),

                // ── Members list ───────────────────────────────
                Expanded(
                  child: filteredMembers.isEmpty
                      ? _buildEmpty(_searchQuery.isNotEmpty)
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: filteredMembers.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildMemberCard(
                          filteredMembers[index], isCampaignPaid);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
        // FIX BUG 6: proper setState-based search, no markNeedsBuild
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search members...',
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

  Widget _buildHeaderBar(int count, bool isCampaignPaid) {
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
              color: Primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people_rounded, color: Primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            '$count ${count == 1 ? 'Member' : 'Members'}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const Spacer(),
          if (isCampaignPaid)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle_rounded,
                      size: 13, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text('Paid Campaign',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(dynamic member, bool isCampaignPaid) {
    final profile = member['userId']?['profile'] ?? {};
    final profileImage = profile['profileImage'] ?? '';
    final isAdmin = member['isAdmin'] == true;
    final paymentStatus =
        member['paymentStatus'] as Map<String, dynamic>? ?? {};
    final isPaid = paymentStatus['status'] == 'PAID';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CampaignMemberDetailsScreen(
            member: member,
            isCampaignPaid: isCampaignPaid,
          ),
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
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Primary.withOpacity(0.1),
                  backgroundImage: profileImage.isNotEmpty
                      ? (profileImage.startsWith('data:image')
                      ? MemoryImage(
                      Uri.parse(profileImage).data!.contentAsBytes())
                      : NetworkImage(profileImage))
                  as ImageProvider
                      : null,
                  child: profileImage.isEmpty
                      ? Text(
                    (profile['name'] ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Primary),
                  )
                      : null,
                ),
                if (isPaid && isCampaignPaid)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Content
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _roleBadge(
                          isAdmin ? 'Admin' : (member['userRole'] ?? 'Member'),
                          isAdmin ? Primary : const Color(0xFF9CA3AF)),
                      if (isCampaignPaid) ...[
                        const SizedBox(width: 6),
                        _roleBadge(
                          isPaid ? 'Paid' : 'Unpaid',
                          isPaid
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE53935),
                        ),
                      ],
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

  Widget _roleBadge(String label, Color color) {
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

  Widget _buildError(String? message) {
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
            Text(message ?? 'Failed to load members',
                style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isSearch) {
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
              child: Icon(
                isSearch ? Icons.search_off_rounded : Icons.people_outline,
                size: 48,
                color: Primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearch ? 'No members found' : 'No members yet',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Try a different search term'
                  : 'Members will appear here once they join',
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member Details Screen
// ─────────────────────────────────────────────────────────────────────────────
class CampaignMemberDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool isCampaignPaid;

  const CampaignMemberDetailsScreen({
    super.key,
    required this.member,
    required this.isCampaignPaid,
  });

  @override
  Widget build(BuildContext context) {
    final paymentStatus =
        member['paymentStatus'] as Map<String, dynamic>? ?? {};
    final profile = member['userId']?['profile'] ?? {};
    final profileImage = profile['profileImage'] ?? '';
    final isAdmin = member['isAdmin'] == true;
    final isPaid = paymentStatus['status'] == 'PAID';

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
            // ── Profile card ────────────────────────────────────
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
                    backgroundColor: Primary.withOpacity(0.1),
                    backgroundImage: profileImage.isNotEmpty
                        ? (profileImage.startsWith('data:image')
                        ? MemoryImage(
                        Uri.parse(profileImage).data!.contentAsBytes())
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
                          color: Primary),
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
                      _badge(
                          isAdmin ? 'Administrator' : (member['userRole'] ?? 'Member'),
                          isAdmin ? Primary : const Color(0xFF6B7280)),
                      if (isCampaignPaid)
                        _badge(isPaid ? 'Paid' : 'Unpaid',
                            isPaid
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE53935)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Contact card ────────────────────────────────────
            _infoCard(
              title: 'Contact Information',
              children: [
                _infoRow(Icons.email_outlined, 'Email',
                    member['userId']?['email'] ?? 'Not provided'),
                _infoRow(Icons.phone_outlined, 'Phone',
                    member['userId']?['mobile'] ?? 'Not provided'),
                _infoRow(Icons.location_on_outlined, 'Location',
                    profile['location'] ?? 'Not provided'),
                _infoRow(Icons.home_outlined, 'Address',
                    profile['address'] ?? 'Not provided'),
                _infoRow(Icons.cake_outlined, 'Birthday',
                    _formatDate(profile['birthdate']),
                    showDivider: false),
              ],
            ),

            // ── Payment card ────────────────────────────────────
            if (isCampaignPaid) ...[
              const SizedBox(height: 14),
              _infoCard(
                title: 'Payment Status',
                titleTrailing: _badge(
                  paymentStatus['status'] ?? 'Unknown',
                  _paymentColor(paymentStatus['status']),
                ),
                children: isPaid
                    ? [
                  _infoRow(
                      Icons.monetization_on_outlined,
                      'Amount Paid',
                      '${paymentStatus['amountPaid'] ?? 0}'),
                  _infoRow(
                      Icons.credit_card_outlined,
                      'Payment Type',
                      paymentStatus['paymentType'] ?? 'N/A',
                      showDivider: false),
                ]
                    : [
                  _infoRow(Icons.pending_outlined, 'Status',
                      'Payment not yet received',
                      showDivider: false),
                ],
              ),
            ],
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

  Widget _infoCard({
    required String title,
    Widget? titleTrailing,
    required List<Widget> children,
  }) {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E))),
              if (titleTrailing != null) titleTrailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
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

  Color _paymentColor(String? status) {
    switch (status) {
      case 'PAID':
        return const Color(0xFF10B981);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'FAILED':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _formatDate(String? v) {
    if (v == null) return 'Not provided';
    try {
      final d = DateTime.parse(v);
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${d.day} ${months[d.month - 1]}, ${d.year}';
    } catch (_) {
      return 'Not provided';
    }
  }
}