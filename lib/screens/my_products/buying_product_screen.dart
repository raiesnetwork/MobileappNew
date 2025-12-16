import 'package:flutter/material.dart';
import 'package:ixes.app/providers/service_provider.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../constants/constants.dart';


class ProductPurchaseScreen extends StatefulWidget {
  final String dealerId;
  final List<Map<String, dynamic>> productDetails;
  final num totalAmount;
  final String addressId;
  final Map<String, dynamic>? couponData;
  final String type; // 'normal' or 'business'
  final String? businessDealerId;
  final String courierId;
  final Map<String, dynamic> customerDetails;

  const ProductPurchaseScreen({
    Key? key,
    required this.dealerId,
    required this.productDetails,
    required this.totalAmount,
    required this.addressId,
    this.couponData,
    this.type = 'normal',
    this.businessDealerId,
    this.courierId = 'shiprocket',
    required this.customerDetails,
  }) : super(key: key);

  @override
  State<ProductPurchaseScreen> createState() => _ProductPurchaseScreenState();
}

class _ProductPurchaseScreenState extends State<ProductPurchaseScreen> {
  late Razorpay _razorpay;
  bool _isProcessing = false;
  String _razorpayKeyId = 'rzp_test_R9SkYwGQh6HuUF';

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();

    // Defer API call until after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createPartnerOrder();
    });
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

  Future<void> _createPartnerOrder() async {
    if (!mounted) return;

    setState(() => _isProcessing = true);

    try {
      final provider = Provider.of<ServicesProvider>(context, listen: false);

      final orderResult = await provider.createPartnerOrder(
        dealerId: widget.dealerId,
        amount: widget.totalAmount,
        customerDetails: widget.customerDetails,
      );

      if (!mounted) return;

      if (orderResult['err']) {
        setState(() => _isProcessing = false);

        if (orderResult['message']?.contains('OAuth') == true) {
          _showSnackBar(
            'Dealer payment not configured. Please contact support.',
            isError: true,
          );
        } else {
          _showSnackBar(orderResult['message'], isError: true);
        }
        return;
      }

      final order = orderResult['order'];
      _razorpayKeyId = orderResult['key_id'] ?? '';

      if (order == null || order.isEmpty || _razorpayKeyId.isEmpty) {
        setState(() => _isProcessing = false);
        _showSnackBar('Failed to create payment order', isError: true);
        return;
      }

      setState(() => _isProcessing = false);

    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _initiatePayment() async {
    final provider = Provider.of<ServicesProvider>(context, listen: false);
    final order = provider.paymentOrder;

    if (order.isEmpty || _razorpayKeyId.isEmpty) {
      _showSnackBar('Payment order not created', isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    _openRazorpayCheckout(order);
  }

  void _openRazorpayCheckout(Map<String, dynamic> order) {
    var options = {
      'key': _razorpayKeyId,
      'amount': order['amount'],
      'order_id': order['id'],
      'name': 'Product Purchase',
      'description': 'Order for ${widget.productDetails.length} product(s)',
      'prefill': {
        'contact': widget.customerDetails['phone'] ?? '9999999999',
        'email': widget.customerDetails['email'] ?? 'customer@example.com',
        'name': widget.customerDetails['name'] ?? 'Customer',
      },
      'theme': {
        'color': '#${Primary.value.toRadixString(16).substring(2, 8)}',
      },
      'notes': {
        'dealer_id': widget.dealerId,
        'type': widget.type,
        'products_count': widget.productDetails.length.toString(),
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnackBar('Error opening payment: ${e.toString()}', isError: true);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('✅ Payment Success:');
    print('Payment ID: ${response.paymentId}');
    print('Order ID: ${response.orderId}');
    print('Signature: ${response.signature}');

    final paymentId = response.paymentId;
    final orderId = response.orderId;
    final signature = response.signature;

    // Wait a bit for Razorpay UI to close
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) {
      print('⚠️ Widget unmounted, cannot proceed');
      return;
    }

    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      setState(() => _isProcessing = true);

      try {
        final provider = Provider.of<ServicesProvider>(context, listen: false);

        final verifyResult = await provider.verifyPaymentAndCreateOrder(
          response: {
            'razorpay_payment_id': paymentId,
            'razorpay_order_id': orderId,
            'razorpay_signature': signature,
          },
          productDetails: widget.productDetails,
          totalAmount: widget.totalAmount,
          paymentMethod: 'online',
          addressId: widget.addressId,
          couponData: widget.couponData,
          type: widget.type,
          businessDealerId: widget.businessDealerId,
          courierId: widget.courierId,
          dealerId: widget.dealerId,
        );

        if (!mounted) {
          print('⚠️ Widget unmounted after verification');
          return;
        }

        setState(() => _isProcessing = false);

        print('🔍 Verify Result: $verifyResult');
        print('🔍 Error flag: ${verifyResult['err']}');

        final hasError = verifyResult['err'] == true ||
            verifyResult['err'] == 'true' ||
            verifyResult['err'] == null;

        if (!hasError) {
          final orderData = verifyResult['data'];
          if (orderData != null && orderData.isNotEmpty) {
            _showSuccessDialog(orderData);
          } else {
            print('⚠️ Order data: $orderData');
            _showSnackBar(
              'Payment successful but order data is missing',
              isError: true,
            );
          }
        } else {
          final message = verifyResult['message'] ?? 'Payment verification failed';
          print('❌ Verification failed: $message');
          _showSnackBar(message, isError: true);
        }
      } catch (e) {
        print('💥 Error in _handlePaymentSuccess: $e');
        print('💥 Stack trace: ${StackTrace.current}');

        if (!mounted) return;

        setState(() => _isProcessing = false);
        _showSnackBar('Error verifying payment: ${e.toString()}', isError: true);
      }
    });
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment Error:');
    print('Code: ${response.code}');
    print('Message: ${response.message}');

    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() => _isProcessing = false);

      _showSnackBar(
        'Payment failed: ${response.message ?? "Unknown error"}',
        isError: true,
      );
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('🔗 External Wallet: ${response.walletName}');

    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() => _isProcessing = false);

      _showSnackBar('External wallet selected: ${response.walletName}');
    });
  }

  void _showSuccessDialog(Map<String, dynamic> orderData) {
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
              // Success Icon
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
                'Order Placed Successfully!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Your order has been confirmed and will be shipped soon',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 24),

              // Order Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.shopping_bag_rounded,
                      'Products',
                      '${widget.productDetails.length} item(s)',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.local_shipping_rounded,
                      'Status',
                      orderData['status'] ?? 'NEW',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.account_balance_wallet_rounded,
                      'Amount Paid',
                      'INR ${orderData['totalAmount'] ?? widget.totalAmount}',
                      isHighlight: true,
                    ),
                    if (orderData['orderData']?['awb_code'] != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.qr_code_rounded,
                        'AWB Code',
                        orderData['orderData']['awb_code'],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Order ID
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Order ID: ${orderData['_id'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                        // Navigate to orders screen
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Primary,
                        side: BorderSide(color: Primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'View Orders',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon,
      String label,
      String value, {
        bool isHighlight = false,
      }) {
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
    if (!mounted) return;

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

  num get subtotal {
    num total = 0;
    for (var product in widget.productDetails) {
      final price = product['price'] ?? 0;
      final quantity = product['quantity'] ?? 1;
      total += (price * quantity);
    }
    return total;
  }

  num get discount {
    if (widget.couponData != null) {
      return widget.couponData!['discount'] ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Complete Purchase',
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
                    // Header Section
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_cart_checkout_rounded,
                            size: 48,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Review Your Order',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.productDetails.length} product(s) in cart',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProductsList(),
                          const SizedBox(height: 20),
                          _buildCustomerDetails(),
                          const SizedBox(height: 20),
                          _buildPriceSummary(),
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

  Widget _buildProductsList() {
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
                'Products',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.productDetails.map((product) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_rounded,
                      color: Colors.grey[400],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'Product',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${product['quantity'] ?? 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'INR ${(product['price'] ?? 0) * (product['quantity'] ?? 1)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Primary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCustomerDetails() {
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
                  Icons.person_rounded,
                  color: Primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Customer Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.person_outline,
            widget.customerDetails['name'] ?? 'N/A',
          ),
          if (widget.customerDetails['email'] != null) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.email_outlined,
              widget.customerDetails['email'],
            ),
          ],
          if (widget.customerDetails['phone'] != null) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.phone_outlined,
              widget.customerDetails['phone'],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSummary() {
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
          _buildPriceRow('Subtotal', 'INR $subtotal'),
          if (discount > 0) ...[
            const SizedBox(height: 10),
            _buildPriceRow(
              'Discount',
              '- INR $discount',
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 10),
          _buildPriceRow('Shipping', widget.courierId.toUpperCase()),
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
                  'INR ${widget.totalAmount}',
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

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false}) {
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDiscount ? const Color(0xFF10B981) : const Color(0xFF1F2937),
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
    onPressed: _isProcessing ? null : _initiatePayment,
    style: ElevatedButton.styleFrom(
    backgroundColor: Primary,
    foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.grey[300],
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
    ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_rounded, size: 18),
          const SizedBox(width: 10),
          Text(
            _isProcessing
                ? 'Processing...'
                : 'Pay INR ${widget.totalAmount}',
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