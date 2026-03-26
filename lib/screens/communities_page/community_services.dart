import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/communities_provider.dart';
import '../services_page/booking_screen.dart';
import '../services_page/create_service_screen.dart';
import '../services_page/my_services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ServiceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> service;

  const ServiceDetailScreen({super.key, required this.service});

  bool _isBase64(String str) {
    try {
      final base64Str = str.contains(',') ? str.split(',').last : str;
      base64Decode(base64Str);
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _buildServiceImage() {
    if (service['image'] != null &&
        (service['image'] as String).isNotEmpty &&
        _isBase64(service['image'])) {
      try {
        final base64Str = service['image'].contains(',')
            ? service['image'].split(',').last
            : service['image'];
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            base64Decode(base64Str),
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imagePlaceholder(full: true),
          ),
        );
      } catch (_) {
        return _imagePlaceholder(full: true);
      }
    }
    return _imagePlaceholder(full: true);
  }

  Widget _imagePlaceholder({bool full = false}) {
    return Container(
      width: full ? double.infinity : 62,
      height: full ? 200 : 62,
      decoration: BoxDecoration(
        color: Primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(full ? 14 : 10),
      ),
      child: Icon(
        Icons.business_center_outlined,
        color: Primary.withOpacity(0.4),
        size: full ? 52 : 26,
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<_DetailRow> rows,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: Primary, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFFF0F0F4)),
          const SizedBox(height: 10),
          ...rows.map((row) => _buildDetailRow(row)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(_DetailRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(row.icon, size: 13, color: Primary.withOpacity(0.6)),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              row.label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFAAAAAA),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              style: TextStyle(
                fontSize: 12,
                color: row.valueColor ?? const Color(0xFF1A1A2E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCommunityService =
    (service['serviceProvider']?.toString().toLowerCase() ?? '')
        .contains('community');
    final isActive = service['status']?.toString() == 'ACTIVE';
    final availableDays =
        (service['availableDays'] as List<dynamic>?)?.cast<String>() ?? [];
    final cost = service['cost']?.toString() ?? '0';
    final currency = service['currency']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          service['name']?.toString() ?? 'Service Details',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEF2)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            _buildServiceImage(),
            const SizedBox(height: 14),

            // Name + description + badges
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                  Text(
                    service['name']?.toString() ?? 'Unnamed Service',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    service['description']?.toString() ??
                        'No description available',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A7A8C),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildChip(
                        '$currency $cost',
                        const Color(0xFF00C48C),
                        const Color(0xFFE6FAF5),
                      ),
                      _buildChip(
                        isCommunityService
                            ? 'Community Service'
                            : 'Member Service',
                        isCommunityService
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFFFF9F43),
                        isCommunityService
                            ? const Color(0xFFF0EEFF)
                            : const Color(0xFFFFF4E6),
                      ),
                      _buildChip(
                        isActive ? 'Active' : 'Inactive',
                        isActive
                            ? const Color(0xFF00C48C)
                            : const Color(0xFFFF6B6B),
                        isActive
                            ? const Color(0xFFE6FAF5)
                            : const Color(0xFFFFF0F0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Category
            _buildSection(
              title: 'Category & Classification',
              icon: Icons.category_outlined,
              rows: [
                _DetailRow(Icons.folder_outlined, 'Category',
                    service['category']?.toString() ?? 'N/A'),
                _DetailRow(Icons.layers_outlined, 'Subcategory',
                    service['subCategory']?.toString() ?? 'N/A'),
              ],
            ),

            // Pricing
            _buildSection(
              title: 'Pricing & Capacity',
              icon: Icons.monetization_on_outlined,
              rows: [
                _DetailRow(Icons.attach_money_rounded, 'Cost Per',
                    service['costPer']?.toString() ?? 'N/A'),
                _DetailRow(Icons.people_outline_rounded, 'Capacity',
                    service['capacity']?.toString() ?? 'N/A'),
                _DetailRow(Icons.currency_exchange_outlined, 'Currency',
                    service['currency']?.toString() ?? 'N/A'),
              ],
            ),

            // Schedule
            _buildSection(
              title: 'Schedule & Availability',
              icon: Icons.schedule_outlined,
              rows: [
                _DetailRow(
                    Icons.calendar_today_outlined,
                    'Available Days',
                    availableDays.isNotEmpty
                        ? availableDays.join(', ')
                        : 'N/A'),
                _DetailRow(
                    Icons.access_time_rounded,
                    'Opening Hours',
                    '${service['openHourFrom']?.toString() ?? 'N/A'} – ${service['openHourEnd']?.toString() ?? 'N/A'}'),
              ],
            ),

            // Location
            _buildSection(
              title: 'Location & Provider',
              icon: Icons.location_on_outlined,
              rows: [
                _DetailRow(Icons.place_outlined, 'Location',
                    service['location']?.toString() ?? 'N/A'),
                _DetailRow(Icons.person_outline_rounded, 'Provider',
                    service['serviceProvider']?.toString() ?? 'N/A'),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingScreen(
                      serviceId: service['_id']?.toString() ?? '',
                      serviceName:
                      service['name']?.toString() ?? 'Service',
                      costPerSlot: service['cost'] ?? 0,
                      currency:
                      service['currency']?.toString() ?? 'INR',
                      maxSlots: service['capacity'] ?? 10,
                      serviceImage:
                      service['image']?.toString() ?? '',
                      location:
                      service['location']?.toString() ?? '',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: const Text(
                'Book Now',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY SERVICES SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class CommunityServicesScreen extends StatefulWidget {
  final String communityId;

  const CommunityServicesScreen({super.key, required this.communityId});

  @override
  State<CommunityServicesScreen> createState() =>
      _CommunityServicesScreenState();
}

class _CommunityServicesScreenState extends State<CommunityServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CommunityProvider>(context, listen: false)
          .fetchCommunityServices(widget.communityId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<dynamic> _filterServices(
      List<dynamic> services, bool isCommunityTab) {
    return services.where((service) {
      final sp =
          service['serviceProvider']?.toString().toLowerCase() ?? '';
      if (isCommunityTab) {
        return sp == 'community' || sp.contains('community');
      } else {
        return sp != 'community' &&
            !sp.contains('community') &&
            sp.isNotEmpty &&
            sp != 'n/a';
      }
    }).toList();
  }

  bool _isBase64(String str) {
    try {
      final base64Str = str.contains(',') ? str.split(',').last : str;
      base64Decode(base64Str);
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _buildServiceImage(Map<String, dynamic> service) {
    const double size = 62;
    if (service['image'] != null &&
        (service['image'] as String).isNotEmpty &&
        _isBase64(service['image'])) {
      try {
        final base64Str = service['image'].contains(',')
            ? service['image'].split(',').last
            : service['image'];
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(base64Str),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imagePlaceholder(size),
          ),
        );
      } catch (_) {
        return _imagePlaceholder(size);
      }
    }
    return _imagePlaceholder(size);
  }

  Widget _imagePlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.business_center_outlined,
          color: Primary.withOpacity(0.4), size: 26),
    );
  }

  Widget _buildChip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final cost = service['cost']?.toString() ?? '0';
    final currency = service['currency']?.toString() ?? '';
    final isCommunity =
    (service['serviceProvider']?.toString().toLowerCase() ?? '')
        .contains('community');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceDetailScreen(service: service),
          ),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildServiceImage(service),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      service['name']?.toString() ?? 'Unnamed Service',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Description
                    Text(
                      service['description']?.toString() ??
                          'No description',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A7A8C),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Chips + Book button
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildChip(
                                '$currency $cost',
                                const Color(0xFF00C48C),
                                const Color(0xFFE6FAF5),
                              ),
                              _buildChip(
                                isCommunity ? 'Community' : 'Member',
                                const Color(0xFF6C63FF),
                                const Color(0xFFF0EEFF),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingScreen(
                                serviceId:
                                service['_id']?.toString() ?? '',
                                serviceName:
                                service['name']?.toString() ??
                                    'Service',
                                costPerSlot: service['cost'] ?? 0,
                                currency: service['currency']
                                    ?.toString() ??
                                    'INR',
                                maxSlots: service['capacity'] ?? 10,
                                serviceImage:
                                service['image']?.toString() ?? '',
                                location:
                                service['location']?.toString() ??
                                    '',
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Book',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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
    );
  }

  Widget _buildTabContent(
      CommunityProvider provider, bool isCommunityTab) {
    final services =
        provider.communityServices['services'] as List<dynamic>? ?? [];
    final filtered = _filterServices(services, isCommunityTab);
    final tabName =
    isCommunityTab ? 'Community Services' : 'Member Services';

    return RefreshIndicator(
      onRefresh: () async =>
          provider.fetchCommunityServices(widget.communityId),
      color: Primary,
      child: provider.isLoadingServices
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Primary),
          strokeWidth: 2,
        ),
      )
          : provider.servicesError != null
          ? _buildErrorState(provider)
          : filtered.isEmpty
          ? _buildEmptyState(isCommunityTab, tabName)
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        itemCount: filtered.length,
        itemBuilder: (_, index) =>
            _buildServiceCard(filtered[index]),
      ),
    );
  }

  Widget _buildErrorState(CommunityProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F0), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  size: 32, color: Color(0xFFFF6B6B)),
            ),
            const SizedBox(height: 12),
            Text(
              provider.servicesError ?? 'Something went wrong',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A7A8C),
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  provider.fetchCommunityServices(widget.communityId),
              child: const Text('Retry',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCommunityTab, String tabName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Primary.withOpacity(0.06),
                  shape: BoxShape.circle),
              child: Icon(
                isCommunityTab
                    ? Icons.business_center_outlined
                    : Icons.people_outline_rounded,
                size: 36,
                color: Primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No $tabName',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 4),
            Text(
              isCommunityTab
                  ? 'No services added by the community yet'
                  : 'No services added by members yet',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFFAAAAAA)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Community Services',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
                letterSpacing: 0.2,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyServicesScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'My Services',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(49),
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFEEEEF2)),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Primary,
                    indicatorWeight: 2.5,
                    labelColor: Primary,
                    unselectedLabelColor: const Color(0xFFAAAAAA),
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_center_outlined,
                                size: 15),
                            SizedBox(width: 6),
                            Text('Community'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded,
                                size: 15),
                            SizedBox(width: 6),
                            Text('Members'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent(provider, true),
              _buildTabContent(provider, false),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateServiceScreen(
                    communityId: widget.communityId),
              ),
            ),
            backgroundColor: Primary,
            elevation: 4,
            child: const Icon(Icons.add_rounded,
                color: Colors.white, size: 26),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow(this.icon, this.label, this.value, {this.valueColor});
}