import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/constants.dart';
import '../../providers/campaign_provider.dart';

class CampaignDetailsScreen extends StatefulWidget {
  final String campaignId;
  final String communityName;
  final Widget Function(String?, {bool isProfileImage}) buildImageWidget;

  const CampaignDetailsScreen({
    super.key,
    required this.campaignId,
    required this.buildImageWidget,
    required this.communityName,
  });

  @override
  State<CampaignDetailsScreen> createState() => _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState extends State<CampaignDetailsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? campaign;
  bool isLoading = true;
  String? errorMessage;
  bool isDescriptionExpanded = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final provider = context.read<CampaignProvider>();
    final response = await provider.getCampaignDetails(widget.campaignId);
    if (mounted) {
      setState(() {
        // FIX BUG 5: backend wraps in { data: {...} }, provider should unwrap.
        // Support both shapes: response['campaign'] or response['data']
        campaign = response['campaign'] ?? response['data'];
        errorMessage =
        (response['error'] == true) ? response['message'] : null;
        isLoading = false;
      });
      if (campaign != null) _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: isLoading
          ? _buildLoading()
          : errorMessage != null
          ? _buildError()
          : campaign == null
          ? _buildNotFound()
          : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Primary, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Loading campaign...',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildError() {
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
            Text(errorMessage!,
                style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 64, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          const Text('Campaign not found',
              style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadDetails,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  _buildTitleSection(),
                  const SizedBox(height: 16),
                  _buildDescription(),
                  const SizedBox(height: 16),
                  if ((campaign!['totalAmountNeeded'] ?? 0) > 0)
                    _buildProgressCard(),
                  if ((campaign!['totalAmountNeeded'] ?? 0) > 0)
                    const SizedBox(height: 16),
                  _buildDetailsGrid(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                  _buildMetaRow(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final coverImage = campaign!['coverImage'] ?? '';
    final type = (campaign!['type'] ?? 'MANDATORY').toString().toUpperCase();

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: Colors.white),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image or gradient
            coverImage.isNotEmpty
                ? _buildDetailImage(coverImage)
                : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Primary.withOpacity(0.8),
                    Primary,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.campaign, size: 80, color: Colors.white),
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Type badge
            Positioned(
              bottom: 20,
              left: 16,
              child: _buildBadge(type, _getTypeColor(type)),
            ),
            Positioned(
              bottom: 20,
              right: 16,
              child: _buildBadge(
                campaign!['schedule']?.toString().toUpperCase() ?? '',
                const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          campaign!['title'] ?? 'Untitled',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.group_outlined,
                size: 14, color: Color(0xFF6366F1)),
            const SizedBox(width: 5),
            Text(
              widget.communityName,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.person_outline,
                size: 14, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 5),
            Text(
              campaign!['createdBy'] ?? 'Unknown',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() {
    final desc = campaign!['description'] ?? '';
    final isLong = desc.length > 120;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: isDescriptionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              desc,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF4B5563), height: 1.6),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            secondChild: Text(
              desc,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF4B5563), height: 1.6),
            ),
          ),
          if (isLong)
            GestureDetector(
              onTap: () =>
                  setState(() => isDescriptionExpanded = !isDescriptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isDescriptionExpanded ? 'Show less' : 'Read more',
                  style: const TextStyle(
                    color: Primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final double collected =
    (campaign!['totalAmountCollected'] ?? 0).toDouble();
    final double needed = (campaign!['totalAmountNeeded'] ?? 1).toDouble();
    final double progress = needed > 0 ? (collected / needed) : 0;
    final String currency = campaign!['currency'] ?? '₹';
    final int pct = (progress * 100).clamp(0, 100).toInt();

    return Container(
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
              const Text('Funding Progress',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E))),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (pct >= 100
                      ? const Color(0xFF10B981)
                      : Primary)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: pct >= 100 ? const Color(0xFF10B981) : Primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 100 ? const Color(0xFF10B981) : Primary,
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildAmountItem(
                  label: 'Raised',
                  amount: '$currency${collected.toStringAsFixed(0)}',
                  color: const Color(0xFF10B981),
                ),
              ),
              Container(
                  width: 1, height: 36, color: const Color(0xFFE5E7EB)),
              Expanded(
                child: _buildAmountItem(
                  label: 'Goal',
                  amount: '$currency${needed.toStringAsFixed(0)}',
                  color: const Color(0xFF1A1A2E),
                  align: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountItem({
    required String label,
    required String amount,
    required Color color,
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(amount,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3)),
      ],
    );
  }

  Widget _buildDetailsGrid() {
    // FIX BUG 4: use amountPayablePerUser not amountPerUser
    final items = [
      _GridItem(
          icon: Icons.schedule_rounded,
          label: 'Schedule',
          value: _formatSchedule(campaign!['schedule'])),
      _GridItem(
          icon: Icons.calendar_today_rounded,
          label: 'End Date',
          value: _formatDate(campaign!['endDate'])),
      _GridItem(
          icon: Icons.person_outlined,
          label: 'Per User',
          value:
          '${campaign!['currency'] ?? '₹'}${campaign!['amountPayablePerUser'] ?? 0}'),
      _GridItem(
          icon: Icons.group_outlined,
          label: 'Members',
          value: '${campaign!['totalMembers'] ?? 0}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Campaign Details',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: items.map((item) => _buildGridCell(item)).toList(),
        ),
      ],
    );
  }

  Widget _buildGridCell(_GridItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
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
            child: Icon(item.icon, size: 16, color: Primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    // FIX BUG 5: paidUsers is returned inside campaign.toObject() from backend
    final paidUsers = campaign!['paidUsers'] as List? ?? [];
    final stats = [
      _StatItem(
          icon: Icons.check_circle_outline_rounded,
          label: 'Paid',
          value: '${paidUsers.length}',
          color: const Color(0xFF10B981)),
      _StatItem(
          icon: Icons.visibility_outlined,
          label: 'Views',
          value: '${campaign!['totalViews'] ?? 0}',
          color: const Color(0xFF3B82F6)),
      _StatItem(
          icon: Icons.ads_click_rounded,
          label: 'Clicks',
          value: '${campaign!['totalClicks'] ?? 0}',
          color: const Color(0xFFF59E0B)),
      _StatItem(
          icon: Icons.local_activity_outlined,
          label: 'Leads',
          value: '${campaign!['totalLeads'] ?? 0}',
          color: const Color(0xFF8B5CF6)),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 16),
          Row(
            children: stats
                .map((s) => Expanded(child: _buildStatCell(s)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell(_StatItem s) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: s.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(s.icon, size: 20, color: s.color),
        ),
        const SizedBox(height: 6),
        Text(s.value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: s.color,
                letterSpacing: -0.3)),
        Text(s.label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMetaRow() {
    return Row(
      children: [
        const Icon(Icons.access_time_rounded,
            size: 13, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 5),
        Text(
          'Created ${_formatDate(campaign!['createdAt'])}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        const Spacer(),
        const Icon(Icons.update_rounded, size: 13, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 5),
        Text(
          'Updated ${_formatDate(campaign!['updatedAt'])}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildDetailImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(imageUrl.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF0F4FF)));
    }
    final processed = imageUrl.startsWith('/')
        ? 'https://api.ixes.ai$imageUrl'
        : imageUrl;
    return widget.buildImageWidget(processed, isProfileImage: false);
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'MARKETING':
        return const Color(0xFFF59E0B);
      case 'MANDATORY':
        return const Color(0xFFE53935);
      default:
        return Primary;
    }
  }

  String _formatDate(dynamic v) {
    try {
      if (v == null) return 'N/A';
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(v.toString()));
    } catch (_) {
      return 'N/A';
    }
  }

  String _formatSchedule(dynamic v) {
    if (v == null) return 'N/A';
    switch (v.toString()) {
      case 'one_time':
        return 'One Time';
      case 'half_yearly':
        return 'Half Yearly';
      case '2_day':
        return 'Every 2 Days';
      default:
        return v.toString()[0].toUpperCase() + v.toString().substring(1);
    }
  }
}

class _GridItem {
  final IconData icon;
  final String label;
  final String value;
  _GridItem({required this.icon, required this.label, required this.value});
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  _StatItem(
      {required this.icon,
        required this.label,
        required this.value,
        required this.color});
}