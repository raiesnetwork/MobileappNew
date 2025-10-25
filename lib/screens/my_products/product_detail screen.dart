import 'dart:convert';
import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Helper method to get price option display info
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

    // Combine main image and sub-images for display
    final images = mainImage != null ? [mainImage, ...subImages] : subImages;

    // Get price option info
    final priceOptionInfo = _getPriceOptionInfo(widget.product['priceOption']);

    return Scaffold(
      appBar: AppBar(
        title: Text(
           'Product Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18, // Reduced font size
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
                height: 280, // Reduced height
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
                height: 280, // Reduced height
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
                      SizedBox(height: 6), // Reduced gap
                      Text(
                        'No images available',
                        style: TextStyle(color: Colors.grey, fontSize: 14), // Reduced font size
                      ),
                    ],
                  ),
                ),
              ),

            // Image indicator dots
            if (images.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6), // Reduced padding
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: images.asMap().entries.map((entry) {
                    return Container(
                      width: 6, // Reduced size
                      height: 6, // Reduced size
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

            // Sub-images thumbnail row (if available)
            if (images.length > 1)
              Container(
                height: 70, // Reduced height
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
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
                        width: 50, // Reduced size
                        height: 50, // Reduced size
                        margin: const EdgeInsets.only(right: 6), // Reduced margin
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _currentImageIndex == index
                                ? Theme.of(context).primaryColor
                                : Colors.grey[300]!,
                            width: _currentImageIndex == index ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(6), // Reduced radius
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4), // Reduced radius
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
              padding: const EdgeInsets.all(12.0), // Reduced padding
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
                          style: const TextStyle(
                            fontSize: 20, // Reduced font size
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8), // Reduced gap
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Reduced padding
                        decoration: BoxDecoration(
                          color: priceOptionInfo['bgColor'],
                          borderRadius: BorderRadius.circular(10), // Reduced radius
                          border: Border.all(
                            color: priceOptionInfo['color'],
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              priceOptionInfo['icon'],
                              size: 14, // Reduced size
                              color: priceOptionInfo['color'],
                            ),
                            const SizedBox(width: 4), // Reduced gap
                            Text(
                              priceOptionInfo['text'],
                              style: TextStyle(
                                fontSize: 12, // Reduced font size
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
                    const SizedBox(height: 6), // Reduced gap
                    Text(
                      widget.product['brandName'],
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 14, // Reduced font size
                        color: Colors.grey,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12), // Reduced gap

                  // Price
                  Text(
                    widget.product['priceOption'] == 'free'
                        ? 'Free'
                        : widget.product['priceOption'] == 'auctions'
                        ? 'Starting Bid: ${widget.product['currency'] ?? ''}${widget.product['price'] ?? 'N/A'}'
                        : widget.product['priceOption'] == 'exchange'
                        ? 'Exchange Item'
                        : '${widget.product['currency'] ?? ''}${widget.product['price'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 18, // Reduced font size
                      fontWeight: FontWeight.bold,
                      color: priceOptionInfo['color'],
                    ),
                  ),

                  const SizedBox(height: 12), // Reduced gap

                  // Product Count
                  Row(
                    children: [
                      Icon(Icons.inventory, size: 18, color: Colors.grey[600]), // Reduced size
                      const SizedBox(width: 6), // Reduced gap
                      Text(
                        '${widget.product['productCount'] ?? 'N/A'} items available',
                        style: TextStyle(
                          fontSize: 14, // Reduced font size
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16), // Reduced gap

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16, // Reduced font size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced gap
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final description = widget.product['description'] ?? 'No description available';
                      final textSpan = TextSpan(
                        text: description,
                        style: const TextStyle(fontSize: 14, height: 1.4), // Reduced font size and line height
                      );
                      final textPainter = TextPainter(
                        text: textSpan,
                        maxLines: 2,
                        textDirection: TextDirection.ltr,
                      );
                      textPainter.layout(maxWidth: constraints.maxWidth);

                      final isOverflowing = textPainter.didExceedMaxLines;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14, // Reduced font size
                              height: 1.4, // Reduced line height
                            ),
                            maxLines: _isDescriptionExpanded ? null : 2,
                            overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
                          ),
                          if (isOverflowing)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isDescriptionExpanded = !_isDescriptionExpanded;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6), // Reduced padding
                                child: Text(
                                  _isDescriptionExpanded ? 'See Less' : 'See More',
                                  style: TextStyle(
                                    fontSize: 14, // Reduced font size
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

                  const SizedBox(height: 16), // Reduced gap

                  // Add to Cart and Buy Now buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Added to cart!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart_outlined, size: 18), // Reduced size
                          label: const Text('Add to cart', style: TextStyle(fontSize: 14)), // Reduced font size
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            padding: const EdgeInsets.symmetric(vertical: 10), // Reduced padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6), // Reduced radius
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8), // Reduced gap
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Proceeding to buy now!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('Buy Now', style: TextStyle(fontSize: 14)), // Reduced font size
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10), // Reduced padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6), // Reduced radius
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12), // Reduced gap

                  // Privacy Policy
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Privacy Policy', style: TextStyle(fontSize: 16)), // Reduced font size
                          content: const Text('Privacy policy content goes here...', style: TextStyle(fontSize: 14)), // Reduced font size
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close', style: TextStyle(fontSize: 14)), // Reduced font size
                            ),
                          ],
                        ),
                      );
                    },
                    child: Center(
                      child: Text(
                        'Refund and Cancellation Policy',
                        style: TextStyle(
                          fontSize: 12, // Reduced font size
                          color: Colors.grey[600],
                          decoration: TextDecoration.underline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6), // Reduced gap

                  // Copyright
                  Center(
                    child: Text(
                      '© 2023 GES Global Solutions private limited. All rights reserved.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16), // Reduced bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}