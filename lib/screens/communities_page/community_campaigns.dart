import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/communities_provider.dart';
import '../campaigns_page/campaign_members.dart';
import '../campaigns_page/create_campaign_screen.dart';
import '../campaigns_page/un_paid_community_campaigns_members_screen.dart';

class CommunityCampaignsScreen extends StatefulWidget {
  final String communityId;
  const CommunityCampaignsScreen({super.key, required this.communityId});

  @override
  _CommunityCampaignsScreenState createState() =>
      _CommunityCampaignsScreenState();
}

class _CommunityCampaignsScreenState extends State<CommunityCampaignsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _headerAnim;
  late AnimationController _listAnim;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  // Design tokens
  static const _bg = Color(0xFF0D0F14);
  static const _surface = Color(0xFF161920);
  static const _surfaceHigh = Color(0xFF1E2129);
  static const _border = Color(0xFF2A2D38);
  static const _accent = Color(0xFF6C63FF);
  static const _accentGlow = Color(0x336C63FF);
  static const _gold = Color(0xFFFFB547);
  static const _green = Color(0xFF00D9A3);
  static const _red = Color(0xFFFF4D6D);
  static const _textPrimary = Color(0xFFF0F2FF);
  static const _textSecondary = Color(0xFF8B8FA8);
  static const _textMuted = Color(0xFF4A4D60);

  @override
  void initState() {
    super.initState();

    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _listAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _headerFade =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
        begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));

    _headerAnim.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CommunityProvider>(context, listen: false)
          .fetchCommunityCampaigns(widget.communityId)
          .then((_) => _listAnim.forward());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerAnim.dispose();
    _listAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Gradient spacer for AppBar
          const SizedBox(height: kToolbarHeight + 44),
          // Search field
          SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerFade,
              child: _buildSearchBar(),
            ),
          ),
          const SizedBox(height: 8),
          // Campaign list
          Expanded(
            child: Consumer<CommunityProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingCampaigns) return _buildSkeleton();
                if (provider.campaignsError != null)
                  return _buildError(provider);

                final campaigns =
                    provider.communityCampaigns['data'] as List<dynamic>? ??
                        [];
                final filtered = campaigns
                    .where((c) => c['title']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
                    .toList();

                if (filtered.isEmpty) return _buildEmpty();

                return RefreshIndicator(
                  onRefresh: () => provider
                      .fetchCommunityCampaigns(widget.communityId),
                  color: _accent,
                  backgroundColor: _surfaceHigh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _AnimatedCampaignCard(
                        campaign: filtered[index],
                        index: index,
                        communityId: widget.communityId,
                        listAnim: _listAnim,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: SlideTransition(
        position: _headerSlide,
        child: FadeTransition(
          opacity: _headerFade,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _textPrimary, size: 16),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campaigns',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Consumer<CommunityProvider>(
                  builder: (_, provider, __) {
                    final count = (provider.communityCampaigns['data']
                    as List?)
                        ?.length ??
                        0;
                    return Text(
                      '$count active',
                      style: const TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ],
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC0D0F14), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search campaigns...',
            hintStyle:
            const TextStyle(color: _textMuted, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: _textMuted, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: _textMuted, size: 16),
              onPressed: () =>
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
            )
                : null,
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: 4,
      itemBuilder: (_, i) => _SkeletonCard(index: i),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentGlow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.campaign_outlined,
                color: _accent, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('No Campaigns Yet',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3)),
          const SizedBox(height: 8),
          const Text('Create your first campaign below',
              style: TextStyle(color: _textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError(CommunityProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: _red, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Failed to load',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => provider
                .fetchCommunityCampaigns(widget.communityId),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _accent.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateCampaignScreen(
                  communityId: widget.communityId),
            ),
          );
        },
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Campaign',
            style:
            TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ─── Animated Campaign Card ───────────────────────────────────────────────────
class _AnimatedCampaignCard extends StatefulWidget {
  final dynamic campaign;
  final int index;
  final String communityId;
  final AnimationController listAnim;

  const _AnimatedCampaignCard({
    required this.campaign,
    required this.index,
    required this.communityId,
    required this.listAnim,
  });

  @override
  State<_AnimatedCampaignCard> createState() => _AnimatedCampaignCardState();
}

class _AnimatedCampaignCardState extends State<_AnimatedCampaignCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  static const _bg = Color(0xFF0D0F14);
  static const _surface = Color(0xFF161920);
  static const _surfaceHigh = Color(0xFF1E2129);
  static const _border = Color(0xFF2A2D38);
  static const _accent = Color(0xFF6C63FF);
  static const _accentGlow = Color(0x336C63FF);
  static const _gold = Color(0xFFFFB547);
  static const _green = Color(0xFF00D9A3);
  static const _red = Color(0xFFFF4D6D);
  static const _textPrimary = Color(0xFFF0F2FF);
  static const _textSecondary = Color(0xFF8B8FA8);
  static const _textMuted = Color(0xFF4A4D60);

  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;
    final isCompleted = campaign['isCompleted'] ?? false;
    final isUserPaid = campaign['isUserPaid'] is Map
        ? true
        : (campaign['isUserPaid'] == true);
    final totalMembers = campaign['totalMembers'] ?? 0;
    final paidUsers = campaign['paidUsers'] ?? 0;
    final progress = totalMembers > 0
        ? (paidUsers / totalMembers).clamp(0.0, 1.0)
        : 0.0;
    final hasCost = (campaign['amountPayablePerUser'] ?? 0) > 0;

    final delay = (widget.index * 80).clamp(0, 500);
    final startInterval = delay / 600;
    final endInterval = (startInterval + 0.5).clamp(0.0, 1.0);

    final anim = CurvedAnimation(
      parent: widget.listAnim,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
            offset: Offset(0, 24 * (1 - anim.value)), child: child),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          _showCampaignSheet(context, campaign);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCompleted
                    ? _green.withOpacity(0.3)
                    : _border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCompleted
                      ? _green.withOpacity(0.06)
                      : Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Card header ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _accentGlow,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.campaign_rounded,
                            color: _accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      // Title + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              campaign['title'] ?? 'Untitled',
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              campaign['community']?['name'] ??
                                  'Community',
                              style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      // Status pill
                      _StatusPill(
                          isCompleted: isCompleted,
                          isPaid: isUserPaid,
                          hasCost: hasCost),
                    ],
                  ),
                ),

                // ── Description ──────────────────────────────
                if ((campaign['description'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      campaign['description'],
                      style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                          height: 1.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // ── Progress bar (only if payment campaign) ──
                if (hasCost) ...[
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$paidUsers / $totalMembers paid',
                              style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                color: progress >= 1.0
                                    ? _green
                                    : _accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.toDouble(),
                            backgroundColor: _surfaceHigh,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? _green : _accent,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Divider ──────────────────────────────────
                Container(
                    height: 1,
                    color: _border.withOpacity(0.5)),

                // ── Footer actions ───────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Members count chip
                      _FooterChip(
                        icon: Icons.people_outline_rounded,
                        label: '$totalMembers members',
                        color: _textMuted,
                      ),
                      const Spacer(),
                      // View members button
                      _ActionBtn(
                        icon: Icons.group_add_outlined,
                        label: 'Unpaid',
                        color: _gold,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UnpaidCommunityMembersScreen(
                                    communityId: widget.communityId,
                                    campaignId: campaign['_id'],
                                  ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.people_rounded,
                        label: 'Members',
                        color: _accent,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CampaignMembersScreen(
                                campaignId: campaign['_id'],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCampaignSheet(
      BuildContext context, Map<String, dynamic> campaign) {
    final isCompleted = campaign['isCompleted'] ?? false;
    final isUserPaid = campaign['isUserPaid'] is Map
        ? true
        : (campaign['isUserPaid'] == true);
    final totalMembers = campaign['totalMembers'] ?? 0;
    final paidUsers = campaign['paidUsers'] ?? 0;
    final progress =
    (campaign['progress'] ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
                top: BorderSide(color: _border, width: 1)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              campaign['title'] ?? 'Untitled',
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _surfaceHigh,
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: _textSecondary, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Badges
                      Wrap(
                        spacing: 8,
                        children: [
                          _Badge(
                            label: isCompleted
                                ? 'Completed'
                                : 'Ongoing',
                            color: isCompleted ? _green : _gold,
                            icon: isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                          ),
                          _Badge(
                            label:
                            isUserPaid ? 'Paid' : 'Unpaid',
                            color: isUserPaid ? _green : _red,
                            icon: isUserPaid
                                ? Icons.verified_rounded
                                : Icons.pending_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Description
                      if ((campaign['description'] ?? '')
                          .isNotEmpty) ...[
                        const Text('Description',
                            style: TextStyle(
                                color: _textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        Text(
                          campaign['description'],
                          style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 14,
                              height: 1.6),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Stats grid
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surfaceHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _StatItem('Paid',
                                    '$paidUsers', _green),
                                _StatItem('Total',
                                    '$totalMembers', _accent),
                                _StatItem(
                                    'Remaining',
                                    '${totalMembers - paidUsers}',
                                    _gold),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius:
                              BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                backgroundColor: _border,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                  progress >= 100
                                      ? _green
                                      : _accent,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Progress',
                                    style: TextStyle(
                                        color: _textMuted,
                                        fontSize: 11)),
                                Text(
                                  '${progress.toInt()}%',
                                  style: TextStyle(
                                    color: progress >= 100
                                        ? _green
                                        : _accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: _SheetButton(
                              label: 'All Members',
                              icon: Icons.people_rounded,
                              color: _accent,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CampaignMembersScreen(
                                          campaignId: campaign['_id'],
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SheetButton(
                              label: 'Unpaid',
                              icon: Icons.schedule_rounded,
                              color: _gold,
                              outline: true,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        UnpaidCommunityMembersScreen(
                                          communityId:
                                          campaign['community']
                                          ?['_id'] ??
                                              '',
                                          campaignId: campaign['_id'],
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final bool isCompleted;
  final bool isPaid;
  final bool hasCost;

  static const _green = Color(0xFF00D9A3);
  static const _gold = Color(0xFFFFB547);
  static const _red = Color(0xFFFF4D6D);

  const _StatusPill(
      {required this.isCompleted,
        required this.isPaid,
        required this.hasCost});

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return _pill('Done', _green, Icons.check_circle_rounded);
    }
    if (hasCost && isPaid) {
      return _pill('Paid', _green, Icons.verified_rounded);
    }
    if (hasCost && !isPaid) {
      return _pill('Unpaid', _red, Icons.pending_rounded);
    }
    return _pill('Active', _gold, Icons.bolt_rounded);
  }

  Widget _pill(String label, Color color, IconData icon) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FooterChip(
      {required this.icon,
        required this.label,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon,
        required this.label,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge(
      {required this.label,
        required this.color,
        required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(this.label, this.value, this.color);

  static const _textPrimary = Color(0xFFF0F2FF);
  static const _textMuted = Color(0xFF4A4D60);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outline;

  const _SheetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: outline ? color : Colors.transparent,
              width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: outline ? color : Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: outline ? color : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton card ────────────────────────────────────────────────────────────
class _SkeletonCard extends StatefulWidget {
  final int index;
  const _SkeletonCard({required this.index});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  static const _surface = Color(0xFF161920);
  static const _surfaceHigh = Color(0xFF1E2129);
  static const _border = Color(0xFF2A2D38);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = Color.lerp(
            _surfaceHigh, const Color(0xFF252836), _anim.value)!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(13))),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 140,
                          height: 14,
                          decoration: BoxDecoration(
                              color: c,
                              borderRadius:
                              BorderRadius.circular(6))),
                      const SizedBox(height: 6),
                      Container(
                          width: 80,
                          height: 10,
                          decoration: BoxDecoration(
                              color: c,
                              borderRadius:
                              BorderRadius.circular(4))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(
                  width: 200,
                  height: 10,
                  decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(4))),
            ],
          ),
        );
      },
    );
  }
}