import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/coupon_provider.dart';
import 'create_coupon.dart';


class CouponListScreen extends StatefulWidget {
  const CouponListScreen({Key? key}) : super(key: key);

  @override
  State<CouponListScreen> createState() => _CouponListScreenState();
}

class _CouponListScreenState extends State<CouponListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Fetch coupons when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CouponProvider>().fetchUserCoupons();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Coupons'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Created Coupons'),
            Tab(text: 'Received Coupons'),
          ],
        ),
        actions: [IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>CreateCouponScreen()),
            );
          },
        )
        ],
      ),
      body: Consumer<CouponProvider>(
        builder: (context, couponProvider, child) {
          if (couponProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (couponProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    couponProvider.errorMessage!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => couponProvider.fetchUserCoupons(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCouponList(couponProvider.createdCoupons, 'created'),
              _buildCouponList(couponProvider.receivedCoupons, 'received'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCouponList(List<Map<String, dynamic>> coupons, String type) {
    if (coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type} coupons found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type == 'created'
                  ? 'Create your first coupon to get started'
                  : 'You haven\'t received any coupons yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<CouponProvider>().fetchUserCoupons(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coupons.length,
        itemBuilder: (context, index) {
          final coupon = coupons[index];
          return CouponCard(coupon: coupon, type: type);
        },
      ),
    );
  }
}

class CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;
  final String type;

  const CouponCard({
    Key? key,
    required this.coupon,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isExpired = _isExpired();
    final discountText = _getDiscountText();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isExpired
              ? [Colors.grey[300]!, Colors.grey[400]!]
              : [Colors.blue[400]!, Colors.purple[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Decorative pattern
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          coupon['name'] ?? 'Unnamed Coupon',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Coupon code
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.confirmation_number,
                          color: Colors.grey[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          coupon['code'] ?? 'NO CODE',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Details
                  if (coupon['details'] != null && coupon['details'].toString().isNotEmpty)
                    Text(
                      coupon['details'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Discount info
                  if (discountText.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer,
                          color: Colors.white.withOpacity(0.9),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          discountText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Expiry date
                  Row(
                    children: [
                      Icon(
                        isExpired ? Icons.schedule : Icons.access_time,
                        color: isExpired
                            ? Colors.red[300]
                            : Colors.white.withOpacity(0.9),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isExpired
                            ? 'Expired on ${_formatDate(coupon['expiry'])}'
                            : 'Expires on ${_formatDate(coupon['expiry'])}',
                        style: TextStyle(
                          color: isExpired
                              ? Colors.red[300]
                              : Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: isExpired ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),

                  // Action buttons
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (coupon['link'] != null && coupon['link'].toString().isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isExpired ? null : () => _openLink(context, coupon['link']),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Use Coupon'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _copyCode(context, coupon['code']),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Expired overlay
            if (isExpired)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'EXPIRED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isExpired() {
    if (coupon['expiry'] == null) return false;
    try {
      final expiryDate = DateTime.parse(coupon['expiry']);
      return expiryDate.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  String _getDiscountText() {
    if (coupon['discountPercentage'] != null) {
      return '${coupon['discountPercentage']}% OFF';
    } else if (coupon['discountAmount'] != null) {
      final currency = coupon['discountCurrency'] ?? '';
      return '$currency${coupon['discountAmount']} OFF';
    } else if (coupon['coinAmount'] != null) {
      return '${coupon['coinAmount']} Coins';
    }
    return '';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'No date';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _openLink(BuildContext context, String link) {
    // Implement URL launcher here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening: $link')),
    );
  }

  void _copyCode(BuildContext context, String? code) {
    if (code != null) {
      // Implement clipboard copy here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coupon code copied to clipboard!')),
      );
    }
  }
}