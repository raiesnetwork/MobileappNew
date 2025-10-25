import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/communities_provider.dart';

class CommunityCouponsScreen extends StatelessWidget {
  final String communityId;

  const CommunityCouponsScreen({super.key, required this.communityId});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    final couponsFuture = provider.fetchCommunityCoupons(communityId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coupons',style: TextStyle(color: Primary),),
        backgroundColor: Colors.grey.shade100,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: couponsFuture,
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
                style: TextStyle(fontSize: 16, color: Colors.black87,fontWeight: FontWeight.bold),
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
