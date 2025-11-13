import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:provider/provider.dart';
import '../../providers/service_provider.dart';
import 'booking_screen.dart';

class ServiceDetailsScreen extends StatefulWidget {
  final String serviceId;

  const ServiceDetailsScreen({super.key, required this.serviceId});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ServicesProvider>(context, listen: false);
      provider.fetchServiceDetailsSeparate(widget.serviceId);
    });
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (iconColor ?? Primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: iconColor ?? Primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'active':
        chipColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green[700]!;
        break;
      case 'inactive':
        chipColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red[700]!;
        break;
      case 'pending':
        chipColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange[700]!;
        break;
      default:
        chipColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildAvailableDaysChips(List<dynamic>? days) {
    if (days == null || days.isEmpty) {
      return const Text('N/A', style: TextStyle(color: Colors.grey));
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: days.map<Widget>((day) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Primary.withOpacity(0.3)),
          ),
          child: Text(
            day.toString(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Primary,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        final service = provider.serviceDetails.isNotEmpty ? provider.serviceDetails : null;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: provider.isServiceDetailsLoading
              ? const Center(child: CircularProgressIndicator(color: Primary))
              : provider.hasServiceDetailsError
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Colors.red[400],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  provider.serviceDetailsMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => provider.fetchServiceDetailsSeparate(widget.serviceId),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          )
              : service == null
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'No service details available',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )
              : SingleChildScrollView(
            child: Column(
              children: [
                // Hero Image Section
                Container(
                  height: 260,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Image
                      service['image'] != null && service['image'].toString().isNotEmpty
                          ? () {
                        String base64Image = service['image'].toString();
                        if (base64Image.startsWith('data:image')) {
                          base64Image = base64Image.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
                        }
                        try {
                          final imageBytes = base64Decode(base64Image);
                          return Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: MemoryImage(imageBytes),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.25),
                                  ],
                                ),
                              ),
                            ),
                          );
                        } catch (e) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image,
                              size: 64,
                              color: Colors.grey,
                            ),
                          );
                        }
                      }()
                          : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Primary.withOpacity(0.3),
                              Primary.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.image,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Section
                Container(
                  transform: Matrix4.translationValues(0, -16, 0),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Status Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                service['name']?.toString() ?? 'Unnamed Service',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildStatusChip(service['status']?.toString() ?? 'Unknown'),
                          ],
                        ),

                        const SizedBox(height: 15),






                        // Description Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                service['description']?.toString() ?? 'No description available',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height:12),

                        // Information Grid
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoCard(
                                    icon: Icons.category_outlined,
                                    title: 'Category',
                                    value: service['category']?.toString() ?? 'N/A',
                                    iconColor: Colors.blue[600],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildInfoCard(
                                    icon: Icons.layers_outlined,
                                    title: 'Sub Category',
                                    value: service['subCategory']?.toString() ?? 'N/A',
                                    iconColor: Colors.purple[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoCard(
                                    icon: Icons.access_time,
                                    title: 'Hours',
                                    value: '${service['openHourFrom']?.toString() ?? 'N/A'} - ${service['openHourEnd']?.toString() ?? 'N/A'}',
                                    iconColor: Colors.orange[600],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildInfoCard(
                                    icon: Icons.attach_money,
                                    title: 'Cost',
                                    value: '${service['currency']?.toString() ?? ''}${service['cost']?.toString() ?? 'N/A'} / ${service['costPer']?.toString() ?? 'N/A'}',
                                    iconColor: Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoCard(
                                    icon: Icons.event_seat,
                                    title: 'Available Slots',
                                    value: service['capacity']?.toString() ?? 'N/A',
                                    iconColor: Colors.indigo[600],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildInfoCard(
                                    icon: Icons.location_on_outlined,
                                    title: 'Location',
                                    value: service['location']?.toString() ?? 'N/A',
                                    iconColor: Colors.red[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        // Available Days Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today,
                                      color: Primary,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Available Days',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildAvailableDaysChips(service['availableDays'] as List<dynamic>?),
                            ],
                          ),
                        ),

                        const SizedBox(height:15),

                        // Book Now Button
                        // Replace the existing "Book Now" button in service_details.dart with this code:

// Book Now Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to BookingScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingScreen(
                                    serviceId: service['_id']?.toString() ?? '',
                                    serviceName: service['name']?.toString() ?? 'Service',
                                    costPerSlot: service['cost'] ?? 0,
                                    currency: service['currency']?.toString() ?? 'INR',
                                    maxSlots: service['capacity'] ?? 10,
                                    serviceImage: service['image']?.toString() ?? '',
                                    location: service['location']?.toString() ?? '',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                              shadowColor: Primary.withOpacity(0.3),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.book_online, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Book Now',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

// Don't forget to add this import at the top of service_details.dart:
// import 'booking_screen.dart';
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}