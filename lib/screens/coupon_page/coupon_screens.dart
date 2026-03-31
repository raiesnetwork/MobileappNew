import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/screens/coupon_page/send_coupon-screen.dart';
import 'package:ixes.app/screens/coupon_page/verify_coupon.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/coupon_provider.dart';
import 'create_coupon.dart';

class CouponListScreen extends StatefulWidget {
  const CouponListScreen({Key? key}) : super(key: key);

  @override
  State<CouponListScreen> createState() => _CouponListScreenState();
}

class _CouponListScreenState extends State<CouponListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Coupons',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: Primary),
            onPressed: _showVerifySheet,
            tooltip: 'Apply Coupon',
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.grey[600]),
            onPressed: () =>
                context.read<CouponProvider>().fetchUserCoupons(),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                indicator: BoxDecoration(
                  color: Primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Created'),
                  Tab(text: 'Received'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Consumer<CouponProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Primary,
                strokeWidth: 2,
              ),
            );
          }

          if (provider.errorMessage != null) {
            return _buildError(provider);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCouponList(provider.createdCoupons, isCreated: true),
              _buildCouponList(provider.receivedCoupons, isCreated: false),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateCouponScreen()),
        ),
        backgroundColor: Primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Create Coupon',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildError(CouponProvider provider) {
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.wifi_off_rounded,
                  color: Colors.red.shade400, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              provider.errorMessage!,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: provider.fetchUserCoupons,
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
              child: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponList(List<Map<String, dynamic>> coupons,
      {required bool isCreated}) {
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
              Text(
                isCreated ? 'No coupons yet' : 'No received coupons',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCreated
                    ? 'Tap + to create your first coupon'
                    : 'Coupons shared with you will appear here',
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
      onRefresh: () => context.read<CouponProvider>().fetchUserCoupons(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: coupons.length,
        itemBuilder: (context, index) {
          return _CouponCard(
            coupon: coupons[index],
            isCreated: isCreated,
            onSend: isCreated ? () => _showSendSheet(coupons[index]) : null,
          );
        },
      ),
    );
  }

  void _showVerifySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VerifyCouponSheet(),
    );
  }

  void _showSendSheet(Map<String, dynamic> coupon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendCouponSheet(coupon: coupon),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUPON CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;
  final bool isCreated;
  final VoidCallback? onSend;

  const _CouponCard({
    required this.coupon,
    required this.isCreated,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = _isExpired();
    final typeColor = _typeColor();
    final discountText = _discountText();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired ? Colors.grey.shade200 : typeColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top colored strip
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isExpired
                  ? Colors.grey.shade50
                  : typeColor.withOpacity(0.06),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: isExpired
                      ? Colors.grey.shade100
                      : typeColor.withOpacity(0.12),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.grey.shade100
                        : typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(),
                          color: isExpired ? Colors.grey : typeColor,
                          size: 12),
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
                if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
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
                          color: isExpired
                              ? Colors.grey
                              : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (discountText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? Colors.grey.shade100
                              : Primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
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
                ),

                if (coupon['details'] != null &&
                    coupon['details'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    coupon['details'],
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Dashed divider
                Row(
                  children: List.generate(
                    30,
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

                const SizedBox(height: 12),

                // Code strip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.confirmation_number_outlined,
                          color: Colors.grey[400], size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          coupon['code'] ?? '—',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                              text: coupon['code'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Code copied!'),
                              backgroundColor: Primary,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.copy_rounded,
                              color: Primary, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Expiry row
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
                            : Colors.grey[400],
                        fontSize: 11,
                        fontWeight: isExpired
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),

                // Action buttons
                if (!isExpired) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (isCreated && onSend != null) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onSend,
                            icon: const Icon(Icons.send_rounded,
                                size: 14),
                            label: const Text('Send'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Primary,
                              side: BorderSide(
                                  color: Primary.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (coupon['link'] != null &&
                          coupon['link'].toString().isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 14),
                            label: const Text('Use Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              elevation: 0,
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
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