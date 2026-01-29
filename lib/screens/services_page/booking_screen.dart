import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../constants/constants.dart';
import '../../providers/service_provider.dart';

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

class _BookingScreenState extends State<BookingScreen> {
  late Razorpay _razorpay;
  DateTime? _selectedDate;
  Set<String> _selectedTimeSlots = {};
  bool _isProcessing = false;

  final List<String> _availableTimeSlots = [
    '09:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
    '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM',
    '05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  num get totalAmount => widget.costPerSlot * _selectedTimeSlots.length;

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  /// ✅ NEW: Convert single time to time range (e.g., "10:00 AM" → "10:00 am - 10:15 am")
  String _convertToTimeRange(String startTime) {
    try {
      final DateFormat format = DateFormat('hh:mm a');
      final DateTime parsedTime = format.parse(startTime);

      // Add slot duration to get end time
      final DateTime endTime = parsedTime.add(Duration(minutes: widget.slotDurationMinutes));


      final String formattedStart = DateFormat('hh:mm a').format(parsedTime).toLowerCase();
      final String formattedEnd = DateFormat('hh:mm a').format(endTime).toLowerCase();

      return '$formattedStart - $formattedEnd';
    } catch (e) {
      print('❌ Error converting time range: $e');
      return startTime.toLowerCase();
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlots.clear(); // Reset slots when date changes
      });
    }
  }

  void _toggleTimeSlot(String slot) {
    setState(() {
      if (_selectedTimeSlots.contains(slot)) {
        _selectedTimeSlots.remove(slot);
      } else {
        if (_selectedTimeSlots.length < widget.maxSlots) {
          _selectedTimeSlots.add(slot);
        } else {
          _showSnackBar('Maximum ${widget.maxSlots} slots allowed', isError: true);
        }
      }
    });
  }

  Future<void> _initiateBooking() async {
    if (_selectedDate == null) {
      _showSnackBar('Please select a date', isError: true);
      return;
    }

    if (_selectedTimeSlots.isEmpty) {
      _showSnackBar('Please select at least one time slot', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final provider = context.read<ServicesProvider>();

      final orderResult = await provider.createPaymentOrder(
        amount: totalAmount,
      );

      if (orderResult['err']) {
        setState(() => _isProcessing = false);
        _showSnackBar(orderResult['message'], isError: true);
        return;
      }

      final order = orderResult['order'];

      if (order == null || order.isEmpty) {
        setState(() => _isProcessing = false);
        _showSnackBar('Failed to create payment order', isError: true);
        return;
      }

      _openRazorpayCheckout(order);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  void _openRazorpayCheckout(Map<String, dynamic> order) {
    var options = {
      'key': 'rzp_test_R9SkYwGQh6HuUF',
      'amount': order['amount'],
      'order_id': order['id'],
      'name': widget.serviceName,
      'description': 'Booking for ${widget.serviceName} - ${_formatDate(_selectedDate!)}',
      'prefill': {
        'contact': '9999999999',
        'email': 'user@gmail.com',
      },
      'theme': {
        'color': '#${Primary.value.toRadixString(16).substring(2, 8)}',
      },
      'notes': {
        'service_id': widget.serviceId,
        'slots': _selectedTimeSlots.length.toString(),
        'date': _selectedDate!.toIso8601String(),
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar('Error opening payment: ${e.toString()}', isError: true);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() => _isProcessing = true);

    try {
      final provider = Provider.of<ServicesProvider>(context, listen: false);

      // ✅ Convert selected slots to time ranges (start - end format)
      final selectedSlotsList = _selectedTimeSlots
          .toList()
        ..sort(); // Sort first

      // Convert each slot to time range format
      final selectedSlotsWithRanges = selectedSlotsList
          .map((slot) => _convertToTimeRange(slot))
          .toList();

      print('🎯 Original slots: $selectedSlotsList');
      print('🎯 Converted to ranges: $selectedSlotsWithRanges');

      final verifyResult = await provider.verifyPayment(
        response: {
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId,
          'razorpay_signature': response.signature,
        },
        serviceId: widget.serviceId,
        amount: totalAmount,
        date: _selectedDate!.toIso8601String().split('T')[0], // ✅ Send only date: YYYY-MM-DD
        slots: _selectedTimeSlots.length,
        selectedSlots: selectedSlotsWithRanges, // ✅ Send time ranges
      );

      if (!mounted) return;

      setState(() => _isProcessing = false);

      final hasError = verifyResult['err'] == true ||
          verifyResult['err'] == 'true' ||
          verifyResult['err'] == null;

      if (!hasError) {
        final booking = verifyResult['booking'];
        if (booking != null && booking.isNotEmpty) {
          _showSuccessDialog(booking);
        } else {
          _showSnackBar('Payment successful but booking data is missing', isError: true);
        }
      } else {
        final message = verifyResult['message'] ?? 'Payment verification failed';
        _showSnackBar(message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnackBar('Error verifying payment: ${e.toString()}', isError: true);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnackBar('Payment failed: ${response.message ?? "Unknown error"}', isError: true);
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnackBar('External wallet selected: ${response.walletName}');
    });
  }

  void _showSuccessDialog(Map<String, dynamic> booking) {
    // Convert selected slots to display format with ranges
    final displaySlots = _selectedTimeSlots
        .toList()
        .map((slot) => _convertToTimeRange(slot))
        .join(', ');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your booking has been successfully confirmed',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.business_center_rounded, 'Service', widget.serviceName),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.calendar_today_rounded, 'Date', _formatDate(_selectedDate!)),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.access_time_rounded, 'Time Slots', displaySlots),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.account_balance_wallet_rounded, 'Amount Paid',
                        '${widget.currency} $totalAmount', isHighlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ID: ${booking['_id'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isHighlight ? Primary.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: isHighlight ? Primary : Colors.grey[600]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isHighlight ? Primary : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Book Service', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<ServicesProvider>(
        builder: (context, provider, _) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Primary, Primary.withOpacity(0.8)],
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildServiceCard(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateSelector(),
                          const SizedBox(height: 20),
                          _buildTimeSlotsSelector(),
                          const SizedBox(height: 20),
                          _buildPriceBreakdown(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(bottom: 0, left: 0, right: 0, child: _buildPaymentButton()),
              if (_isProcessing || provider.isPaymentLoading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Primary),
                            strokeWidth: 2.5,
                          ),
                          const SizedBox(height: 16),
                          const Text('Processing payment...',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                          const SizedBox(height: 6),
                          Text('Please wait', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServiceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Primary.withOpacity(0.1), Primary.withOpacity(0.05)],
              ),
              image: widget.serviceImage.isNotEmpty
                  ? DecorationImage(image: NetworkImage(widget.serviceImage), fit: BoxFit.cover)
                  : null,
            ),
            child: widget.serviceImage.isEmpty
                ? Icon(Icons.business_center_rounded, size: 32, color: Primary.withOpacity(0.5))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.serviceName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (widget.location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(child: Text(widget.location,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${widget.currency} ${widget.costPerSlot}/slot',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.calendar_month_rounded, color: Primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Select Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedDate != null ? Primary.withOpacity(0.05) : Colors.grey[50],
                border: Border.all(color: _selectedDate != null ? Primary : Colors.grey[300]!, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, color: _selectedDate != null ? Primary : Colors.grey[400], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedDate == null ? 'Choose booking date' : _formatDate(_selectedDate!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                        color: _selectedDate != null ? Primary : Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.access_time_rounded, color: Primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Select Time Slots', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_selectedTimeSlots.length}/${widget.maxSlots}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTimeSlots.map((slot) {
              final isSelected = _selectedTimeSlots.contains(slot);
              return InkWell(
                onTap: () => _toggleTimeSlot(slot),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Primary : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Primary : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Primary.withOpacity(0.05), Primary.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Primary.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.receipt_long_rounded, color: Primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Price Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            ],
          ),
          const SizedBox(height: 16),
          _buildPriceRow('Price per slot', '${widget.currency} ${widget.costPerSlot}'),
          const SizedBox(height: 10),
          _buildPriceRow('Number of slots', '${_selectedTimeSlots.length} × ${widget.currency} ${widget.costPerSlot}'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Primary.withOpacity(0.2), thickness: 1),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Primary, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${widget.currency} $totalAmount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
      ],
    );
  }

  Widget _buildPaymentButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isProcessing || _selectedTimeSlots.isEmpty ? null : _initiateBooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: Primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            shadowColor: Primary.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 18),
              const SizedBox(width: 10),
              Text(
                _isProcessing ? 'Processing...' :
                _selectedTimeSlots.isEmpty ? 'Select Time Slots' : 'Pay ${widget.currency} $totalAmount',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
