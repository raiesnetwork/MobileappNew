import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/constants.dart';
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
  final PageController _pageController = PageController();
  bool _isDescriptionExpanded = false;
  String? selectedAddressId;
  int selectedQuantity = 1;

  @override
  void initState() {
    super.initState();
    print('📦 Product Data: ${widget.product}');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleBuyNow() async {
    String? redirectLink = widget.product['redirectLink']?.toString();

    if (redirectLink == null || redirectLink.isEmpty) {
      final productId = widget.product['_id']?.toString();
      if (productId != null && productId.isNotEmpty) {
        redirectLink = 'https://mystore.ixes.ai/details/$productId';
      }
    }

    if (redirectLink == null || redirectLink.isEmpty) {
      _showError('No purchase link available for this product.');
      return;
    }

    final uri = Uri.tryParse(redirectLink);
    if (uri == null) {
      _showError('Invalid product link.');
      return;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open the purchase page.');
      }
    } catch (e) {
      _showError('Error opening link: ${e.toString()}');
    }
  }

  Future<void> _selectAddress() async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressSelectionScreen()),
    );

    if (selectedAddress != null) {
      setState(() => selectedAddressId = selectedAddress['_id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address selected successfully'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ====================== IMAGE HANDLING ======================

  bool _isSvg(String imageStr) {
    if (imageStr.isEmpty) return false;
    final lower = imageStr.toLowerCase();
    return lower.contains('svg+xml') ||
        lower.contains('<svg') ||
        imageStr.startsWith('PD94bWwgdmVyc2lvbj0iMS4w');
  }

  Uint8List? _decodeRasterImage(String imageStr) {
    try {
      String base64Data = imageStr;
      if (imageStr.contains(',')) {
        base64Data = imageStr.split(',').last.trim();
      }
      base64Data = base64Data.replaceAll(RegExp(r'\s+'), ''); // clean whitespace
      return base64Decode(base64Data);
    } catch (e) {
      print("❌ Raster decode error: $e");
      return null;
    }
  }

  String? _decodeSvg(String imageStr) {
    try {
      String base64Data = imageStr;
      if (imageStr.contains(',')) {
        base64Data = imageStr.split(',').last.trim();
      }
      base64Data = base64Data.replaceAll(RegExp(r'\s+'), '');
      return utf8.decode(base64Decode(base64Data));
    } catch (e) {
      print("❌ SVG decode error: $e");
      return null;
    }
  }

  Widget _buildImageWidget(dynamic imageData) {
    if (imageData == null) {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      );
    }

    final String imageStr = imageData.toString().trim();

    if (_isSvg(imageStr)) {
      final svgString = _decodeSvg(imageStr);
      if (svgString != null) {
        return SvgPicture.string(
          svgString,
          fit: BoxFit.cover,
          placeholderBuilder: (context) => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
    } else {
      final bytes = _decodeRasterImage(imageStr);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print("❌ Image.memory error: $error");
            return const Center(
              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
            );
          },
        );
      }
    }

    return const Center(
      child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Collect all images (mainImage + subImages)
    final List<dynamic> allImages = [];

    final mainImage = widget.product['mainImage'];
    if (mainImage != null && mainImage.toString().isNotEmpty) {
      allImages.add(mainImage);
    }

    final subImages = widget.product['subImages'] as List<dynamic>? ?? [];
    allImages.addAll(subImages);

    final priceOptionInfo = _getPriceOptionInfo(widget.product['priceOption']);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Product Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Primary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Primary),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Image with PageView
            if (allImages.isNotEmpty)
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: allImages.length,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _buildImageWidget(allImages[index]);
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
                      Text('No images available',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
              ),

            // Image indicator dots
            if (allImages.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: allImages.asMap().entries.map((entry) {
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

            // Sub-images thumbnails
            if (allImages.length > 1)
              Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: allImages.length,
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
                          child: _buildImageWidget(allImages[index]),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ================== Product Details Section (Unchanged) ==================
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  if (widget.product['brandName'] != null &&
                      widget.product['brandName'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.product['brandName'],
                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14, color: Colors.grey),
                    ),
                  ],

                  const SizedBox(height: 12),

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
                        child: Text('$selectedQuantity',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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