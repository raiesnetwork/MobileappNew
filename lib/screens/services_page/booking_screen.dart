import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../constants/constants.dart';
import '../../providers/service_provider.dart';
import '../../providers/coupon_provider.dart';

class BookingScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final num costPerSlot;
  final String currency;
  final int maxSlots;
  final String serviceImage;
  final String location;
  final int slotDurationMinutes;

  const BookingScreen({
    Key? key,
    required this.serviceId,
    required this.serviceName,
    required this.costPerSlot,
    this.currency = 'INR',
    this.maxSlots = 10,
    this.serviceImage = '',
    this.location = '',
    this.slotDurationMinutes = 15,
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with TickerProviderStateMixin {
  late Razorpay _razorpay;
  DateTime? _selectedDate;
  final Set<String> _selectedTimeSlots = {};
  bool _isProcessing = false;
  Map<String, dynamic>? _appliedCoupon;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<String> _availableTimeSlots = [
    '09:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
    '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM',
    '05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Pricing ─────────────────────────────────────────────────────────────────
  num get _subtotal => widget.costPerSlot * _selectedTimeSlots.length;

  num get _discountAmount {
    if (_appliedCoupon == null || _selectedTimeSlots.isEmpty) return 0;
    if (_appliedCoupon!['discountPercentage'] != null) {
      return (_subtotal * (_appliedCoupon!['discountPercentage'] as num) / 100)
          .floorToDouble();
    }
    if (_appliedCoupon!['discountAmount'] != null) {
      final d = _appliedCoupon!['discountAmount'] as num;
      return d > _subtotal ? _subtotal : d;
    }
    return 0;
  }

  num get _total => _subtotal - _discountAmount;

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _fmt(DateTime d) => DateFormat('EEE, dd MMM yyyy').format(d);

  String _slotRange(String start) {
    try {
      final p = DateFormat('hh:mm a').parse(start);
      final e = p.add(Duration(minutes: widget.slotDurationMinutes));
      return '${DateFormat('hh:mm a').format(p)} – ${DateFormat('hh:mm a').format(e)}';
    } catch (_) {
      return start;
    }
  }

  // ── Date picker ─────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: Primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlots.clear();
      });
    }
  }

  // ── Slot toggle ─────────────────────────────────────────────────────────────
  void _toggleSlot(String slot) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedTimeSlots.contains(slot)) {
        _selectedTimeSlots.remove(slot);
      } else {
        if (_selectedTimeSlots.length < widget.maxSlots) {
          _selectedTimeSlots.add(slot);
        } else {
          _snack('Maximum ${widget.maxSlots} slots allowed', error: true);
        }
      }
    });
  }

  // ── Coupon ───────────────────────────────────────────────────────────────────
  void _openCoupon() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<CouponProvider>(),
        child: _CouponBottomSheet(
          onApplied: (coupon) {
            setState(() => _appliedCoupon = coupon);
            Navigator.pop(context);
            _snack('Coupon applied 🎉');
          },
        ),
      ),
    );
  }

  void _removeCoupon() {
    HapticFeedback.lightImpact();
    setState(() => _appliedCoupon = null);
  }

  // ── Payment ──────────────────────────────────────────────────────────────────
  Future<void> _pay() async {
    if (_selectedDate == null) {
      _snack('Please select a date', error: true);
      return;
    }
    if (_selectedTimeSlots.isEmpty) {
      _snack('Please select at least one time slot', error: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);
    try {
      final provider = context.read<ServicesProvider>();
      final res = await provider.createPaymentOrder(amount: _total);
      if (res['err']) {
        setState(() => _isProcessing = false);
        _snack(res['message'], error: true);
        return;
      }
      final order = res['order'];
      if (order == null || (order as Map).isEmpty) {
        setState(() => _isProcessing = false);
        _snack('Failed to create payment order', error: true);
        return;
      }
      _openRazorpay(order as Map<String, dynamic>);
    } catch (e) {
      setState(() => _isProcessing = false);
      _snack('Error: $e', error: true);
    }
  }

  void _openRazorpay(Map<String, dynamic> order) {
    _razorpay.open({
      'key': 'rzp_live_SL4ZRZsuETGg36',
      'amount': order['amount'],
      'order_id': order['id'],
      'name': widget.serviceName,
      'description': 'Booking – ${_fmt(_selectedDate!)}',
      'prefill': {'contact': '9999999999', 'email': 'user@gmail.com'},
      'theme': {'color': '#${Primary.value.toRadixString(16).substring(2, 8)}'},
      'notes': {
        'service_id': widget.serviceId,
        'slots': _selectedTimeSlots.length.toString(),
        'date': _selectedDate!.toIso8601String(),
        if (_appliedCoupon != null) 'coupon_code': _appliedCoupon!['code'],
      },
    });
  }

  void _handlePaymentSuccess(PaymentSuccessResponse res) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final provider = Provider.of<ServicesProvider>(context, listen: false);
      final slots = _selectedTimeSlots.toList()
        ..sort();
      final slotsWithRanges = slots.map(_slotRange).toList();

      final verify = await provider.verifyPayment(
        response: {
          'razorpay_payment_id': res.paymentId,
          'razorpay_order_id': res.orderId,
          'razorpay_signature': res.signature,
        },
        serviceId: widget.serviceId,
        amount: _total,
        date: _selectedDate!.toIso8601String().split('T')[0],
        slots: _selectedTimeSlots.length,
        selectedSlots: slotsWithRanges,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final booking = verify['booking'];
      if (booking != null && booking is Map && booking.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        _showSuccess(Map<String, dynamic>.from(booking));
      } else {
        _snack(verify['message'] ?? 'Payment verification failed', error: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _snack('Error: $e', error: true);
    }
  }

  void _handlePaymentError(PaymentFailureResponse res) {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _snack('Payment failed: ${res.message ?? "Unknown error"}', error: true);
    });
  }

  void _handleExternalWallet(ExternalWalletResponse res) {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _snack('External wallet: ${res.walletName}');
    });
  }

  // ── Success dialog ───────────────────────────────────────────────────────────
  void _showSuccess(Map<String, dynamic> booking) {
    final slots = _selectedTimeSlots.toList().map(_slotRange).join('\n');
    final bookingId = booking['_id']?.toString() ?? 'N/A';
    final sId = booking['serviceId'];
    final name = sId is Map ? sId['name']?.toString() ?? widget.serviceName : widget.serviceName;
    final date = _selectedDate != null ? _fmt(_selectedDate!) : 'N/A';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success ring
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withOpacity(0.1),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Booking Confirmed!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              const SizedBox(height: 4),
              Text('Your appointment is all set', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _dRow(Icons.business_center_rounded, 'Service', name),
                    _div(),
                    _dRow(Icons.calendar_today_rounded, 'Date', date),
                    _div(),
                    _dRow(Icons.access_time_rounded, 'Slots', slots, multi: true),
                    _div(),
                    _dRow(Icons.payments_rounded, 'Amount Paid',
                        '${widget.currency} $_total', hi: true),
                    if (_discountAmount > 0) ...[
                      _div(),
                      _dRow(Icons.local_offer_rounded, 'You Saved',
                          '${widget.currency} $_discountAmount',
                          hi: true, hiColor: const Color(0xFF10B981)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Primary.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.confirmation_number_rounded, size: 12, color: Primary),
                    const SizedBox(width: 6),
                    Text('Booking ID: $bookingId',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Primary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _div() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Divider(height: 1, color: const Color(0xFFE5E7EB)),
  );

  Widget _dRow(IconData icon, String label, String val,
      {bool hi = false, bool multi = false, Color? hiColor}) {
    final c = hiColor ?? Primary;
    return Row(
      crossAxisAlignment: multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: hi ? c.withOpacity(0.1) : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: hi ? c : Colors.grey[500]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(val,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: hi ? c : const Color(0xFF111827))),
            ],
          ),
        ),
      ],
    );
  }

  // ── Snackbar ─────────────────────────────────────────────────────────────────
  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Consumer<ServicesProvider>(
          builder: (context, provider, _) {
            return Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
                          child: Column(
                            children: [
                              _dateCard(),
                              const SizedBox(height: 12),
                              _slotsCard(),
                              const SizedBox(height: 12),
                              _couponCard(),
                              const SizedBox(height: 12),
                              _summaryCard(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(bottom: 0, left: 0, right: 0, child: _payBar()),
                if (_isProcessing || provider.isPaymentLoading) _loading(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 210,
      collapsedHeight: 60,
      pinned: true,
      stretch: true,
      backgroundColor: Primary,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16),
          ),
        ),
      ),
      title: const Text('Book Appointment',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _appBarBg(),
      ),
    );
  }

  Widget _appBarBg() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Primary, Color.lerp(Primary, const Color(0xFF0A0A1A), 0.4)!],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -50, right: -30,
              child: Container(width: 180, height: 180,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04)))),
          Positioned(bottom: -30, left: -20,
              child: Container(width: 120, height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04)))),
          Positioned(
            bottom: 18, left: 16, right: 16,
            child: Row(
              children: [
                // thumbnail
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.12),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                    image: widget.serviceImage.isNotEmpty
                        ? DecorationImage(
                        image: NetworkImage(widget.serviceImage), fit: BoxFit.cover)
                        : null,
                  ),
                  child: widget.serviceImage.isEmpty
                      ? Icon(Icons.medical_services_rounded, size: 28,
                      color: Colors.white.withOpacity(0.8))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.serviceName,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w800, height: 1.2)),
                      if (widget.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.location_on_rounded, size: 11,
                              color: Colors.white.withOpacity(0.65)),
                          const SizedBox(width: 3),
                          Expanded(child: Text(widget.location, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11))),
                        ]),
                      ],
                      const SizedBox(height: 8),
                      Row(children: [
                        _badge('${widget.currency} ${widget.costPerSlot}/slot',
                            Icons.payments_rounded),
                        const SizedBox(width: 8),
                        _badge('${widget.slotDurationMinutes} min',
                            Icons.timer_rounded),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withOpacity(0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: Colors.white),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 10,
              fontWeight: FontWeight.w700)),
    ]),
  );

  // ── Card shell ───────────────────────────────────────────────────────────────
  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 14, offset: const Offset(0, 4)),
      ],
    ),
    child: child,
  );

  Widget _sectionTitle(String t, {Widget? trailing}) => Row(
    children: [
      Text(t,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: Color(0xFF111827))),
      const Spacer(),
      if (trailing != null) trailing,
    ],
  );

  // ── Date card ────────────────────────────────────────────────────────────────
  Widget _dateCard() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Select Date'),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _pickDate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _selectedDate != null
                ? Primary.withOpacity(0.05) : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _selectedDate != null
                  ? Primary.withOpacity(0.3) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _selectedDate != null
                    ? Primary.withOpacity(0.1) : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_month_rounded, size: 18,
                  color: _selectedDate != null ? Primary : Colors.grey[400]),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _selectedDate == null ? 'Choose a date' : _fmt(_selectedDate!),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _selectedDate != null
                      ? FontWeight.w700 : FontWeight.w400,
                  color: _selectedDate != null
                      ? const Color(0xFF111827) : Colors.grey[400],
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(height: 2),
                Text('Tap to change',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ])),
            Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[350]),
          ]),
        ),
      ),
    ]),
  );

  // ── Slots card ───────────────────────────────────────────────────────────────
  Widget _slotsCard() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Select Time Slots', trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _selectedTimeSlots.isNotEmpty
              ? Primary.withOpacity(0.1) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('${_selectedTimeSlots.length}/${widget.maxSlots}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: _selectedTimeSlots.isNotEmpty ? Primary : Colors.grey[500])),
      )),
      const SizedBox(height: 4),
      Text('${widget.slotDurationMinutes} min per slot',
          style: TextStyle(fontSize: 12, color: Colors.grey[450])),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _availableTimeSlots.map((slot) {
          final sel = _selectedTimeSlots.contains(slot);
          return GestureDetector(
            onTap: () => _toggleSlot(slot),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? Primary : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? Primary : const Color(0xFFE5E7EB), width: 1.5),
                boxShadow: sel
                    ? [BoxShadow(color: Primary.withOpacity(0.2),
                    blurRadius: 8, offset: const Offset(0, 3))]
                    : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (sel) ...[
                  const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                ],
                Text(slot,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : const Color(0xFF444444))),
              ]),
            ),
          );
        }).toList(),
      ),
    ]),
  );

  // ── Coupon card ──────────────────────────────────────────────────────────────
  Widget _couponCard() {
    if (_appliedCoupon != null) {
      final dl = _appliedCoupon!['discountPercentage'] != null
          ? '${_appliedCoupon!['discountPercentage']}% OFF'
          : _appliedCoupon!['discountAmount'] != null
          ? '${widget.currency} ${_appliedCoupon!['discountAmount']} OFF'
          : 'Discount applied';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.05),
              blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_offer_rounded,
                color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_appliedCoupon!['code']?.toString().toUpperCase() ?? 'APPLIED',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text('You save $dl',
                style: const TextStyle(fontSize: 12, color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600)),
          ])),
          GestureDetector(
            onTap: _removeCoupon,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded, size: 15, color: Colors.redAccent),
            ),
          ),
        ]),
      );
    }

    return _card(
      child: GestureDetector(
        onTap: _openCoupon,
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_offer_rounded, color: Primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Apply Coupon',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Primary)),
            const SizedBox(height: 2),
            Text('Have a promo code? Tap here',
                style: TextStyle(fontSize: 12, color: Colors.grey[450])),
          ])),
          Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[350]),
        ]),
      ),
    );
  }

  // ── Summary card ─────────────────────────────────────────────────────────────
  Widget _summaryCard() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Price Summary'),
      const SizedBox(height: 16),
      _pRow('Price per slot', '${widget.currency} ${widget.costPerSlot}'),
      const SizedBox(height: 8),
      _pRow('${_selectedTimeSlots.length} slot(s)', '${widget.currency} $_subtotal'),
      if (_appliedCoupon != null && _discountAmount > 0) ...[
        const SizedBox(height: 8),
        _pRow('Coupon discount', '– ${widget.currency} $_discountAmount',
            vc: const Color(0xFF10B981)),
      ],
      const SizedBox(height: 16),
      Container(height: 1, color: const Color(0xFFEEEEEE)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Total',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: Color(0xFF111827))),
        Text('${widget.currency} $_total',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: Primary, letterSpacing: -0.5)),
      ]),
    ]),
  );

  Widget _pRow(String l, String v, {Color? vc}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(l, style: TextStyle(fontSize: 13, color: Colors.grey[500],
          fontWeight: FontWeight.w500)),
      Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: vc ?? const Color(0xFF1A1A2E))),
    ],
  );

  // ── Pay bar ───────────────────────────────────────────────────────────────────
  Widget _payBar() {
    final ok = !_isProcessing && _selectedTimeSlots.isNotEmpty && _selectedDate != null;
    String label;
    if (_isProcessing) {
      label = 'Processing…';
    } else if (_selectedDate == null) {
      label = 'Select a date first';
    } else if (_selectedTimeSlots.isEmpty) {
      label = 'Select a time slot';
    } else {
      label = 'Pay ${widget.currency} $_total';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
            blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: ok ? _pay : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              disabledForegroundColor: Colors.grey[400],
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_isProcessing ? Icons.hourglass_empty_rounded : Icons.lock_rounded,
                  size: 17),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────────
  Widget _loading() => Container(
    color: Colors.black.withOpacity(0.4),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 38, height: 38,
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Primary), strokeWidth: 3)),
          const SizedBox(height: 18),
          const Text('Processing Payment',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text('Don\'t close this screen',
              style: TextStyle(fontSize: 12, color: Colors.grey[450])),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Coupon Bottom Sheet — standalone widget, NOT inline
// This is what opens from BookingScreen via showModalBottomSheet
// ─────────────────────────────────────────────────────────────────────────────
class _CouponBottomSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> coupon) onApplied;

  const _CouponBottomSheet({required this.onApplied});

  @override
  State<_CouponBottomSheet> createState() => _CouponBottomSheetState();
}

