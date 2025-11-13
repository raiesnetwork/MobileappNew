import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/service_provider.dart';


class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicesProvider>().fetchMyBookings();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<ServicesProvider>().loadMoreBookings();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'all') {
                context.read<ServicesProvider>().filterBookingsByStatus(null);
              } else {
                context.read<ServicesProvider>().filterBookingsByStatus(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Bookings')),
              const PopupMenuItem(value: 'SUCCESS', child: Text('Success')),
              const PopupMenuItem(value: 'PENDING', child: Text('Pending')),
              const PopupMenuItem(value: 'FAILED', child: Text('Failed')),
            ],
          ),
        ],
      ),
      body: Consumer<ServicesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingBookings && provider.myBookings.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.bookingsError.isNotEmpty && provider.myBookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.bookingsError),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchMyBookings(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.myBookings.isEmpty) {
            return const Center(child: Text('No bookings found'));
          }

          return RefreshIndicator(
            onRefresh: provider.refreshBookings,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: provider.myBookings.length +
                  (provider.hasMoreBookings ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == provider.myBookings.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final booking = provider.myBookings[index];
                return _buildBookingCard(booking);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final service = booking['serviceId'] ?? {};
    final creator = service['creatorId'] ?? {};
    final creatorProfile = creator['profile'] ?? {};
    final community = service['communityId'] ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Service Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    service['image'] ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['name'] ?? 'Unknown Service',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${service['currency'] ?? 'INR'} ${service['cost'] ?? 0} / ${service['costPer'] ?? 'person'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(booking['paymentStatus'] ?? 'PENDING'),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.category, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${service['category'] ?? ''} - ${service['subCategory'] ?? ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  service['location'] ?? 'N/A',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  creatorProfile['name'] ?? 'Unknown Creator',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            if (community['name'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    community['name'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatDate(booking['bookingDate']),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        color = Colors.green;
        break;
      case 'PENDING':
        color = Colors.orange;
        break;
      case 'FAILED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}