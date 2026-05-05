import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late Future<Map<String, dynamic>> _couponsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _couponsFuture = context
            .read<CommunityProvider>()
            .fetchCommunityCoupons(widget.communityId);
      });
    });
  }

  void _refresh() {
    setState(() {
      _couponsFuture = context
          .read<CommunityProvider>()
          .fetchCommunityCoupons(widget.communityId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Community Coupons',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.grey[600]),
            onPressed: _refresh,
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F1F5)),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _couponsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Primary, strokeWidth: 2),
            );
          }

          if (snapshot.hasError || provider.couponsError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.wifi_off_rounded,
                          color: Colors.red.shade400, size: 36),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Couldn\'t load coupons',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.couponsError ?? 'Something went wrong',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 13),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final coupons =
              provider.communityCoupons['coupons'] as List<dynamic>? ?? [];

          if (coupons.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_offer_outlined,
                          color: Primary, size: 36),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No coupons available',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coupons shared to this community will appear here',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: Primary,
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: coupons.length,
              itemBuilder: (context, index) {
                final coupon =
                Map<String, dynamic>.from(coupons[index] as Map);
                return _CouponCard(coupon: coupon);
              },
            ),
          );
        },
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;

  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final isExpired = _isExpired();
    final typeColor = _typeColor();
    final discountText = _discountText();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpired
              ? Colors.grey.shade200
              : typeColor.withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header strip ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isExpired
                  ? Colors.grey.shade50
                  : typeColor.withOpacity(0.06),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(
                bottom: BorderSide(
                  color: isExpired
                      ? Colors.grey.shade100
                      : typeColor.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                // Type badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.grey.shade100
                        : typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(),
                          color: isExpired ? Colors.grey : typeColor, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        _typeLabel().toUpperCase(),
                        style: TextStyle(
                          color: isExpired ? Colors.grey : typeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Expired badge
                if (isExpired)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'EXPIRED',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                // Active badge
                else
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + discount badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        coupon['name'] ?? 'Unnamed Coupon',
                        style: TextStyle(
                          color: isExpired ? Colors.grey : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (discountText.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? Colors.grey.shade100
                              : Primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          discountText,
                          style: TextStyle(
                            color: isExpired ? Colors.grey : Primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                if (coupon['details'] != null &&
                    coupon['details'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    coupon['details'],
                    style:
                    TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),

                // ── Dashed divider ──
                Row(
                  children: List.generate(
                    40,
                        (i) => Expanded(
                      child: Container(
                        height: 1,
                        color: i.isEven
                            ? Colors.grey.shade200
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Code strip ──
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.confirmation_number_outlined,
                          color: Colors.grey[400], size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          coupon['code'] ?? '—',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: coupon['code'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Code copied!'),
                                ],
                              ),
                              backgroundColor: Primary,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, color: Primary, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  color: Primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Expiry row ──
                Row(
                  children: [
                    Icon(
                      isExpired
                          ? Icons.timer_off_outlined
                          : Icons.timer_outlined,
                      color: isExpired
                          ? Colors.red.shade400
                          : Colors.grey[400],
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${isExpired ? 'Expired' : 'Expires'} ${_formatDate(coupon['expiry'])}',
                      style: TextStyle(
                        color: isExpired
                            ? Colors.red.shade400
                            : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: isExpired
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor() {
    switch (coupon['type']) {
      case 'coins':
        return const Color(0xFFF59E0B);
      case 'rewards':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _typeIcon() {
    switch (coupon['type']) {
      case 'coins':
        return Icons.monetization_on_outlined;
      case 'rewards':
        return Icons.card_giftcard_outlined;
      default:
        return Icons.local_offer_outlined;
    }
  }

  String _typeLabel() => coupon['type'] ?? 'coupon';

  String _discountText() {
    if (coupon['discountPercentage'] != null) {
      return '${coupon['discountPercentage']}% OFF';
    } else if (coupon['discountAmount'] != null) {
      final cur = coupon['discountCurrency'] ?? '';
      return '$cur${coupon['discountAmount']} OFF';
    } else if (coupon['coinAmount'] != null) {
      return '${coupon['coinAmount']} Coins';
    }
    return '';
  }

  bool _isExpired() {
    if (coupon['expiry'] == null) return false;
    try {
      return DateTime.parse(coupon['expiry']).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '—';
    try {
      final d = DateTime.parse(date);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return '—';
    }
  }
}