class _CouponBottomSheetState extends State<_CouponBottomSheet> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _coupon;

  @override
  void dispose() {
    _ctrl.dispose();
    context.read<CouponProvider>().clearVerifyState();
    super.dispose();
  }

  void _verify() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;
    final result = await context.read<CouponProvider>().verifyCoupon(code: code);
    if (result['success'] == true && mounted) {
      setState(() => _coupon = result['coupon']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.local_offer_rounded, color: Primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Apply Coupon',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                Text('Enter your promo code below',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ]),

            const SizedBox(height: 20),

            // Input + button
            Row(children: [
              Expanded(
                child: StatefulBuilder(
                  builder: (_, ss) => TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.black87,
                        fontWeight: FontWeight.w700, letterSpacing: 2, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'COUPON CODE',
                      hintStyle: TextStyle(color: Colors.grey[300],
                          fontWeight: FontWeight.w400, letterSpacing: 2, fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Primary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.grey[400], size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          context.read<CouponProvider>().clearVerifyState();
                          setState(() => _coupon = null);
                          ss(() {});
                        },
                      )
                          : null,
                    ),
                    onChanged: (_) => ss(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Consumer<CouponProvider>(builder: (_, provider, __) {
                return SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: provider.isVerifying ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: provider.isVerifying
                        ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Text('Apply',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                );
              }),
            ]),

            const SizedBox(height: 16),

            // Result feedback
            Consumer<CouponProvider>(builder: (_, provider, __) {
              if (provider.verifyErrorMessage != null) {
                return _tile(
                  icon: Icons.cancel_rounded,
                  color: Colors.red.shade400,
                  bg: Colors.red.shade50,
                  title: 'Invalid Coupon',
                  sub: provider.verifyErrorMessage!,
                );
              }
              if (_coupon != null) {
                final disc = _discText(_coupon!);
                return _tile(
                  icon: Icons.check_circle_rounded,
                  color: Colors.green.shade500,
                  bg: Colors.green.shade50,
                  title: 'Coupon Applied! 🎉',
                  sub: disc.isNotEmpty ? 'You save $disc' : _coupon!['name'] ?? '',
                  action: () => widget.onApplied(_coupon!),
                  actionLabel: 'Use this',
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  String _discText(Map<String, dynamic> c) {
    if (c['discountPercentage'] != null) return '${c['discountPercentage']}%';
    if (c['discountAmount'] != null) return '${c['discountCurrency'] ?? ''}${c['discountAmount']}';
    return '';
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required Color bg,
    required String title,
    required String sub,
    VoidCallback? action,
    String? actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(sub, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ])),
        if (action != null)
          GestureDetector(
            onTap: action,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(actionLabel ?? 'Use',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
      ]),
    );
  }
}