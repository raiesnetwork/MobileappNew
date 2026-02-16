import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/constants.dart';
import '../../providers/communities_provider.dart';
import '../dash_board_screens/main_dashboard.dart';
import 'community_campaigns.dart';
import 'community_members.dart';
import 'community_services.dart';

class CommunityStatsScreen extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityStatsScreen({
    super.key,
    required this.communityId,
    this.communityName = 'Community'
  });

  @override
  State<CommunityStatsScreen> createState() => _CommunityStatsScreenState();
}

class _CommunityStatsScreenState extends State<CommunityStatsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🚀 Fetching community hierarchy stats for: ${widget.communityId}');
      Provider.of<CommunityProvider>(context, listen: false)
          .fetchCommunityHierarchyStats(widget.communityId);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildGroupedStatsBox({
    required String title,
    required List<Map<String, dynamic>> items,
    required Color primaryColor,
    required int index,
  }) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _fadeAnimation.value)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.08),
                    primaryColor.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...items.asMap().entries.map((entry) {
                      final item = entry.value;
                      final isLast = entry.key == items.length - 1;
                      return Column(
                        children: [
                          InkWell(
                            onTap: item['onTap'],
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          item['color'],
                                          item['color'].withOpacity(0.8)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      item['icon'],
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['value'],
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: item['color'],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: item['color'].withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      color: item['color'],
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast) ...[
                            const SizedBox(height: 14),
                            Divider(
                              color: Colors.grey[200],
                              thickness: 1,
                              height: 1,
                            ),
                            const SizedBox(height: 14),
                          ],
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> statsData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Primary, Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Community Analytics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.communityName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Total Reach',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _calculateTotalReach(statsData).toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 35,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Growth',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Colors.green[300],
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+12.5%',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[300],
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
          ],
        ),
      ),
    );
  }

  int _calculateTotalReach(Map<String, dynamic> statsData) {
    final communities = statsData['totalCommunities'] as int? ?? 0;
    final users = statsData['totalUsers'] as int? ?? 0;
    final services = statsData['totalServices'] as int? ?? 0;
    final campaigns = statsData['totalCampaigns'] as int? ?? 0;
    return communities + users + services + campaigns;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Analytics Available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Statistics for this community are not\navailable at the moment',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Provider.of<CommunityProvider>(context, listen: false)
                  .fetchCommunityHierarchyStats(widget.communityId);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load Analytics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Go Back', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Provider.of<CommunityProvider>(context, listen: false)
                      .fetchCommunityHierarchyStats(widget.communityId);
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToCommunities() {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => YourCommunitiesScreen(
    //       communityId: widget.communityId,
    //       communityName: widget.communityName,
    //     ),
    //   ),
    // );
  }

  void _navigateToUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityMembersScreen(
          communityId: widget.communityId,
        ),
      ),
    );
  }

  void _navigateToServices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityServicesScreen(
          communityId: widget.communityId,
        ),
      ),
    );
  }

  void _navigateToCampaigns() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityCampaignsScreen(
          communityId: widget.communityId,
        ),
      ),
    );
  }

  void _navigateToDashboard() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Primary),
        ),
      ),
    );

    try {
      // Get current user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('user_id');

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('User not authenticated. Please login again.');
      }

      print('🔍 Current User ID: $currentUserId');

      // Fetch community users to get current user's role
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      await provider.fetchCommunityUsers(widget.communityId);

      // Find current user in the members list
      final membersList = (provider.communityUsers['data'] as List<dynamic>?) ?? [];
      String userRole = 'member';
      bool isAdmin = false;
      bool isMember = false;

      print('🔍 Searching for user in ${membersList.length} members...');

      for (var member in membersList) {
        final userId = member['userId']?['_id'] as String?;
        print('   Checking member: $userId');

        if (userId == currentUserId) {
          userRole = member['userRole'] as String? ?? 'member';
          isAdmin = member['isAdmin'] as bool? ?? false;
          isMember = true;

          print('✅ User found!');
          print('   - Role: $userRole');
          print('   - Is Admin: $isAdmin');
          break;
        }
      }

      if (!isMember) {
        throw Exception('You are not a member of this community');
      }

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        // Navigate to dashboard with correct role
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              communityId: widget.communityId,
              userRole: userRole,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _navigateToDashboard: $e');

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Community Analytics',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Provider.of<CommunityProvider>(context, listen: false)
                  .fetchCommunityHierarchyStats(widget.communityId);
            },
            icon: const Icon(Icons.refresh, color: Colors.black87, size: 20),
          ),
        ],
      ),
      body: Consumer<CommunityProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingHierarchyStats) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Primary),
                    strokeWidth: 2.5,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Loading community statistics...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.hierarchyStatsError != null) {
            return _buildErrorState(provider.hierarchyStatsError!);
          }

          final statsData = provider.communityHierarchyStats['data'] as Map<String, dynamic>? ?? {};

          if (statsData.isEmpty) {
            return _buildEmptyState();
          }

          // Start animation when data is loaded
          _animationController.forward();

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchCommunityHierarchyStats(widget.communityId);
            },
            color: Primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(statsData),

                  // Box 1: Communities, Services & Campaigns
                  _buildGroupedStatsBox(
                    title: 'Resources',
                    primaryColor: const Color(0xFF8B5CF6),
                    index: 0,
                    items: [
                      {
                        'title': 'Communities',
                        'value': (statsData['totalCommunities'] ?? 0).toString(),
                        'icon': Icons.business,
                        'color': const Color(0xFF3B82F6),
                        'onTap': _navigateToCommunities,
                      },
                      {
                        'title': 'Services',
                        'value': (statsData['totalServices'] ?? 0).toString(),
                        'icon': Icons.business_center,
                        'color': const Color(0xFFF59E0B),
                        'onTap': _navigateToServices,
                      },
                      {
                        'title': 'Campaigns',
                        'value': (statsData['totalCampaigns'] ?? 0).toString(),
                        'icon': Icons.campaign,
                        'color': const Color(0xFFEC4899),
                        'onTap': _navigateToCampaigns,
                      },
                    ],
                  ),

                  // Box 2: Dashboard & Users
                  _buildGroupedStatsBox(
                    title: 'Management',
                    primaryColor: const Color(0xFF10B981),
                    index: 1,
                    items: [
                      {
                        'title': 'Dashboard',
                        'value': 'View',
                        'icon': Icons.dashboard,
                        'color': const Color(0xFF6366F1),
                        'onTap': _navigateToDashboard,
                      },
                      {
                        'title': 'Active Users',
                        'value': (statsData['totalUsers'] ?? 0).toString(),
                        'icon': Icons.people,
                        'color': const Color(0xFF10B981),
                        'onTap': _navigateToUsers,
                      },
                    ],
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}