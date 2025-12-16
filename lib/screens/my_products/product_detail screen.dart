import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'addres_selection.dart';
import 'buying_product_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentImageIndex = 0;
  PageController _pageController = PageController();
  bool _isDescriptionExpanded = false;
  String? selectedAddressId;
  int selectedQuantity = 1;

  @override
  void initState() {
    super.initState();
    print('📦 Product Data: ${widget.product}');
    print('🏪 Dealer ID: ${widget.product['user']}');
    print('🆔 Product ID: ${widget.product['_id']}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getPriceOptionInfo(String? priceOption) {
    switch (priceOption?.toLowerCase()) {
      case 'free':
        return {
          'text': 'Free',
          'color': Colors.green,
          'icon': Icons.card_giftcard,
          'bgColor': Colors.green.withOpacity(0.1),
        };
      case 'auctions':
        return {
          'text': 'Auction',
          'color': Colors.purple,
          'icon': Icons.gavel,
          'bgColor': Colors.purple.withOpacity(0.1),
        };
      case 'exchange':
        return {
          'text': 'Exchange',
          'color': Colors.teal,
          'icon': Icons.swap_horiz,
          'bgColor': Colors.teal.withOpacity(0.1),
        };
      case 'normal':
      default:
        return {
          'text': 'For Sale',
          'color': Colors.blue,
          'icon': Icons.attach_money,
          'bgColor': Colors.blue.withOpacity(0.1),
        };
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleBuyNow() async {
    print('🛒 Buy Now button pressed');

    // FIXED: Dealer ID is in the 'user' field
    final dealerId = widget.product['user'] ??
        widget.product['userId'] ??
        widget.product['dealerId'];

    final productId = widget.product['_id'];
    final productName = widget.product['productName'];
    final productPrice = widget.product['price'];

    print('🔍 Extracted Data:');
    print('   Dealer ID: $dealerId');
    print('   Product ID: $productId');
    print('   Product Name: $productName');
    print('   Product Price: $productPrice');

    // Validate dealerId exists and is not empty
    if (dealerId == null || dealerId.toString().isEmpty) {
      print('❌ Dealer ID is missing!');
      print('📋 Available product fields: ${widget.product.keys.toList()}');
      _showError('Dealer information is missing. Cannot proceed with purchase.');
      return;
    }

    // Validate product ID
    if (productId == null || productId.toString().isEmpty) {
      print('❌ Product ID is missing!');
      _showError('Product information is incomplete');
      return;
    }

    // Validate price
    if (productPrice == null) {
      print('❌ Product price is missing!');
      _showError('Product price is not available');
      return;
    }

    // Check if address is selected
    if (selectedAddressId == null || selectedAddressId!.isEmpty) {
      print('⚠️ No address selected');

      // Navigate to address selection
      final selectedAddress = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddressSelectionScreen(),
        ),
      );

      if (selectedAddress != null) {
        setState(() {
          selectedAddressId = selectedAddress['_id'];
        });

        // Retry buy now after address selection
        _handleBuyNow();
        return;
      } else {
        _showError('Please select a delivery address to continue');
        return;
      }
    } // FIXED: Added missing closing brace

    try {
      // Get user details from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ??
          prefs.getString('name') ??
          'Customer';
      final userEmail = prefs.getString('user_email') ??
          prefs.getString('email') ??
          '';
      final userPhone = prefs.getString('user_phone') ??
          prefs.getString('phone') ??
          '9999999999';

      print('👤 User Details:');
      print('   Name: $userName');
      print('   Email: $userEmail');
      print('   Phone: $userPhone');

      // Calculate total amount
      final price = productPrice is String
          ? double.tryParse(productPrice) ?? 0
          : (productPrice is num ? productPrice.toDouble() : 0.0);

      final totalAmount = price * selectedQuantity;

      print('💰 Payment Details:');
      print('   Price per item: $price');
      print('   Quantity: $selectedQuantity');
      print('   Total Amount: $totalAmount');

      // Validate minimum amount
      if (totalAmount <= 0) {
        _showError('Product price must be greater than 0');
        return;
      }

      print('✅ All validations passed. Navigating to purchase screen...');

      // Navigate to purchase screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductPurchaseScreen(
            dealerId: dealerId.toString(),
            productDetails: [
              {
                '_id': productId.toString(),
                'name': productName ?? 'Product',
                'price': price,
                'quantity': selectedQuantity,
              }
            ],
            totalAmount: totalAmount,
            addressId: selectedAddressId!,
            customerDetails: {
              'name': userName,
              'email': userEmail.isNotEmpty ? userEmail : 'customer@example.com',
              'phone': userPhone,
            },
            couponData: null,
            type: 'normal',
            courierId: 'shiprocket',
          ),
        ),
      );
    } catch (e) {
      print('💥 Error in _handleBuyNow: $e');
      _showError('Error: ${e.toString()}');
    }
  }

  Future<void> _selectAddress() async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressSelectionScreen(),
      ),
    );

    if (selectedAddress != null) {
      setState(() {
        selectedAddressId = selectedAddress['_id'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Address selected successfully'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Decode images
    final mainImage = widget.product['mainImage'] != null
        ? base64Decode(widget.product['mainImage'].split(',').last)
        : null;
    final subImages = (widget.product['subImages'] as List<dynamic>?)
        ?.map((img) => base64Decode(img.split(',').last))
        .toList() ??
        [];

    final images = mainImage != null ? [mainImage, ...subImages] : subImages;
    final priceOptionInfo = _getPriceOptionInfo(widget.product['priceOption']);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Product Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Image
            if (images.isNotEmpty)
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Image.memory(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      SizedBox(height: 6),
                      Text('No images available', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
              ),

            // Image indicator dots
            if (images.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: images.asMap().entries.map((entry) {
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == entry.key
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Sub-images thumbnail row
            if (images.length > 1)
              Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _currentImageIndex == index
                                ? Theme.of(context).primaryColor
                                : Colors.grey[300]!,
                            width: _currentImageIndex == index ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image, size: 16, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Product Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name and Price Option Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product['productName'] ?? 'Unnamed Product',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: priceOptionInfo['bgColor'],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: priceOptionInfo['color'], width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(priceOptionInfo['icon'], size: 14, color: priceOptionInfo['color']),
                            const SizedBox(width: 4),
                            Text(
                              priceOptionInfo['text'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: priceOptionInfo['color'],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Brand Name
                  if (widget.product['brandName'] != null &&
                      widget.product['brandName'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.product['brandName'],
                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14, color: Colors.grey),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Price
                  Text(
                    widget.product['priceOption'] == 'free'
                        ? 'Free'
                        : widget.product['priceOption'] == 'auctions'
                        ? 'Starting Bid: ${widget.product['currency'] ?? ''}${widget.product['price'] ?? 'N/A'}'
                        : widget.product['priceOption'] == 'exchange'
                        ? 'Exchange Item'
                        : '${widget.product['currency'] ?? 'INR '}${widget.product['price'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: priceOptionInfo['color'],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Product Count
                  Row(
                    children: [
                      Icon(Icons.inventory, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.product['productCount'] ?? 'N/A'} items available',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quantity Selector
                  Row(
                    children: [
                      const Text('Quantity: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      IconButton(
                        onPressed: () {
                          if (selectedQuantity > 1) setState(() => selectedQuantity--);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 24,
                        color: Theme.of(context).primaryColor,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('$selectedQuantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        onPressed: () => setState(() => selectedQuantity++),
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 24,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description
                  const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final description = widget.product['description'] ?? 'No description available';
                      final textSpan = TextSpan(text: description, style: const TextStyle(fontSize: 14, height: 1.4));
                      final textPainter = TextPainter(text: textSpan, maxLines: 2, textDirection: TextDirection.ltr);
                      textPainter.layout(maxWidth: constraints.maxWidth);
                      final isOverflowing = textPainter.didExceedMaxLines;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            description,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                            maxLines: _isDescriptionExpanded ? null : 2,
                            overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
                          ),
                          if (isOverflowing)
                            GestureDetector(
                              onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _isDescriptionExpanded ? 'See Less' : 'See More',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Address Selection Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: InkWell(
                      onTap: _selectAddress,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedAddressId != null
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: selectedAddressId != null ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedAddressId != null ? 'Delivery Address Selected' : 'Select Delivery Address',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: selectedAddressId != null ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedAddressId != null ? 'Tap to change' : 'Required for checkout',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to cart!'), duration: Duration(seconds: 2)),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                          label: const Text('Add to cart', style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleBuyNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Buy Now', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Privacy Policy
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Privacy Policy', style: TextStyle(fontSize: 16)),
                          content: const Text('Privacy policy content goes here...', style: TextStyle(fontSize: 14)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close', style: TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Center(
                      child: Text(
                        'Refund and Cancellation Policy',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          decoration: TextDecoration.underline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Copyright
                  Center(
                    child: Text(
                      '© 2023 GES Global Solutions private limited. All rights reserved.',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}