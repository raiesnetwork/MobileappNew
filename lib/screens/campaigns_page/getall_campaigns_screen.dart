import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/campaign_provider.dart';
import 'campaign_members.dart';
import 'campaigns_info screen.dart';
import 'create_campaign_screen.dart';
import '../home/feedpage/sharepost_screen.dart';

class CampaignsScreen extends StatefulWidget {
  final Widget Function(String?, {bool isProfileImage}) buildImageWidget;
  final String communityId;

  const CampaignsScreen({
    super.key,
    required this.buildImageWidget,
    required this.communityId,
  });

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Design tokens (mirrors AnnouncementScreen _T) ──────────────────────────
  static const _accent = Color(0xFF6366F1);
  static const _accentLight = Color(0xFFEEF0FD);
  static const _textPrimary = Color(0xFF1A1A2E);
  static const _textSecondary = Color(0xFF6B7280);
  static const _textTertiary = Color(0xFF9CA3AF);
  static const _divider = Color(0xFFF0F1F5);
  static const _red = Color(0xFFE53935);
  static const _redLight = Color(0xFFFFEEEE);
  static const _green = Color(0xFF10B981);
  static const _surface = Colors.white;
  static const _bg = Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CampaignProvider>();
      if (provider.campaigns.isEmpty) {
        provider.fetchAllCampaigns(page: 1);
      }
      _setupScrollListener();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        _loadMoreCampaigns();
      }
    });
  }

  void _shareCampaign(String campaignId, String campaignTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharePostScreen(
          postId: campaignTitle,
          shareContext: 'campaign',
          contextId: campaignId,
        ),
      ),
    );
  }

  void _loadMoreCampaigns() async {
    if (_isLoadingMore) return;
    final provider = context.read<CampaignProvider>();
    if (provider.isLoading || !provider.hasMoreCampaigns) return;

    _isLoadingMore = true;
    if (mounted) setState(() {});
    await provider.fetchAllCampaigns(page: provider.currentPage + 1);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _editCampaign(dynamic campaign) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCampaignScreen(
          campaign: campaign,
          communityId: widget.communityId,
        ),
      ),
    );
    if (result == true && mounted) {
      context.read<CampaignProvider>().refreshCampaigns();
    }
  }

  void _confirmDelete(String campaignId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Campaign',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'This will permanently remove this campaign and all its data.',
          style: TextStyle(color: _textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final response = await context
                  .read<CampaignProvider>()
                  .deleteCampaign(campaignId);
              if (mounted) {
                final isError = response['error'] ?? true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isError
                          ? 'Error: ${response['message'] ?? 'Unknown error'}'
                          : response['message'] ?? 'Deleted',
                    ),
                    backgroundColor: isError ? _red : _green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignImage(String imageUrl) {
    try {
      if (imageUrl.isEmpty) return _buildImagePlaceholder();
      if (imageUrl.startsWith('http://') ||
          imageUrl.startsWith('https://') ||
          imageUrl.contains('amazonaws.com') ||
          imageUrl.contains('cloudfront.net')) {
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: const Color(0xFFF3F4F6),
              child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Primary),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildImagePlaceholder(),
        );
      } else {
        return widget.buildImageWidget(imageUrl, isProfileImage: false);
      }
    } catch (e) {
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(color: _accentLight),
      child: const Center(
        child: Icon(Icons.campaign_outlined, color: _accent, size: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Campaigns',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _divider),
        ),
      ),
      body: Consumer<CampaignProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.campaigns.isEmpty) {
            return _buildLoadingState();
          }
          if (provider.campaigns.isEmpty &&
              provider.errorMessage != null) {
            return _buildErrorState(provider);
          }
          if (provider.campaigns.isEmpty) {
            return _buildEmptyState();
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              onRefresh: provider.refreshCampaigns,
              color: _accent,
              backgroundColor: Colors.white,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 100),
                itemCount: provider.campaigns.length +
                    (provider.hasMoreCampaigns ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < provider.campaigns.length) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(
                          milliseconds: 350 + index * 60),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                            offset: Offset(0, 16 * (1 - v)),
                            child: child),
                      ),
                      child: _buildCampaignCard(
                          provider.campaigns[index], index),
                    );
                  }
                  return _buildLoadingMoreIndicator();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _accentLight,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                  color: _accent, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading campaigns...',
            style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CampaignProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: _redLight, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  color: _red, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Couldn\'t load',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            Text(provider.errorMessage ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: _textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => provider.refreshCampaigns(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: _accentLight, shape: BoxShape.circle),
            child: const Icon(Icons.campaign_outlined,
                color: _accent, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('No campaigns yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary)),
          const SizedBox(height: 6),
          const Text('Check back later or create one',
              style:
              TextStyle(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(dynamic campaign, int index) {
    final String coverImage = campaign['coverImage'] ?? '';
    final String schedule =
    (campaign['schedule'] ?? 'one_time').toString().toLowerCase();
    final String communityName =
        campaign['community']?['name'] ?? 'Unknown';
    // ── Fix: handle both bool true and string "true" ──────────────
    final bool isAdmin = campaign['isUserAdmin'] == true ||
        campaign['isUserAdmin'].toString() == 'true';
    final String type =
    (campaign['type'] ?? 'MANDATORY').toString().toUpperCase();
    final bool isCompleted = campaign['isCompleted'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CampaignDetailsScreen(
                campaignId: campaign['_id'],
                buildImageWidget: widget.buildImageWidget,
                communityName: communityName,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover image ──────────────────────────────────────
              if (coverImage.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: _buildCampaignImage(coverImage),
                  ),
                )
              else
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  child: Center(
                    child: Icon(Icons.campaign_outlined,
                        size: 40, color: _getTypeColor(type)),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title row + ⋮ menu ───────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon badge
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getTypeColor(type)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            _getTypeIcon(type),
                            color: _getTypeColor(type),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                campaign['title'] ??
                                    'Untitled Campaign',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                  letterSpacing: -0.2,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.group_outlined,
                                      size: 12, color: _textTertiary),
                                  const SizedBox(width: 4),
                                  Text(
                                    communityName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textTertiary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // ── ⋮ PopupMenuButton ────────────────────
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: _textTertiary, size: 20),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          onSelected: (v) {
                            if (v == 'share')
                              _shareCampaign(campaign['_id'], campaign['title'] ?? 'Campaign');
                            if (v == 'edit') _editCampaign(campaign);
                            if (v == 'delete')
                              _confirmDelete(campaign['_id']);
                            if (v == 'members')
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CampaignMembersScreen(
                                    campaignId: campaign['_id'],
                                  ),
                                ),
                              );
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'share',
                              height: 42,
                              child: Row(children: const [
                                Icon(Icons.share_outlined,
                                    color: _accent, size: 18),
                                SizedBox(width: 10),
                                Text('Share',
                                    style: TextStyle(fontSize: 14)),
                              ]),
                            ),
                            if (isAdmin) ...[
                              PopupMenuItem(
                                value: 'members',
                                height: 42,
                                child: Row(children: [
                                  const Icon(
                                      Icons.people_alt_outlined,
                                      color: _accent,
                                      size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Members${campaign['totalMembers'] != null ? ' · ${campaign['totalMembers']}' : ''}',
                                    style: const TextStyle(
                                        fontSize: 14),
                                  ),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                height: 42,
                                child: Row(children: const [
                                  Icon(Icons.edit_outlined,
                                      color: _accent, size: 18),
                                  SizedBox(width: 10),
                                  Text('Edit',
                                      style: TextStyle(fontSize: 14)),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                height: 42,
                                child: Row(children: const [
                                  Icon(
                                      Icons.delete_outline_rounded,
                                      color: _red,
                                      size: 18),
                                  SizedBox(width: 10),
                                  Text('Delete',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: _red)),
                                ]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    // ── Description ──────────────────────────────
                    if ((campaign['description'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        campaign['description'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textSecondary,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // ── Progress bar ─────────────────────────────
                    if ((campaign['totalAmountNeeded'] ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      _buildProgressBar(campaign),
                    ],

                    // ── Status chips (non-action, info only) ─────
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: _buildChip(
                            icon: Icons.schedule_rounded,
                            label: _formatSchedule(schedule),
                            color: _getScheduleColor(schedule),
                            shrink: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildChip(
                          icon: _getTypeIcon(type),
                          label: type,
                          color: _getTypeColor(type),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(width: 8),
                          _buildChip(
                            icon: Icons.check_circle_rounded,
                            label: 'Completed',
                            color: _green,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(dynamic campaign) {
    final double collected =
    (campaign['totalAmountCollected'] ?? 0).toDouble();
    final double needed =
    (campaign['totalAmountNeeded'] ?? 1).toDouble();
    final double progress = (collected / needed).clamp(0.0, 1.0);
    final String currency = campaign['currency'] ?? '₹';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$currency${collected.toInt()} raised',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _green),
            ),
            Text(
              'of $currency${needed.toInt()}',
              style: const TextStyle(
                  fontSize: 12, color: _textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: _divider,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? _green : _accent,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    bool shrink = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          if (shrink)
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            )
          else
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Color _getScheduleColor(String schedule) {
    switch (schedule) {
      case 'daily':
        return const Color(0xFF3B82F6);
      case 'weekly':
        return const Color(0xFF8B5CF6);
      case 'monthly':
        return const Color(0xFFF59E0B);
      case 'yearly':
        return const Color(0xFFEC4899);
      default:
        return _green;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'MARKETING':
        return const Color(0xFFF59E0B);
      case 'MANDATORY':
        return _red;
      default:
        return _accent;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'MARKETING':
        return Icons.trending_up_rounded;
      case 'MANDATORY':
        return Icons.lock_outline_rounded;
      default:
        return Icons.campaign_outlined;
    }
  }

  String _formatSchedule(String schedule) {
    return schedule[0].toUpperCase() +
        schedule.substring(1).replaceAll('_', ' ');
  }

  Widget _buildLoadingMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              color: _accent, strokeWidth: 2.5),
        ),
      ),
    );
  }
}