import 'dart:convert';
import 'package:flutter/material.dart';
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

  const CampaignsScreen({super.key, required this.buildImageWidget, required this.communityId});

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
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreCampaigns();
      }
    });
  }

  void _loadMoreCampaigns() async {
    final provider = context.read<CampaignProvider>();

    // Prevent multiple simultaneous calls
    if (_isLoadingMore || provider.isLoading || !provider.hasMoreCampaigns) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    // Calculate next page based on current campaigns count
    final currentPage = (provider.campaigns.length / 10).ceil();
    final nextPage = currentPage + 1;

    print('Loading more campaigns - Current count: ${provider.campaigns.length}, Loading page: $nextPage');

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
            Text('Delete Campaign', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black87)),
          ],
        ),
        content: const Text('Are you sure you want to delete this campaign? This action cannot be undone.',
            style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final response = await context.read<CampaignProvider>().deleteCampaign(campaignId);
              if (mounted) {
                final isError = response['error'] ?? true;
                final message = response['message'] ?? 'Unknown error';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(child: Text(isError ? 'Error: $message' : message, style: const TextStyle(color: Colors.white, fontSize: 14))),
                      ],
                    ),
                    backgroundColor: isError ? Colors.red : Colors.green,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Delete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Build image - now handles multipart URL responses
  Widget _buildCampaignImage(String imageUrl) {
    try {
      if (imageUrl.isEmpty) {
        return _buildImageErrorWidget();
      }

      // Use the buildImageWidget for URL-based images
      return widget.buildImageWidget(imageUrl, isProfileImage: false);
    } catch (e) {
      print('Error processing campaign image: $e');
      return _buildImageErrorWidget();
    }
  }

  Widget _buildImageErrorWidget() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 48),
          const SizedBox(height: 12),
          Text('Failed to load image', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          'Campaigns',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.5),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: Consumer<CampaignProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.campaigns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const CircularProgressIndicator(color: Primary, strokeWidth: 3),
                  ),
                  const SizedBox(height: 24),
                  const Text('Loading campaigns...', style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          if (provider.campaigns.isEmpty && provider.errorMessage != null) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      provider.errorMessage!,
                      style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.refreshCampaigns(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.campaigns.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.campaign_outlined, size: 64, color: Primary),
                    ),
                    const SizedBox(height: 24),
                    const Text('No Campaigns Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black87)),
                    const SizedBox(height: 8),
                    const Text('Create your first campaign to get started', style: TextStyle(fontSize: 16, color: Colors.black54)),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refreshCampaigns,
            color: Primary,
            backgroundColor: Colors.white,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: provider.campaigns.length + (provider.hasMoreCampaigns ? 1 : 0),
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
    // Get cover image URL from the response
    final String coverImage = campaign['coverImage'] ?? '';
    final String schedule = (campaign['schedule'] ?? 'one_time').toString().toLowerCase();
    final String communityName = campaign['community']?['name'] ?? 'Unknown';

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
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
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey.shade100,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: coverImage.isNotEmpty
                            ? _buildCampaignImage(coverImage)
                            : Container(
                          color: Primary.withOpacity(0.1),
                          child: const Icon(Icons.campaign_outlined, size: 40, color: Primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Padding(
                            padding: const EdgeInsets.only(right: 15),
                            child: Text(
                              campaign['title'] ?? 'Untitled Campaign',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Description
                          Text(
                            campaign['description'] ?? 'No description available',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),

                          // Schedule + Members Button
                          Row(
                            children: [
                              // Schedule Chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.schedule, size: 14, color: Colors.green),
                                    const SizedBox(width: 6),
                                    Text(
                                      schedule.replaceAll('_', ' ').toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Members icon
                              if (campaign['isUserAdmin'] == true)
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.people_outline, color: Colors.blue, size: 16),
                                  ),
                                  tooltip: 'View Members',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CampaignMembersScreen(campaignId: campaign['_id']),
                                      ),
                                    );
                                  },
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
        ),

        if (campaign['isUserAdmin'] == true)
          Positioned(
            top: 3,
            right: 5,
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editCampaign(campaign);
                } else if (value == 'delete') {
                  _confirmDelete(campaign['_id']);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Text('Edit', style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: const CircularProgressIndicator(color: Primary, strokeWidth: 3),
        ),
      ),
    );
  }
}