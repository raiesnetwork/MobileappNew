import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/screens/my_products/product_detail%20screen.dart';
import 'package:provider/provider.dart';
import '../../providers/service_provider.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({Key? key}) : super(key: key);

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  String _selectedPriceOption = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ServicesProvider>();
      if (!provider.isMyProductsLoading) {
        provider.fetchMyProducts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterProducts(List<dynamic> products) {
    return products.where((product) {
      final productPriceOption =
          product['priceOption']?.toString().toLowerCase() ?? '';
      final matchesPriceFilter = _selectedPriceOption == 'all' ||
          productPriceOption == _selectedPriceOption.toLowerCase();

      final productName =
          product['productName']?.toString().toLowerCase() ?? '';
      final matchesSearch = _searchQuery.isEmpty ||
          productName.contains(_searchQuery.toLowerCase());

      return matchesPriceFilter && matchesSearch;
    }).cast<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final servicesProvider = context.watch<ServicesProvider>();
    final filteredProducts = _filterProducts(servicesProvider.myProducts);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Products',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Primary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products by name...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: Theme.of(context).primaryColor),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Price Option Filter
                Row(
                  children: [
                    const Icon(Icons.filter_list,
                        color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Filter by:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPriceOption,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down,
                                size: 18),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Row(
                                  children: [
                                    Icon(Icons.all_inclusive,
                                        size: 16, color: Colors.blue),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('All Products',
                                          style: TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'normal',
                                child: Row(
                                  children: [
                                    Icon(Icons.attach_money,
                                        size: 16, color: Colors.green),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Priced Products',
                                          style: TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'free',
                                child: Row(
                                  children: [
                                    Icon(Icons.card_giftcard,
                                        size: 16, color: Colors.orange),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Free Products',
                                          style: TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'auctions',
                                child: Row(
                                  children: [
                                    Icon(Icons.gavel,
                                        size: 16, color: Colors.purple),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Auctions',
                                          style: TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'exchange',
                                child: Row(
                                  children: [
                                    Icon(Icons.swap_horiz,
                                        size: 16, color: Colors.teal),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Exchange',
                                          style: TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedPriceOption = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Counter
          if (!servicesProvider.isMyProductsLoading &&
              !servicesProvider.hasMyProductsError)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[50],
              child: Text(
                'Showing ${filteredProducts.length} of ${servicesProvider.myProducts.length} products',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Products Grid
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await servicesProvider.fetchMyProducts();
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedPriceOption = 'all';
                });
              },
              color: Theme.of(context).primaryColor,
              child: servicesProvider.isMyProductsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : servicesProvider.hasMyProductsError
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red[400]),
                    const SizedBox(height: 12),
                    Text(
                      servicesProvider.myProductsMessage,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: servicesProvider.fetchMyProducts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
                  : filteredProducts.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      servicesProvider.myProducts.isEmpty
                          ? Icons.inventory_2_outlined
                          : Icons.search_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      servicesProvider.myProducts.isEmpty
                          ? 'No products found.'
                          : 'No products match your filters.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    if (servicesProvider.myProducts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search or filter.',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                            _selectedPriceOption = 'all';
                          });
                        },
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear Filters'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context)
                              .primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              )
                  : GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return ProductGridCard(
                    product: product,
                    searchQuery: _searchQuery,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductGridCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String searchQuery;

  const ProductGridCard({
    Key? key,
    required this.product,
    this.searchQuery = '',
  }) : super(key: key);

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

  // Safe image decoding function for raster images (PNG/JPG)
  Uint8List? _getImageBytes() {
    final String imageStr = product['mainImage']?.toString() ?? '';
    if (imageStr.isEmpty) return null;

    try {
      String base64Data = imageStr;
      if (imageStr.contains(',')) {
        base64Data = imageStr.split(',').last.trim();
      }
      return base64Decode(base64Data);
    } catch (e) {
      print("❌ Base64 decode error for '${product['productName']}': $e");
      return null;
    }
  }

  // New method to handle both SVG and normal images
  Widget _buildProductImage() {
    final String imageStr = product['mainImage']?.toString() ?? '';
    if (imageStr.isEmpty) {
      return _noImageWidget();
    }

    // Detect if it's an SVG
    final bool isSvg = imageStr.contains('svg+xml') ||
        imageStr.toLowerCase().contains('<svg') ||
        imageStr.startsWith('PD94bWwgdmVyc2lvbj0iMS4w');

    if (isSvg) {
      try {
        String svgBase64 = imageStr;
        if (imageStr.contains(',')) {
          svgBase64 = imageStr.split(',').last.trim();
        }
        final String svgString = utf8.decode(base64Decode(svgBase64));

        return SvgPicture.string(
          svgString,
          fit: BoxFit.cover,
          placeholderBuilder: (context) => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      } catch (e) {
        print("❌ SVG decode error for '${product['productName']}': $e");
        return _errorWidget();
      }
    } else {
      // Normal raster image
      final imageBytes = _getImageBytes();
      if (imageBytes != null) {
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print("❌ Image decode failed for ${product['productName']}");
            return _errorWidget();
          },
        );
      }
    }

    return _noImageWidget();
  }

  Widget _errorWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 40, color: Colors.grey),
          SizedBox(height: 6),
          Text('Image error',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _noImageWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 36, color: Colors.grey),
          SizedBox(height: 8),
          Text('No image',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priceOptionInfo = _getPriceOptionInfo(product['priceOption']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image - Now supports SVG + Normal images
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[100],
                  child: _buildProductImage(),
                ),
              ),
            ),

            // Product Details (unchanged)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product['productName'] ?? 'Unnamed Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            product['priceOption'] == 'free'
                                ? 'Free'
                                : product['priceOption'] == 'exchange'
                                ? 'Exchange'
                                : '${product['currency'] ?? ''}${product['price'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: priceOptionInfo['color'],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priceOptionInfo['bgColor'],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: priceOptionInfo['color'],
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            priceOptionInfo['icon'],
                            size: 10,
                            color: priceOptionInfo['color'],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}