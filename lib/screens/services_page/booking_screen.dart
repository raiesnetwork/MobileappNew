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

  const BookingScreen({
    Key? key,
    required this.serviceId,
    required this.serviceName,
    required this.costPerSlot,
    this.currency = 'INR',
    this.maxSlots = 10,
    this.serviceImage = '',
    this.location = '',
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late Razorpay _razorpay;
  DateTime? _selectedDate;
  int _selectedSlots = 1;
  bool _isProcessing = false;

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

  num get totalAmount => widget.costPerSlot * _selectedSlots;

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
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
      });
    }
  }

  Future<void> _initiateBooking() async {
    if (_selectedDate == null) {
      _showSnackBar('Please select a date', isError: true);
      return;
    }

    if (_selectedSlots <= 0) {
      _showSnackBar('Please select at least 1 slot', isError: true);
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
    final provider = context.read<ServicesProvider>();

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
        'slots': _selectedSlots.toString(),
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
    print('✅ Payment Success:');
    print('Payment ID: ${response.paymentId}');
    print('Order ID: ${response.orderId}');
    print('Signature: ${response.signature}');

    // Check if widget is still mounted before proceeding
    if (!mounted) {
      print('⚠️ Widget unmounted, cannot proceed');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final provider = Provider.of<ServicesProvider>(context, listen: false);

      final verifyResult = await provider.verifyPayment(
        response: {
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId,
          'razorpay_signature': response.signature,
        },
        serviceId: widget.serviceId,
        amount: totalAmount,
        date: _selectedDate!.toIso8601String(),
        slots: _selectedSlots,
      );

      // Check if widget is still mounted after async operation
      if (!mounted) {
        print('⚠️ Widget unmounted after verification');
        return;
      }

      setState(() => _isProcessing = false);

      print('🔍 Verify Result: $verifyResult');

      // Check the error flag properly
      if (verifyResult['err'] == false) {
        // Success
        final booking = verifyResult['booking'];
        if (booking != null && booking.isNotEmpty) {
          _showSuccessDialog(booking);
        } else {
          _showSnackBar('Payment successful but booking data is missing', isError: true);
        }
      } else {
        // Error
        final message = verifyResult['message'] ?? 'Payment verification failed';
        _showSnackBar(message, isError: true);
      }
    } catch (e) {
      print('💥 Error in _handlePaymentSuccess: $e');

      if (!mounted) return;

      setState(() => _isProcessing = false);
      _showSnackBar('Error verifying payment: ${e.toString()}', isError: true);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;

    setState(() => _isProcessing = false);

    print('❌ Payment Error:');
    print('Code: ${response.code}');
    print('Message: ${response.message}');

    _showSnackBar(
      'Payment failed: ${response.message ?? "Unknown error"}',
      isError: true,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;

    setState(() => _isProcessing = false);

    print('🔗 External Wallet: ${response.walletName}');
    _showSnackBar('External wallet selected: ${response.walletName}');
  }

  void _showSuccessDialog(Map<String, dynamic> booking) {
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
              // Success Icon with Animation Effect
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
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 24),

              // Booking Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.business_center_rounded,
                      'Service',
                      widget.serviceName,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.calendar_today_rounded,
                      'Date',
                      _formatDate(_selectedDate!),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.access_time_rounded,
                      'Slots',
                      '$_selectedSlots slot${_selectedSlots > 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.account_balance_wallet_rounded,
                      'Amount Paid',
                      '${widget.currency} $totalAmount',
                      isHighlight: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Booking ID
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

              // Action Button
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
          child: Icon(
            icon,
            size: 16,
            color: isHighlight ? Primary : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
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
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
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
        title: const Text(
          'Book Service',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
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
                    // Header Section with Gradient
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Primary,
                            Primary.withOpacity(0.8),
                          ],
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

                    // Content Section
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateSelector(),
                          const SizedBox(height: 20),
                          _buildSlotsSelector(),
                          const SizedBox(height: 20),
                          _buildPriceBreakdown(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Payment Button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildPaymentButton(),
              ),

              // Loading Overlay
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
                          const Text(
                            'Processing payment...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please wait',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Service Image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Primary.withOpacity(0.1),
                  Primary.withOpacity(0.05),
                ],
              ),
              image: widget.serviceImage.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(widget.serviceImage),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: widget.serviceImage.isEmpty
                ? Icon(
              Icons.business_center_rounded,
              size: 32,
              color: Primary.withOpacity(0.5),
            )
                : null,
          ),
          const SizedBox(width: 12),

          // Service Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.serviceName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.currency} ${widget.costPerSlot}/slot',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Primary,
                    ),
                  ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: Primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Select Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedDate != null
                    ? Primary.withOpacity(0.05)
                    : Colors.grey[50],
                border: Border.all(
                  color: _selectedDate != null ? Primary : Colors.grey[300]!,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    color: _selectedDate != null ? Primary : Colors.grey[400],
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? 'Choose booking date'
                          : _formatDate(_selectedDate!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedDate != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: _selectedDate != null
                            ? Primary
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: Primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Number of Slots',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slot Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decrease button
              Material(
                color: _selectedSlots > 1 ? Primary : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _selectedSlots > 1
                      ? () => setState(() => _selectedSlots--)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.remove_rounded,
                      color: _selectedSlots > 1 ? Colors.white : Colors.grey[400],
                      size: 22,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Slot count display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Primary.withOpacity(0.1),
                      Primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$_selectedSlots',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Primary,
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Increase button
              Material(
                color: _selectedSlots < widget.maxSlots ? Primary : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _selectedSlots < widget.maxSlots
                      ? () => setState(() => _selectedSlots++)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.add_rounded,
                      color: _selectedSlots < widget.maxSlots
                          ? Colors.white
                          : Colors.grey[400],
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              'Maximum ${widget.maxSlots} slots available',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
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
          colors: [
            Primary.withOpacity(0.05),
            Primary.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: Primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Price Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildPriceRow(
            'Price per slot',
            '${widget.currency} ${widget.costPerSlot}',
          ),

          const SizedBox(height: 10),

          _buildPriceRow(
            'Number of slots',
            '$_selectedSlots × ${widget.currency} ${widget.costPerSlot}',
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: Primary.withOpacity(0.2),
              thickness: 1,
            ),
          ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${widget.currency} $totalAmount',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _initiateBooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: Primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            shadowColor: Primary.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 18),
              const SizedBox(width: 10),
              Text(
                _isProcessing
                    ? 'Processing...'
                    : 'Pay ${widget.currency} $totalAmount',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}