import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ixes.app/screens/campaigns_page/share_campaign.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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

class _CampaignsScreenState extends State<CampaignsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CampaignProvider>().fetchAllCampaigns(page: 1);
    });
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
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
        builder: (context) => ShareCampaignScreen(
          campaignId: campaignId,
        ),
      ),
    );
  }

  void _loadMoreCampaigns() async {
    final provider = context.read<CampaignProvider>();

    if (_isLoadingMore || provider.isLoading || !provider.hasMoreCampaigns) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final currentPage = (provider.campaigns.length / 10).ceil();
    final nextPage = currentPage + 1;

    print('📄 Loading page $nextPage (current campaigns: ${provider.campaigns.length})');

    await provider.fetchAllCampaigns(page: nextPage);

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _editCampaign(dynamic campaign) async {
    print('Editing campaign: $campaign');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(24),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Delete Campaign',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this campaign? This action cannot be undone.',
          style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final response = await context
                  .read<CampaignProvider>()
                  .deleteCampaign(campaignId);
              if (mounted) {
                final isError = response['error'] ?? true;
                final message = response['message'] ?? 'Unknown error';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          isError
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isError ? 'Error: $message' : message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: isError ? Colors.red : Colors.green,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignImage(String imageUrl) {
    try {
      if (imageUrl.isEmpty) {
        return _buildImageErrorWidget();
      }

      print('🖼️ Building image for URL: $imageUrl');

      // Handle both S3 URLs and relative paths
      if (imageUrl.startsWith('http://') ||
          imageUrl.startsWith('https://') ||
          imageUrl.contains('amazonaws.com') ||
          imageUrl.contains('cloudfront.net')) {
        // Direct URL (S3, HTTP, HTTPS)
        print('✅ Loading direct URL: $imageUrl');
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('✅ Image loaded successfully: $imageUrl');
              return child;
            }
            final progress = loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes!
                : null;
            print('⏳ Loading image: ${(progress ?? 0) * 100}%');
            return Center(
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading image: $imageUrl');
            print('❌ Error details: $error');
            return _buildImageErrorWidget();
          },
        );
      } else {
        // Use buildImageWidget for relative paths
        print('🔗 Using buildImageWidget for: $imageUrl');
        return widget.buildImageWidget(imageUrl, isProfileImage: false);
      }
    } catch (e) {
      print('❌ Exception processing campaign image: $e');
      return _buildImageErrorWidget();
    }
  }

  Widget _buildImageErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade300,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            'No image',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          'Campaigns',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
      ),
      body: Consumer<CampaignProvider>(
        builder: (context, provider, _) {
          // Initial loading
          if (provider.isLoading && provider.campaigns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Primary.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: Primary,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Loading campaigns...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          // Error state
          if (provider.campaigns.isEmpty && provider.errorMessage != null) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      provider.errorMessage!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.refreshCampaigns(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Empty state
          if (provider.campaigns.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        size: 56,
                        color: Primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Campaigns Yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first campaign\nto get started',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Campaign list
          return RefreshIndicator(
            onRefresh: provider.refreshCampaigns,
            color: Primary,
            backgroundColor: Colors.white,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: provider.campaigns.length +
                  (provider.hasMoreCampaigns ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < provider.campaigns.length) {
                  return _buildCampaignCard(provider.campaigns[index], index);
                } else {
                  return _buildLoadingMoreIndicator();
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCampaignCard(dynamic campaign, int index) {
    final String coverImage = campaign['coverImage'] ?? '';
    final String schedule =
    (campaign['schedule'] ?? 'one_time').toString().toLowerCase();
    final String communityName = campaign['community']?['name'] ?? 'Unknown';
    final bool isAdmin = campaign['isUserAdmin'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CampaignDetailsScreen(
                  campaignId: campaign['_id'],
                  buildImageWidget: widget.buildImageWidget,
                  communityName: communityName,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: coverImage.isNotEmpty
                        ? _buildCampaignImage(coverImage)
                        : Container(
                      decoration: BoxDecoration(
                        color: Primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        size: 40,
                        color: Primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with menu
                      // Replace the entire Title row with menu section with this:


                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              campaign['title'] ?? 'Untitled Campaign',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // ✅ THREE DOTS MENU FOR EVERYONE
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editCampaign(campaign);
                              } else if (value == 'delete') {
                                _confirmDelete(campaign['_id']);
                              } else if (value == 'share') {
                                _shareCampaign(campaign['_id']);
                              }
                            },
                            padding: EdgeInsets.zero,
                            itemBuilder: (context) {
                              // Build menu items dynamically based on admin status
                              List<PopupMenuEntry<String>> menuItems = [];

                              // ✅ Edit - Only for admins
                              if (isAdmin) {
                                menuItems.add(
                                  PopupMenuItem(
                                    value: 'edit',
                                    height: 44,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              // ✅ Share - For EVERYONE
                              menuItems.add(
                                PopupMenuItem(
                                  value: 'share',
                                  height: 44,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.share_outlined,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Share',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              // ✅ Delete - Only for admins
                              if (isAdmin) {
                                menuItems.add(
                                  PopupMenuItem(
                                    value: 'delete',
                                    height: 44,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return menuItems;
                            },
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                            icon: Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Description
                      Text(
                        campaign['description'] ?? 'No description available',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // Schedule + Members (with wrap to prevent overflow)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Schedule Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _getScheduleColor(schedule).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getScheduleColor(schedule).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: _getScheduleColor(schedule),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatSchedule(schedule),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _getScheduleColor(schedule),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Members button
                          if (isAdmin)
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CampaignMembersScreen(
                                      campaignId: campaign['_id'],
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.people_outline_rounded,
                                      color: Colors.blue,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Members',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
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

  Color _getScheduleColor(String schedule) {
    switch (schedule.toLowerCase()) {
      case 'daily':
        return Colors.blue;
      case 'weekly':
        return Colors.purple;
      case 'monthly':
        return Colors.orange;
      case 'one_time':
      default:
        return Colors.green;
    }
  }

  String _formatSchedule(String schedule) {
    return schedule.replaceAll('_', ' ').toUpperCase();
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Primary,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading more campaigns...',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}