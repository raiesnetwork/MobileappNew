import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/screens/communities_page/communities_screen.dart';
import 'package:ixes.app/screens/services_page/services_screen.dart';
import 'package:ixes.app/screens/campaigns_page/getall_campaigns_screen.dart';
import 'package:ixes.app/providers/announcement_provider.dart';
import 'package:ixes.app/providers/notification_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch data when dependencies change (i.e., when the provider is available)
    final provider = Provider.of<AnnouncementProvider>(context, listen: false);
    provider.fetchDashboardCounts().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // Helper method to build notification badge
  Widget _buildNotificationBadge(int count) {
    if (count == 0) return const SizedBox.shrink();

    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        constraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
        ),
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Overview of your activities',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),

              // Dashboard Cards or Loading Indicator
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Expanded(
                child: Consumer2<AnnouncementProvider, NotificationProvider>(
                  builder: (context, announcementProvider, notificationProvider, _) {
                    // Get notification counts for each category
                    final communityCount = notificationProvider.getUnreadCountForTypes([
                      'community',
                      'GroupRequest',
                    ]);

                    final servicesCount = notificationProvider.getUnreadCountForTypes([
                      'Service',
                      'Invoice',
                      'StoreSubscription',
                      'SubDomain',
                      'AddProduct',
                      'ServiceReq',
                    ]);

                    final campaignsCount = notificationProvider.getUnreadCountForTypes([
                      'campaign',
                    ]);

                    return Column(
                      children: [
                        // Communities Card with Badge
                        _buildDashboardCard(
                          title: 'Communities',
                          subtitle: 'Total: ${announcementProvider.totalCommunities}',
                          icon: const Icon(Icons.group, color: Colors.white, size: 28),
                          color: const Color(0xFFFF4081),
                          iconColor: Colors.white,
                          notificationCount: communityCount,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CommunitiesScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Services Card with Asset Image and Badge
                        _buildDashboardCard(
                          title: 'Services',
                          subtitle: 'Total: ${announcementProvider.totalServices}',
                          icon: Image.asset(
                            'assets/icons/service.png',
                            height: 28,
                            width: 28,
                            color: Colors.white,
                          ),
                          color: const Color(0xFF2196F3),
                          iconColor: Colors.white,
                          notificationCount: servicesCount,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ServicesScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Campaigns Card with Badge
                        _buildDashboardCard(
                          title: 'Campaigns',
                          subtitle: 'Total: ${announcementProvider.totalCampaigns}',
                          icon: const Icon(Icons.campaign, color: Colors.white, size: 28),
                          color: const Color(0xFF4CAF50),
                          iconColor: Colors.white,
                          notificationCount: campaignsCount,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CampaignsScreen(
                                  buildImageWidget: _buildImageWidget,
                                  communityId: '',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String? imageData, {bool isProfileImage = false}) {
    if (imageData == null || imageData.isEmpty) {
      return isProfileImage
          ? const Icon(Icons.person, color: Colors.white, size: 24)
          : Container();
    }

    if (imageData.startsWith('data:')) {
      try {
        final base64Data = imageData.split(',')[1];
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          width: isProfileImage ? 120 : double.infinity,
          height: isProfileImage ? 120 : 300,
          errorBuilder: (context, error, stackTrace) {
            return isProfileImage
                ? const Icon(Icons.person, color: Colors.white, size: 24)
                : Container();
          },
        );
      } catch (e) {
        return isProfileImage
            ? const Icon(Icons.person, color: Colors.white, size: 24)
            : Container();
      }
    } else {
      final processedImage = imageData.startsWith('/')
          ? 'https://api.ixes.ai$imageData'
          : imageData;
      return Image.network(
        processedImage,
        fit: BoxFit.cover,
        width: isProfileImage ? 120 : double.infinity,
        height: isProfileImage ? 120 : 300,
        errorBuilder: (context, error, stackTrace) {
          return isProfileImage
              ? const Icon(Icons.person, color: Colors.white, size: 24)
              : Container();
        },
      );
    }
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required Widget icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    int notificationCount = 0, // ✅ NEW: Notification count parameter
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Icon box
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: icon),
                  ),
                  const SizedBox(width: 20),

                  // Texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.7),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          // ✅ Notification Badge
          _buildNotificationBadge(notificationCount),
        ],
      ),
    );
  }
}