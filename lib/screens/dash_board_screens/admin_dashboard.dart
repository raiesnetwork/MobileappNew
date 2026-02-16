import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/dash_board_provider.dart';
import '../../constants/constants.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String communityId;

  const AdminDashboardScreen({super.key, required this.communityId});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    await provider.fetchAdminDashboard(communityId: widget.communityId);
    // Optionally load leakage analysis
    try {
      await provider.fetchLeakageAnalysis(communityId: widget.communityId);
    } catch (e) {
      print('Leakage analysis fetch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final dashboardData = provider.adminDashboardData;
    final leakageData = provider.leakageAnalysisData;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: provider.isLoading && dashboardData.isEmpty
          ? _buildLoadingState()
          : provider.error != null
          ? _buildErrorState(provider.error!)
          : CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),

          // Top Cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: _buildTopCards(dashboardData),
          ),

          // Student Section Summary
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _buildStudentSection(dashboardData),
            ),
          ),

          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Primary,
                indicatorWeight: 3,
                labelColor: Primary,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'OVERVIEW'),
                  Tab(text: 'CAMPAIGNS'),
                  Tab(text: 'ANALYTICS'),
                ],
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(dashboardData),
                _buildCampaignsTab(dashboardData),
                _buildAnalyticsTab(dashboardData, leakageData),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // App Bar
  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Primary,
                Primary.withOpacity(0.85),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comprehensive analytics and insights',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadDashboardData,
        ),
      ],
    );
  }

  // Top Cards
  Widget _buildTopCards(Map<String, dynamic> dashboardData) {
    final topCards = dashboardData['topCards'] as List<dynamic>? ?? [];

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index >= topCards.length) return const SizedBox();

          final card = topCards[index] as Map<String, dynamic>;
          final title = card['title'] ?? '';
          final value = card['value']?.toString() ?? '0';
          final change = card['change']?.toString() ?? '';

          return _buildTopCard(
            title,
            value,
            change,
            _getCardIcon(title),
            _getCardColor(index),
          );
        },
        childCount: topCards.length,
      ),
    );
  }

  Widget _buildTopCard(String title, String value, String change, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (change.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_upward, color: Colors.green, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        change,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Student Section
  Widget _buildStudentSection(Map<String, dynamic> dashboardData) {
    final studentSection = dashboardData['studentSection'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1),
            const Color(0xFF6366F1).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Community Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStudentStat(
                  'Users',
                  (studentSection['totalUsers'] ?? 0).toString(),
                  Icons.people,
                ),
              ),
              Expanded(
                child: _buildStudentStat(
                  'Services',
                  (studentSection['totalServices'] ?? 0).toString(),
                  Icons.business_center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStudentStat(
                  'Campaigns',
                  (studentSection['totalCampaigns'] ?? 0).toString(),
                  Icons.campaign,
                ),
              ),
              Expanded(
                child: _buildStudentStat(
                  'Communities',
                  (studentSection['totalSubCommunities'] ?? 0).toString(),
                  Icons.account_tree,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // Overview Tab
  Widget _buildOverviewTab(Map<String, dynamic> dashboardData) {
    final salesOverview = dashboardData['salesOverview'] as List<dynamic>? ?? [];
    final communityGrowth = dashboardData['communityGrowth'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Sales Overview', Icons.trending_up, Colors.green),
            const SizedBox(height: 16),
            if (salesOverview.isNotEmpty)
              _buildSalesChart(salesOverview)
            else
              _buildEmptyState('No sales data available', Icons.show_chart),

            const SizedBox(height: 32),

            _buildSectionHeader('Community Growth', Icons.group_add, Colors.blue),
            const SizedBox(height: 16),
            if (communityGrowth.isNotEmpty)
              _buildGrowthChart(communityGrowth)
            else
              _buildEmptyState('No growth data available', Icons.trending_up),
          ],
        ),
      ),
    );
  }

  // Campaigns Tab
  Widget _buildCampaignsTab(Map<String, dynamic> dashboardData) {
    final campaignPerformance = dashboardData['campaignPerformance'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Campaign Performance', Icons.assessment, Primary),
            const SizedBox(height: 16),
            if (campaignPerformance.isNotEmpty)
              _buildCampaignPerformance(campaignPerformance)
            else
              _buildEmptyState('No campaign data available', Icons.campaign),
          ],
        ),
      ),
    );
  }

  // Analytics Tab
  Widget _buildAnalyticsTab(Map<String, dynamic> dashboardData, Map<String, dynamic> leakageData) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leakageData.isNotEmpty) ...[
              _buildSectionHeader('Activation Metrics', Icons.analytics, Colors.purple),
              const SizedBox(height: 16),
              _buildActivationMetrics(leakageData),

              const SizedBox(height: 32),

              _buildSectionHeader('Revenue Quadrants', Icons.grid_view, Colors.indigo),
              const SizedBox(height: 16),
              _buildRevenueQuadrants(leakageData),
            ] else
              _buildEmptyState('No analytics data available', Icons.analytics),
          ],
        ),
      ),
    );
  }

  // Sales Chart
  Widget _buildSalesChart(List<dynamic> salesData) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= salesData.length) return const Text('');
                  final data = salesData[value.toInt()] as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      data['month'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    '\$${(value / 1000).toStringAsFixed(0)}k',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (salesData.length - 1).toDouble(),
          minY: 0,
          maxY: _getMaxValue(salesData, 'sales') * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: salesData.asMap().entries.map((entry) {
                final data = entry.value as Map<String, dynamic>;
                return FlSpot(
                  entry.key.toDouble(),
                  (data['sales'] ?? 0).toDouble(),
                );
              }).toList(),
              isCurved: true,
              gradient: LinearGradient(
                colors: [Colors.green, Colors.green.shade400],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: Colors.green,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.3),
                    Colors.green.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Growth Chart
  Widget _buildGrowthChart(List<dynamic> growthData) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxValue(growthData, 'members') * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= growthData.length) return const Text('');
                  final data = growthData[value.toInt()] as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      data['month'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          barGroups: growthData.asMap().entries.map((entry) {
            final data = entry.value as Map<String, dynamic>;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (data['members'] ?? 0).toDouble(),
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blue.shade400],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // Campaign Performance
  Widget _buildCampaignPerformance(List<dynamic> campaigns) {
    final total = campaigns.fold<double>(
      0,
          (sum, item) => sum + ((item as Map<String, dynamic>)['value'] ?? 0).toDouble(),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: campaigns.map((campaign) {
          final data = campaign as Map<String, dynamic>;
          final name = data['name'] ?? '';
          final value = (data['value'] ?? 0).toDouble();
          final color = _parseColor(data['color']);
          final percentage = total > 0 ? (value / total * 100) : 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${value.toInt()} (${percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Activation Metrics
  Widget _buildActivationMetrics(Map<String, dynamic> leakageData) {
    final activationRate = leakageData['activationRate'] ?? '0%';
    final activeMembers = leakageData['activeMembers'] ?? 0;
    final totalMembers = leakageData['totalMembers'] ?? 0;
    final internalizationRate = leakageData['internalizationRate'] ?? '0%';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Activation Rate',
                activationRate.toString(),
                Icons.people_alt,
                Colors.green,
                '$activeMembers / $totalMembers active',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Internalization',
                internalizationRate.toString(),
                Icons.trending_up,
                Colors.blue,
                'Revenue from known users',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Revenue Quadrants
  Widget _buildRevenueQuadrants(Map<String, dynamic> leakageData) {
    final revenueQuadrants = leakageData['revenueQuadrants'] as Map<String, dynamic>? ?? {};
    final quadrants = revenueQuadrants['quadrants'] as Map<String, dynamic>? ?? {};
    final quadrantPercentages = leakageData['quadrantPercentages'] as Map<String, dynamic>? ?? {};

    final quadrantData = [
      {
        'name': 'Known Local',
        'value': quadrants['knownLocal'] ?? 0,
        'percentage': quadrantPercentages['knownLocal'] ?? '0',
        'color': Colors.green,
      },
      {
        'name': 'Unknown Local',
        'value': quadrants['unknownLocal'] ?? 0,
        'percentage': quadrantPercentages['unknownLocal'] ?? '0',
        'color': Colors.orange,
      },
      {
        'name': 'Known Global',
        'value': quadrants['knownGlobal'] ?? 0,
        'percentage': quadrantPercentages['knownGlobal'] ?? '0',
        'color': Colors.blue,
      },
      {
        'name': 'Unknown Global',
        'value': quadrants['unknownGlobal'] ?? 0,
        'percentage': quadrantPercentages['unknownGlobal'] ?? '0',
        'color': Colors.red,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: quadrantData.map((quadrant) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: quadrant['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    quadrant['name'] as String,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Text(
                  '\$${quadrant['value']} (${quadrant['percentage']}%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Section Header
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // Empty State
  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Loading State
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Primary),
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Loading dashboard...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // Error State
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed to Load Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods
  IconData _getCardIcon(String title) {
    if (title.contains('Revenue')) return Icons.attach_money;
    if (title.contains('Members')) return Icons.people;
    if (title.contains('Conversion')) return Icons.trending_up;
    if (title.contains('Campaigns')) return Icons.campaign;
    return Icons.analytics;
  }

  Color _getCardColor(int index) {
    final colors = [Colors.green, Colors.blue, Colors.orange, Primary];
    return colors[index % colors.length];
  }

  Color _parseColor(dynamic colorString) {
    if (colorString == null) return Primary;

    try {
      String colorStr = colorString.toString().replaceAll('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (e) {
      return Primary;
    }
  }

  double _getMaxValue(List<dynamic> data, String key) {
    if (data.isEmpty) return 100;

    return data.fold<double>(0, (max, item) {
      final value = ((item as Map<String, dynamic>)[key] ?? 0).toDouble();
      return value > max ? value : max;
    });
  }
}

// Custom TabBar Delegate
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
