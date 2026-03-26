import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/communities_provider.dart';

class CommunityCouponsScreen extends StatefulWidget {
  final String communityId;

  const CommunityCouponsScreen({super.key, required this.communityId});

  @override
  State<CommunityCouponsScreen> createState() => _CommunityCouponsScreenState();
}

class _CommunityCouponsScreenState extends State<CommunityCouponsScreen> {
  // Store the future so it doesn't re-fire on every rebuild
  late Future<Map<String, dynamic>> _couponsFuture;

  @override
  void initState() {
    super.initState();
    // Safe to call here — before the first build, no listeners are notified yet
    _couponsFuture = context
        .read<CommunityProvider>()
        .fetchCommunityCoupons(widget.communityId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coupons', style: TextStyle(color: Primary)),
        backgroundColor: Colors.grey.shade100,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _couponsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || provider.couponsError != null) {
            return Center(
              child: Text(
                provider.couponsError ?? 'Failed to load coupons',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }

          final coupons =
              provider.communityCoupons['coupons'] as List<dynamic>? ?? [];

          if (coupons.isEmpty) {
            return const Center(
              child: Text(
                'No coupons available',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: coupons.length,
            itemBuilder: (context, index) {
              final coupon = coupons[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    coupon['code'] ?? 'Unknown Coupon',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Discount: ${coupon['discount']}%'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}