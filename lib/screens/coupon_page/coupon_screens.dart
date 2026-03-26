import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/screens/coupon_page/send_coupon-screen.dart';
import 'package:ixes.app/screens/coupon_page/verify_coupon.dart';
import 'package:provider/provider.dart';
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

  // Design tokens
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _card = Color(0xFF242424);
  static const _accent = Color(0xFFE8FF3A);
  static const _accentDim = Color(0xFF9AAB1E);
  static const _textPrimary = Color(0xFFF5F5F0);
  static const _textMuted = Color(0xFF888880);
  static const _expired = Color(0xFF4A1A1A);
  static const _expiredText = Color(0xFFFF6B6B);

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
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MY COUPONS',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  )),
              const SizedBox(height: 4),
              const Text('Offers & Rewards',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  )),
            ],
          ),
          const Spacer(),
          // Verify coupon button
          _iconBtn(
            Icons.qr_code_scanner_rounded,
            onTap: () => _showVerifySheet(),
            tooltip: 'Apply Coupon',
          ),
          const SizedBox(width: 8),
          _iconBtn(
            Icons.refresh_rounded,
            onTap: () => context.read<CouponProvider>().fetchUserCoupons(),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, {VoidCallback? onTap, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(icon, color: _textPrimary, size: 20),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
          labelColor: _bg,
          unselectedLabelColor: _textMuted,
          indicator: BoxDecoration(
            color: _accent,
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
    );
  }

  Widget _buildTabContent() {
    return Consumer<CouponProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: _accent,
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
                color: _expired,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.wifi_off_rounded, color: _expiredText, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              provider.errorMessage!,
              style: const TextStyle(color: _textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _accentButton(
              label: 'Try Again',
              onTap: () => provider.fetchUserCoupons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponList(List<Map<String, dynamic>> coupons, {required bool isCreated}) {
    if (coupons.isEmpty) {
      return _buildEmpty(isCreated: isCreated);
    }

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _surface,
      onRefresh: () => context.read<CouponProvider>().fetchUserCoupons(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: coupons.length,
        itemBuilder: (context, index) {
          return _CouponCard(
            coupon: coupons[index],
            isCreated: isCreated,
            onSend: isCreated
                ? () => _showSendSheet(coupons[index])
                : null,
          );
        },
      ),
    );
  }

  Widget _buildEmpty({required bool isCreated}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.local_offer_outlined, color: _textMuted, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              isCreated ? 'No coupons yet' : 'No received coupons',
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCreated
                  ? 'Tap + to create your first coupon'
                  : 'Coupons shared with you will appear here',
              style: const TextStyle(color: _textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateCouponScreen()),
        );
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: _bg, size: 22),
            SizedBox(width: 8),
            Text(
              'Create Coupon',
              style: TextStyle(
                color: _bg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accentButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _bg,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
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

  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _card = Color(0xFF242424);
  static const _accent = Color(0xFFE8FF3A);
  static const _textPrimary = Color(0xFFF5F5F0);
  static const _textMuted = Color(0xFF888880);

  @override
  Widget build(BuildContext context) {
    final isExpired = _isExpired();
    final typeColor = _typeColor();
    final discountText = _discountText();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isExpired ? const Color(0xFF1A1010) : _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpired
              ? const Color(0xFF3A2020)
              : typeColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Top bar with type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(bottom: BorderSide(color: typeColor.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: typeColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(), color: typeColor, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        _typeLabel().toUpperCase(),
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A1515),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EXPIRED',
                      style: TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + discount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        coupon['name'] ?? 'Unnamed Coupon',
                        style: TextStyle(
                          color: isExpired ? _textMuted : _textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (discountText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? const Color(0xFF2A1A1A)
                              : _accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isExpired
                                ? const Color(0xFF3A2020)
                                : _accent.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          discountText,
                          style: TextStyle(
                            color: isExpired
                                ? const Color(0xFFFF6B6B)
                                : _accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),

                if (coupon['details'] != null &&
                    coupon['details'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    coupon['details'],
                    style: const TextStyle(color: _textMuted, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 16),

                // Coupon code strip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined,
                          color: _textMuted, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          coupon['code'] ?? '—',
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Courier',
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: coupon['code'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Code copied!'),
                              backgroundColor: Color(0xFF242424),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.copy_rounded,
                              color: _accent, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Expiry
                Row(
                  children: [
                    Icon(
                      isExpired
                          ? Icons.timer_off_outlined
                          : Icons.timer_outlined,
                      color: isExpired
                          ? const Color(0xFFFF6B6B)
                          : _textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${isExpired ? 'Expired' : 'Expires'} ${_formatDate(coupon['expiry'])}',
                      style: TextStyle(
                        color: isExpired
                            ? const Color(0xFFFF6B6B)
                            : _textMuted,
                        fontSize: 12,
                        fontWeight: isExpired
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),

                // Action buttons
                if (!isExpired) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (isCreated && onSend != null)
                        Expanded(
                          child: _actionBtn(
                            label: 'Send',
                            icon: Icons.send_rounded,
                            onTap: onSend!,
                            primary: false,
                          ),
                        ),
                      if (isCreated && onSend != null)
                        const SizedBox(width: 10),
                      if (coupon['link'] != null &&
                          coupon['link'].toString().isNotEmpty)
                        Expanded(
                          child: _actionBtn(
                            label: 'Use Now',
                            icon: Icons.open_in_new_rounded,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Opening: ${coupon['link']}'),
                                  backgroundColor: const Color(0xFF242424),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            primary: true,
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

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: primary ? _accent : _surface,
          borderRadius: BorderRadius.circular(10),
          border: primary ? null : Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? _bg : _textPrimary, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: primary ? _bg : _textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor() {
    switch (coupon['type']) {
      case 'coins':
        return const Color(0xFFFFC107);
      case 'rewards':
        return const Color(0xFFAB47BC);
      default:
        return const Color(0xFF42A5F5);
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

  String _typeLabel() {
    return coupon['type'] ?? 'coupon';
  }

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