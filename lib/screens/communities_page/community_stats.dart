import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/communities_provider.dart';
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

  Widget _buildStatsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int index,
    VoidCallback? onTap,
  }) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _fadeAnimation.value)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: EdgeInsets.only(
                  bottom: 16,
                  top: index == 0 ? 0 : 0,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.1),
                      color.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              value,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: color,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Trailing Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          onTap != null ? Icons.arrow_forward_ios : Icons.trending_up,
                          color: color,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
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
                      Text(
                        'Community Analytics',
                        style: const TextStyle(
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

                  _buildStatsCard(
                    title: 'Total Communities',
                    value: (statsData['totalCommunities'] ?? 0).toString(),
                    subtitle: 'Communities in hierarchy',
                    icon: Icons.business,
                    color: const Color(0xFF3B82F6),
                    index: 0,
                    onTap: _navigateToCommunities,
                  ),

                  _buildStatsCard(
                    title: 'Active Users',
                    value: (statsData['totalUsers'] ?? 0).toString(),
                    subtitle: 'Registered members',
                    icon: Icons.people,
                    color: const Color(0xFF10B981),
                    index: 1,
                    onTap: _navigateToUsers,
                  ),

                  _buildStatsCard(
                    title: 'Available Services',
                    value: (statsData['totalServices'] ?? 0).toString(),
                    subtitle: 'Services offered',
                    icon: Icons.business_center,
                    color: const Color(0xFFF59E0B),
                    index: 2,
                    onTap: _navigateToServices,
                  ),

                  _buildStatsCard(
                    title: 'Active Campaigns',
                    value: (statsData['totalCampaigns'] ?? 0).toString(),
                    subtitle: 'Running campaigns',
                    icon: Icons.campaign,
                    color: const Color(0xFF8B5CF6),
                    index: 3,
                    onTap: _navigateToCampaigns,
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