import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/service_provider.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  // Track expanded state for each service card
  final Set<String> _expandedCards = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ServicesProvider>(context, listen: false);
      provider.fetchMyServices();
    });
  }

  Widget _buildServiceCard({
    String? serviceId,
    required String name,
    String? image,
    required String description,
    required String category,
    required String subCategory,
    required double cost,
    required int capacity,
    required String currency,
    required List<String> availableDays,
    required String location,
    required String status,
    required String costPer,
    required String openHourFrom,
    required String openHourEnd,
  }) {
    final isExpanded = _expandedCards.contains(serviceId);
    final isCommunityService = serviceId?.toLowerCase().contains('community') ?? false;

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
          setState(() {
            if (isExpanded) {
              _expandedCards.remove(serviceId);
            } else {
              _expandedCards.add(serviceId!);
            }
          });
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Collapsed View - Always visible
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Image
                  _buildServiceImage(image),
                  const SizedBox(width: 16),

                  // Service Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Service Name
                        Text(
                          name,
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
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.3,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded ? null : TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),

                        // Cost and Provider Badge Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Cost Badge
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
                                      '$cost $currency',
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
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status == 'ACTIVE'
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: status == 'ACTIVE'
                                        ? Colors.blue.withOpacity(0.3)
                                        : Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  status == 'ACTIVE' ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: status == 'ACTIVE' ? Colors.blue : Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Expand Arrow
                              Icon(
                                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: Primary.withOpacity(0.7),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Expanded Details - Only visible when expanded
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        serviceId: serviceId,
                        status: status,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildMenuButton(
                      context: context,
                      serviceId: serviceId!,
                      name: name,
                      description: description,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Service Details Grid
                _buildDetailsSection(
                  category: category,
                  subCategory: subCategory,
                  cost: cost,
                  currency: currency,
                  costPer: costPer,
                  capacity: capacity,
                  availableDays: availableDays,
                  location: location,
                  openHourFrom: openHourFrom,
                  openHourEnd: openHourEnd,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceImage(String? image) {
    if (image != null && image.isNotEmpty) {
      // Check if it's a URL (starts with http:// or https://)
      if (image.startsWith('http://') || image.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            image,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                    valueColor: AlwaysStoppedAnimation<Color>(Primary),
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('Error loading image: $error');
              return _buildDefaultImagePlaceholder();
            },
          ),
        );
      } else {
        // If it's not a URL, show default placeholder
        return _buildDefaultImagePlaceholder();
      }
    } else {
      return _buildDefaultImagePlaceholder();
    }
  }

  Widget _buildDefaultImagePlaceholder() {
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

  Widget _buildActionButton({String? serviceId, required String status}) {
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        final isActive = status == 'ACTIVE';
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.red[50] : Colors.green[50],
            foregroundColor: isActive ? Colors.red[700] : Colors.green[700],
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isActive ? Colors.red[200]! : Colors.green[200]!,
                width: 1,
              ),
            ),
          ),
          onPressed: provider.isServiceActionLoading
              ? null
              : () => _handleServiceToggle(provider, serviceId!, isActive),
          icon: Icon(
            isActive ? Icons.pause : Icons.play_arrow,
            size: 18,
          ),
          label: Text(
            isActive ? 'Deactivate' : 'Activate',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String serviceId,
    required String name,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: const [
                Icon(Icons.edit, size: 18, color: Primary),
                SizedBox(width: 8),
                Text('Edit', style: TextStyle(color: Primary, fontSize: 14)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: const [
                Icon(Icons.delete, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14)),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          final provider = Provider.of<ServicesProvider>(context, listen: false);
          if (value == 'edit') {
            _showEditServiceDialog(context, serviceId, name, description, provider);
          } else if (value == 'delete') {
            _showDeleteConfirmationDialog(context, serviceId, provider);
          }
        },
      ),
    );
  }

  Widget _buildDetailsSection({
    required String category,
    required String subCategory,
    required double cost,
    required String currency,
    required String costPer,
    required int capacity,
    required List<String> availableDays,
    required String location,
    required String openHourFrom,
    required String openHourEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),

        // Details Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 12,
          childAspectRatio: (MediaQuery.of(context).size.width - 80) / 2 / 80,
          children: [
            _buildDetailItem('Category', category, Icons.category),
            _buildDetailItem('Subcategory', subCategory, Icons.subdirectory_arrow_right),
            _buildDetailItem('Cost', '$cost $currency/$costPer', Icons.attach_money),
            _buildDetailItem('Capacity', '$capacity', Icons.people),
            _buildDetailItem('Location', location, Icons.location_on),
            _buildDetailItem('Hours', '$openHourFrom - $openHourEnd', Icons.schedule),
          ],
        ),

        const SizedBox(height: 12),

        // Available Days
        _buildAvailableDays(availableDays),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDays(List<String> availableDays) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Primary),
            const SizedBox(width: 6),
            Text(
              'Available Days',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: availableDays.map((day) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Primary.withOpacity(0.3)),
            ),
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 12,
                color: Primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Future<void> _handleServiceToggle(
      ServicesProvider provider, String serviceId, bool isActive) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isActive ? 'Deactivating service...' : 'Activating service...',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    if (isActive) {
      await provider.deactivateMyService(serviceId);
    } else {
      await provider.activateMyService(serviceId);
    }

    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          provider.serviceActionMessage,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: provider.hasServiceActionError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Edit service dialog
  Future<void> _showEditServiceDialog(
      BuildContext context,
      String serviceId,
      String currentName,
      String currentDescription,
      ServicesProvider provider,
      ) async {
    final nameController = TextEditingController(text: currentName);
    final descriptionController = TextEditingController(text: currentDescription);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Edit Service',
            style: TextStyle(color: Primary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Service Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 14)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Update', style: TextStyle(color: Colors.white, fontSize: 14)),
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Service updated successfully', style: TextStyle(fontSize: 14)),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Delete confirmation dialog
  Future<void> _showDeleteConfirmationDialog(
      BuildContext context,
      String serviceId,
      ServicesProvider provider,
      ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Confirm Delete',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: const Text(
            'Are you sure you want to delete this service? This action cannot be undone.',
            style: TextStyle(fontSize: 14),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 14)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 14)),
              onPressed: () async {
                Navigator.of(context).pop();
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: const [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Deleting service...', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    backgroundColor: Colors.blueGrey,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );

                await provider.deleteService(serviceId: serviceId);

                if (!mounted) return;

                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(provider.myServicesMessage, style: const TextStyle(fontSize: 14)),
                    backgroundColor: provider.hasMyServicesError ? Colors.red : Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            title: const Text(
              'My Services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Primary,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 2,
            centerTitle: true,
            shadowColor: Colors.grey.withOpacity(0.2),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await provider.fetchMyServices();
            },
            color: Primary,
            child: provider.isMyServicesLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Primary),
              ),
            )
                : provider.hasMyServicesError
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
                    provider.myServicesMessage,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => provider.fetchMyServices(),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : provider.myServices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_center_outlined,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No services found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start by adding your first service',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      // Navigate to add service screen (implement as needed)
                    },
                    child: const Text(
                      'Add Service',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(6),
              itemCount: provider.myServices.length,
              itemBuilder: (context, index) {
                final service = provider.myServices[index];
                return _buildServiceCard(
                  serviceId: service['_id']?.toString(),
                  name: service['name']?.toString() ?? 'Unnamed Service',
                  image: service['image']?.toString(),
                  description: service['description']?.toString() ?? 'No description',
                  category: service['category']?.toString() ?? 'N/A',
                  subCategory: service['subCategory']?.toString() ?? 'N/A',
                  cost: (service['cost'] is int
                      ? service['cost'].toDouble()
                      : service['cost'] ?? 0.0) as double,
                  capacity: service['capacity'] as int? ?? 0,
                  currency: service['currency']?.toString() ?? 'N/A',
                  availableDays: List<String>.from(service['availableDays'] ?? []),
                  location: service['location']?.toString() ?? 'N/A',
                  status: service['status']?.toString() ?? 'N/A',
                  costPer: service['costPer']?.toString() ?? 'N/A',
                  openHourFrom: service['openHourFrom']?.toString() ?? 'N/A',
                  openHourEnd: service['openHourEnd']?.toString() ?? 'N/A',
                );
              },
            ),
          ),
        );
      },
    );
  }
}