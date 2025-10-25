import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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

class _CampaignDetailsScreenState extends State<CampaignDetailsScreen> {
  Map<String, dynamic>? campaign;
  bool isLoading = true;
  String? errorMessage;
  bool isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
    });
  }

  Future<void> _loadDetails() async {
    final provider = context.read<CampaignProvider>();
    final response = await provider.getCampaignDetails(widget.campaignId);
    if (mounted) {
      setState(() {
        campaign = response['campaign'];
        errorMessage = response['error'] ? response['message'] : null;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          'Campaign Details'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading campaign details...',
                style: TextStyle(fontSize: 16)),
          ],
        ),
      )
          : errorMessage != null
          ? Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: Colors.red),
                const SizedBox(height: 5),
                Text(
                  errorMessage!,
                  style: const TextStyle(
                      fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          : campaign == null
          ? Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No campaign found',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          : _buildCampaignContent(),
    );
  }

  Widget _buildCampaignContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(1),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image with Status Badges
            _buildCoverImageSection(),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    campaign!['title'] ?? 'Untitled Campaign',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Expandable Description
                  _buildExpandableDescription(),
                  const SizedBox(height: 16),

                  // Creator and Community Info
                  _buildCreatorInfo(),
                  const SizedBox(height: 20),

                  // Progress Section
                  _buildProgressSection(),
                  const SizedBox(height: 20),

                  // Campaign Details Grid
                  _buildDetailsGrid(),
                  const SizedBox(height: 20),

                  // Payment and Statistics
                  _buildPaymentAndStats(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCoverImageSection() {
    return Stack(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          child: campaign!['coverImage']?.isNotEmpty ?? false
              ? ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: _buildImageWidget(campaign!['coverImage']),
          )
              : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.8),
                  Theme.of(context).primaryColor,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Center(
              child: Icon(
                Icons.campaign,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // Campaign Type Badge
        Positioned(
          top: 16,
          left: 16,
          child: _buildTypeBadge(),
        ),
      ],
    );
  }

  Widget _buildExpandableDescription() {
    final description = campaign!['description'] ?? 'No description available';
    const maxLines = 2;

    // Simple check: if description has more than 100 characters or contains multiple sentences
    final shouldShowSeeMore = description.length > 100 ||
        description.split('\n').length > 2 ||
        description.split('. ').length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: isDescriptionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
          secondChild: Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
        if (shouldShowSeeMore)
          GestureDetector(
            onTap: () {
              setState(() {
                isDescriptionExpanded = !isDescriptionExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                isDescriptionExpanded ? 'See less' : 'See more',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCreatorInfo() {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.group, size: 20, color: Colors.blue[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.communityName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.person, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Created by ${campaign!['createdBy'] ?? 'Unknown'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    final totalCollected = (campaign!['totalAmountCollected'] ?? 0).toDouble();
    final totalNeeded = (campaign!['totalAmountNeeded'] ?? 1).toDouble();
    final progress = totalNeeded > 0 ? (totalCollected / totalNeeded) * 100 : 0.0;
    final currency = campaign!['currency'] ?? '₹';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Funding Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${progress.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 100 ? Colors.green : Theme.of(context).primaryColor,
            ),
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collected',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '$currency${totalCollected.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Goal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '$currency${totalNeeded.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Campaign Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 5,
          mainAxisSpacing: 8,
          children: [
            _buildDetailItem(
              icon: Icons.schedule,
              label: 'Schedule',
              value: _formatSchedule(campaign!['schedule']),
            ),
            _buildDetailItem(
              icon: Icons.calendar_today,
              label: 'End Date',
              value: _formatDate(campaign!['endDate']),
            ),
            _buildDetailItem(
              icon: Icons.payment,
              label: 'Per User',
              value: '${campaign!['currency'] ?? '₹'}${campaign!['amountPayablePerUser'] ?? 0}',
            ),
            _buildDetailItem(
              icon: Icons.people,
              label: 'Members',
              value: '${campaign!['totalMembers'] ?? 0}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAndStats() {
    final paidUsers = campaign!['paidUsers'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.people_alt,
                      label: 'Paid Users',
                      value: '${paidUsers.length}',
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.visibility,
                      label: 'Views',
                      value: '${campaign!['totalViews'] ?? 0}',
                      color: Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.touch_app,
                      label: 'Clicks',
                      value: '${campaign!['totalClicks'] ?? 0}',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Created: ${_formatDate(campaign!['createdAt'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Updated: ${_formatDate(campaign!['updatedAt'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final status = campaign!['status'] ?? 'UNKNOWN';
    final published = campaign!['published'] ?? false;

    Color badgeColor;
    String badgeText;

    if (!published) {
      badgeColor = Colors.orange;
      badgeText = 'DRAFT';
    } else {
      switch (status) {
        case 'OPEN':
          badgeColor = Colors.green;
          badgeText = 'ACTIVE';
          break;
        case 'CLOSED':
          badgeColor = Colors.red;
          badgeText = 'CLOSED';
          break;
        default:
          badgeColor = Colors.grey;
          badgeText = status;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final type = campaign!['type'] ?? 'OPTIONAL';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: type == 'MANDATORY' ? Colors.red[600] : Colors.blue[600],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildImageWidget(String? imageUrl, {bool isProfileImage = false}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, size: 100, color: Colors.grey),
      );
    }
    if (imageUrl.startsWith('data:image')) {
      final base64String = imageUrl.split(',').last;
      try {
        final imageBytes = base64Decode(base64String);
        return Image.memory(
          imageBytes,
          height: isProfileImage ? 100 : 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[200],
            child:
            const Icon(Icons.broken_image, size: 100, color: Colors.grey),
          ),
        );
      } catch (e) {
        print('Error decoding Base64 image: $e');
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 100, color: Colors.grey),
        );
      }
    }
    final processedImage =
    imageUrl.startsWith('/') ? 'https://api.ixes.ai$imageUrl' : imageUrl;
    return widget.buildImageWidget(
      processedImage,
      isProfileImage: isProfileImage,
    );
  }

  String _formatDate(dynamic dateString) {
    try {
      if (dateString == null) return 'N/A';
      final date = DateTime.parse(dateString.toString());
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _formatSchedule(dynamic schedule) {
    if (schedule == null) return 'N/A';
    final scheduleStr = schedule.toString();
    switch (scheduleStr) {
      case 'one_time':
        return 'One Time';
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return scheduleStr;
    }
  }
}