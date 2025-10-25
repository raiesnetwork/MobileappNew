import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/communities_provider.dart';

import '../services_page/create_service_screen.dart';
import '../services_page/my_services.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> service;

  const ServiceDetailScreen({super.key, required this.service});

  Widget _buildServiceImage(Map<String, dynamic> service) {
    bool isBase64(String str) {
      try {
        final base64Str = str.contains(',') ? str.split(',').last : str;
        base64Decode(base64Str);
        return true;
      } catch (e) {
        return false;
      }
    }

    if (service['image'] != null && service['image'].isNotEmpty && isBase64(service['image'])) {
      try {
        final base64Str = service['image'].contains(',')
            ? service['image'].split(',').last
            : service['image'];
        final imageData = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            imageData,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultImage(),
          ),
        );
      } catch (e) {
        return _buildDefaultImage();
      }
    } else {
      return _buildDefaultImage();
    }
  }

  Widget _buildDefaultImage() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Primary.withOpacity(0.1), Primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Primary.withOpacity(0.2)),
      ),
      child: Icon(
        Icons.business_center,
        color: Primary.withOpacity(0.7),
        size: 64,
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Primary, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w500,
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
    (service['serviceProvider']?.toString().toLowerCase() ?? '').contains('community');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          service['name']?.toString() ?? 'Service Details',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Image
            _buildServiceImage(service),
            const SizedBox(height: 20),

            // Service Header Info
            _buildInfoCard(
              title: 'Service Information',
              icon: Icons.info_outline,
              children: [
                Text(
                  service['name']?.toString() ?? 'Unnamed Service',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  service['description']?.toString() ?? 'No description available',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 14),
                // Improved badges layout
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Cost Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_money, size: 14, color: Colors.green),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${service['cost']?.toString() ?? '0'} ${service['currency']?.toString() ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Provider Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCommunityService
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCommunityService
                              ? Colors.blue.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        isCommunityService ? 'Community Service' : 'Member Service',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCommunityService ? Colors.blue : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Category & Details
            _buildInfoCard(
              title: 'Category & Classification',
              icon: Icons.category,
              children: [
                _buildDetailRow(
                  label: 'Category',
                  value: service['category']?.toString() ?? 'N/A',
                  icon: Icons.folder_outlined,
                ),
                _buildDetailRow(
                  label: 'Subcategory',
                  value: service['subCategory']?.toString() ?? 'N/A',
                  icon: Icons.subdirectory_arrow_right,
                ),
                _buildDetailRow(
                  label: 'Status',
                  value: service['status']?.toString() ?? 'N/A',
                  valueColor: service['status']?.toString() == 'ACTIVE' ? Colors.green : Colors.red,
                  icon: Icons.toggle_on,
                ),
              ],
            ),

            // Pricing & Capacity
            _buildInfoCard(
              title: 'Pricing & Capacity',
              icon: Icons.monetization_on,
              children: [
                _buildDetailRow(
                  label: 'Cost Per',
                  value: service['costPer']?.toString() ?? 'N/A',
                  icon: Icons.schedule,
                ),
                _buildDetailRow(
                  label: 'Capacity',
                  value: service['capacity']?.toString() ?? 'N/A',
                  icon: Icons.group,
                ),
                _buildDetailRow(
                  label: 'Currency',
                  value: service['currency']?.toString() ?? 'N/A',
                  icon: Icons.currency_exchange,
                ),
              ],
            ),

            // Schedule & Availability
            _buildInfoCard(
              title: 'Schedule & Availability',
              icon: Icons.access_time,
              children: [
                _buildDetailRow(
                  label: 'Available Days',
                  value: (service['availableDays'] as List<dynamic>?)?.join(', ') ?? 'N/A',
                  icon: Icons.calendar_today,
                ),
                _buildDetailRow(
                  label: 'Opening Hours',
                  value: '${service['openHourFrom']?.toString() ?? 'N/A'} - ${service['openHourEnd']?.toString() ?? 'N/A'}',
                  icon: Icons.access_time_filled,
                ),
              ],
            ),

            // Location & Provider
            _buildInfoCard(
              title: 'Location & Provider',
              icon: Icons.location_on,
              children: [
                _buildDetailRow(
                  label: 'Location',
                  value: service['location']?.toString() ?? 'N/A',
                  icon: Icons.place,
                ),
                _buildDetailRow(
                  label: 'Service Provider',
                  value: service['serviceProvider']?.toString() ?? 'N/A',
                  icon: Icons.person,
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // Add contact/book functionality here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact service provider feature coming soon!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Contact Provider',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  // Add bookmark functionality here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bookmark feature coming soon!'),
                    ),
                  );
                },
                icon: const Icon(Icons.bookmark_outline, color: Primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityServicesScreen extends StatefulWidget {
  final String communityId;

  const CommunityServicesScreen({super.key, required this.communityId});

  @override
  State<CommunityServicesScreen> createState() => _CommunityServicesScreenState();
}

class _CommunityServicesScreenState extends State<CommunityServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🚀 Initiating fetchCommunityServices with communityId: ${widget.communityId}');
      // Changed to use CommunityProvider instead of ServicesProvider
      Provider.of<CommunityProvider>(context, listen: false)
          .fetchCommunityServices(widget.communityId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Filter services based on service provider type
  List<dynamic> _filterServices(List<dynamic> services, bool isCommunityTab) {
    print('🔍 Filtering services - Total: ${services.length}, isCommunityTab: $isCommunityTab');

    final filtered = services.where((service) {
      final serviceProvider = service['serviceProvider']?.toString().toLowerCase() ?? '';
      print('  Service: ${service['name']} | Provider: $serviceProvider');

      if (isCommunityTab) {
        final isMatch = serviceProvider == 'community' || serviceProvider.contains('community');
        print('    Community tab match: $isMatch');
        return isMatch;
      } else {
        final isMatch = serviceProvider != 'community' &&
            !serviceProvider.contains('community') &&
            serviceProvider.isNotEmpty &&
            serviceProvider != 'n/a';
        print('    Member tab match: $isMatch');
        return isMatch;
      }
    }).toList();

    print('🔍 Filtered result: ${filtered.length} services');
    return filtered;
  }

  // Debug method to print service information - Updated for CommunityProvider
  void _debugPrintServiceInfo(CommunityProvider provider) {
    if (kDebugMode) {
      print('=== DEBUG SERVICE INFO ===');
      print('Loading: ${provider.isLoadingServices}');
      print('Has Error: ${provider.servicesError != null}');
      print('Message: ${provider.servicesError ?? "No error"}');

      final services = provider.communityServices['services'] as List<dynamic>? ?? [];
      print('Services count: ${services.length}');

      if (services.isNotEmpty) {
        print('First service: ${services[0]}');
        print('Service provider types:');
        for (var service in services) {
          print('  - Name: ${service['name']} | Provider: ${service['serviceProvider']}');
        }
      }
      print('========================');
    }
  }

  Widget _buildServiceImage(Map<String, dynamic> service) {
    // Helper function to check if a string is a valid Base64
    bool isBase64(String str) {
      try {
        final base64Str = str.contains(',') ? str.split(',').last : str;
        base64Decode(base64Str);
        return true;
      } catch (e) {
        return false;
      }
    }

    if (service['image'] != null && service['image'].isNotEmpty && isBase64(service['image'])) {
      try {
        final base64Str = service['image'].contains(',')
            ? service['image'].split(',').last
            : service['image'];
        final imageData = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            imageData,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultImage(),
          ),
        );
      } catch (e) {
        return _buildDefaultImage();
      }
    } else {
      return _buildDefaultImage();
    }
  }

  Widget _buildDefaultImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Primary.withOpacity(0.1), Primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Primary.withOpacity(0.2)),
      ),
      child: Icon(
        Icons.business_center,
        color: Primary.withOpacity(0.7),
        size: 32,
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, int index) {
    final isCommunityService =
    (service['serviceProvider']?.toString().toLowerCase() ?? '').contains('community');

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailScreen(service: service),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Primary.withOpacity(0.05),
                Primary.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              _buildServiceImage(service),
              const SizedBox(width: 16),
              // Basic Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      service['name']?.toString() ?? 'Unnamed Service',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Description
                    Text(
                      service['description']?.toString() ?? 'No description available',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Cost and Provider Badge Row - Fixed overflow
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Cost
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_money, size: 12, color: Colors.green),
                                const SizedBox(width: 2),
                                Text(
                                  '${service['cost']?.toString() ?? '0'} ${service['currency']?.toString() ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Provider Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCommunityService
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCommunityService
                                    ? Colors.blue.withOpacity(0.3)
                                    : Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              isCommunityService ? 'Community' : 'Member',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isCommunityService ? Colors.blue : Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // View Details Arrow
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Primary.withOpacity(0.7),
                            size: 14,
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
      ),
    );
  }

  Widget _buildTabContent(CommunityProvider provider, bool isCommunityTab) {
    // Debug print service info
    _debugPrintServiceInfo(provider);

    // Get services from communityServices map
    final services = provider.communityServices['services'] as List<dynamic>? ?? [];
    final filteredServices = _filterServices(services, isCommunityTab);
    final tabName = isCommunityTab ? 'Community Services' : 'Member Services';

    print('🎨 Building tab content for $tabName');
    print('📊 Provider state - Loading: ${provider.isLoadingServices}, Error: ${provider.servicesError != null}');
    print('📦 Total services: ${services.length}, Filtered: ${filteredServices.length}');

    return RefreshIndicator(
      onRefresh: () async {
        print('🔄 Pull to refresh triggered');
        await provider.fetchCommunityServices(widget.communityId);
      },
      color: Primary,
      child: provider.isLoadingServices
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Primary),
        ),
      )
          : provider.servicesError != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 12),
            Text(
              provider.servicesError!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                print('🔄 Retry button pressed');
                provider.fetchCommunityServices(widget.communityId);
              },
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      )
          : filteredServices.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCommunityTab ? Icons.business : Icons.people_outline,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No $tabName Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCommunityTab
                  ? 'No services provided by the community yet'
                  : 'No services provided by community members yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filteredServices.length,
        itemBuilder: (context, index) {
          final service = filteredServices[index];
          return _buildServiceCard(service, index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Changed Consumer to use CommunityProvider instead of ServicesProvider
    return Consumer<CommunityProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            title: const Text(
              'Community Services',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Primary,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 2,
            shadowColor: Colors.grey.withOpacity(0.2),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyServicesScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: const Text(
                    'My Services',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Primary,
              labelColor: Primary,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business, size: 16),
                      SizedBox(width: 6),
                      Text('Community'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people, size: 16),
                      SizedBox(width: 6),
                      Text('Members'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent(provider, true), // Community Services tab
              _buildTabContent(provider, false), // Member Services tab
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateServiceScreen(communityId: widget.communityId),
                ),
              );
            },
            backgroundColor: Primary,
            elevation: 6,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }
}