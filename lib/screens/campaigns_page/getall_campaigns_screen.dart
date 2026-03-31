import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ixes.app/screens/campaigns_page/share_campaign.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/campaign_provider.dart';
import 'campaign_members.dart';
import 'campaigns_info screen.dart';
import 'create_campaign_screen.dart';

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

  void _shareCampaign(String campaignId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShareCampaignScreen(campaignId: campaignId),
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE53935),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Campaign?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This action cannot be undone. All campaign data will be permanently removed.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFF3F4F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final response = await context
                            .read<CampaignProvider>()
                            .deleteCampaign(campaignId);
                        if (mounted) {
                          final isError = response['error'] ?? true;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    isError
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isError
                                          ? 'Error: ${response['message'] ?? 'Unknown error'}'
                                          : response['message'] ?? 'Deleted',
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: isError
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                  strokeWidth: 2,
                  color: Primary,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
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
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(
          Icons.campaign_outlined,
          color: Primary,
          size: 36,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        title: const Text(
          'Campaigns',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Consumer<CampaignProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.campaigns.isEmpty) {
            return _buildLoadingState();
          }
          if (provider.campaigns.isEmpty && provider.errorMessage != null) {
            return _buildErrorState(provider);
          }
          if (provider.campaigns.isEmpty) {
            return _buildEmptyState();
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              onRefresh: provider.refreshCampaigns,
              color: Primary,
              backgroundColor: Colors.white,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: provider.campaigns.length +
                    (provider.hasMoreCampaigns ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < provider.campaigns.length) {
                    return _buildCampaignCard(
                        provider.campaigns[index], index);
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Primary.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Primary, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading campaigns...',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CampaignProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 40, color: Color(0xFFE53935)),
            ),
            const SizedBox(height: 20),
            Text(
              provider.errorMessage!,
              style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.refreshCampaigns(),
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
              label: const Text('Try Again',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.campaign_outlined,
                  size: 52, color: Primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Campaigns Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first campaign to engage\nyour community',
              style: TextStyle(
                  fontSize: 15, color: Color(0xFF6B7280), height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignCard(dynamic campaign, int index) {
    final String coverImage = campaign['coverImage'] ?? '';
    final String schedule =
    (campaign['schedule'] ?? 'one_time').toString().toLowerCase();
    final String communityName =
        campaign['community']?['name'] ?? 'Unknown';
    // FIX BUG 7: isUserAdmin comes from campaign['isUserAdmin'], not a community field
    final bool isAdmin = campaign['isUserAdmin'] == true;
    final String type =
    (campaign['type'] ?? 'MANDATORY').toString().toUpperCase();
    final bool isCompleted = campaign['isCompleted'] == true;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 60).clamp(0, 400)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1A2E).withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cover image full-width ──────────────────────────
                if (coverImage.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: _buildCampaignImage(coverImage),
                    ),
                  )
                else
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: _getTypeColor(type).withOpacity(0.08),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    child: Center(
                      child: Icon(Icons.campaign_outlined,
                          size: 48, color: _getTypeColor(type)),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title row + menu ──────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              campaign['title'] ?? 'Untitled Campaign',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.2,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildPopupMenu(campaign, isAdmin),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // ── Community name ──────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.group_outlined,
                              size: 13, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Text(
                            communityName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── Description ────────────────────────────
                      Text(
                        campaign['description'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),

                      // ── Progress bar (only for payment campaigns) ──
                      if ((campaign['totalAmountNeeded'] ?? 0) > 0)
                        _buildProgressBar(campaign),

                      if ((campaign['totalAmountNeeded'] ?? 0) > 0)
                        const SizedBox(height: 14),

                      // ── Chips row ──────────────────────────────
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(
                            icon: Icons.schedule_rounded,
                            label: _formatSchedule(schedule),
                            color: _getScheduleColor(schedule),
                          ),
                          _buildChip(
                            icon: _getTypeIcon(type),
                            label: type,
                            color: _getTypeColor(type),
                          ),
                          if (isCompleted)
                            _buildChip(
                              icon: Icons.check_circle_rounded,
                              label: 'Completed',
                              color: const Color(0xFF10B981),
                            ),
                          if (isAdmin)
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CampaignMembersScreen(
                                    campaignId: campaign['_id'],
                                  ),
                                ),
                              ),
                              child: _buildChip(
                                icon: Icons.people_alt_outlined,
                                label:
                                'Members${campaign['totalMembers'] != null ? ' · ${campaign['totalMembers']}' : ''}',
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                        ],
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
                color: Color(0xFF10B981),
              ),
            ),
            Text(
              'of $currency${needed.toInt()}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0
                  ? const Color(0xFF10B981)
                  : Primary,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupMenu(dynamic campaign, bool isAdmin) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') _editCampaign(campaign);
        if (value == 'delete') _confirmDelete(campaign['_id']);
        if (value == 'share') _shareCampaign(campaign['_id']);
      },
      padding: EdgeInsets.zero,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];
        if (isAdmin)
          items.add(_menuItem('edit', 'Edit', Icons.edit_outlined,
              const Color(0xFF6366F1)));
        items.add(_menuItem('share', 'Share', Icons.share_outlined,
            const Color(0xFF10B981)));
        if (isAdmin)
          items.add(_menuItem('delete', 'Delete', Icons.delete_outline_rounded,
              const Color(0xFFE53935)));
        return items;
      },
      color: Colors.white,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      icon: Icon(Icons.more_horiz_rounded,
          size: 20, color: const Color(0xFF9CA3AF)),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: value,
      height: 48,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
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
        return const Color(0xFF10B981);
    }
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
    return schedule.replaceAll('_', ' ').toUpperCase();
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}