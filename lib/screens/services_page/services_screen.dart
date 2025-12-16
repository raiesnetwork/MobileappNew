import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/screens/services_page/service_details.dart';
import 'package:provider/provider.dart';
import '../../providers/service_provider.dart';
import '../my_products/my_products_screen.dart';
import 'booking_screen.dart';
import 'create_service_screen.dart';
import 'my_bookings.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<String> _categories = [
    'All',
    'Rental Services',
    'Educational Services',
    'Health and Wellness Services',
    'Financial Services',
    'Consulting Services',
    'Matrimonial Services',
    'Organizational Services',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ServicesProvider>(context, listen: false);
      provider.fetchServices();
    });

    _selectedCategories = {'All'};
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<ServicesProvider>(context, listen: false);

      if (_searchQuery.isEmpty &&
          (_selectedCategories.isEmpty || _selectedCategories.contains('All'))) {
        provider.loadMoreServices();
      }
    }
  }

  List<dynamic> _getFilteredServices(List<dynamic> services) {
    List<dynamic> filteredServices = services;

    if (_selectedCategories.contains('All') || _selectedCategories.isEmpty) {
      // Return all services
    } else {
      filteredServices = filteredServices.where((service) {
        if (service is! Map<String, dynamic>) return false;
        final category = service['category']?.toString().toLowerCase() ?? '';
        return _selectedCategories.any((selectedCategory) {
          final normalizedSelectedCategory = selectedCategory.toLowerCase();
          return category.contains(
            normalizedSelectedCategory.replaceAll(' ', '').replaceAll('services', ''),
          ) ||
              category == normalizedSelectedCategory;
        });
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredServices = filteredServices.where((service) {
        if (service is! Map<String, dynamic>) return false;

        final name = service['name']?.toString().toLowerCase() ?? '';
        final category = service['category']?.toString().toLowerCase() ?? '';
        final description = service['description']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return name.contains(query) ||
            category.contains(query) ||
            description.contains(query);
      }).toList();
    }

    return filteredServices;
  }

  void _showFilterDialog() {
    Set<String> tempSelectedCategories = Set.from(_selectedCategories);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                width: MediaQuery.of(context).size.width * 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.filter_list,
                            color: Primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Filter by Category',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Column(
                          children: _categories.map((category) {
                            final isSelected = tempSelectedCategories.contains(category);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () {
                                  dialogSetState(() {
                                    if (category == 'All') {
                                      tempSelectedCategories = {'All'};
                                    } else {
                                      tempSelectedCategories.remove('All');
                                      if (isSelected) {
                                        tempSelectedCategories.remove(category);
                                      } else {
                                        tempSelectedCategories.add(category);
                                      }
                                      if (tempSelectedCategories.isEmpty) {
                                        tempSelectedCategories.add('All');
                                      }
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Primary.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? Primary : Colors.grey.withOpacity(0.3),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (value) {
                                          dialogSetState(() {
                                            if (category == 'All') {
                                              tempSelectedCategories = {'All'};
                                            } else {
                                              tempSelectedCategories.remove('All');
                                              if (value == true) {
                                                tempSelectedCategories.add(category);
                                              } else {
                                                tempSelectedCategories.remove(category);
                                              }
                                              if (tempSelectedCategories.isEmpty) {
                                                tempSelectedCategories.add('All');
                                              }
                                            }
                                          });
                                        },
                                        activeColor: Primary,
                                        checkColor: Colors.white,
                                        fillColor: MaterialStateProperty.resolveWith<Color?>((states) {
                                          if (states.contains(MaterialState.selected)) {
                                            return Primary;
                                          }
                                          return Colors.grey.withOpacity(0.3);
                                        }),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            color: isSelected ? Primary : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (category != 'All') ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${_getCategoryCount(category)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              dialogSetState(() {
                                tempSelectedCategories = {'All'};
                              });
                            },
                            child: const Text(
                              'Clear Filter',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategories = Set.from(tempSelectedCategories);
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _getCategoryCount(String category) {
    final provider = Provider.of<ServicesProvider>(context, listen: false);
    if (category == 'All') return provider.services.length;

    return provider.services.where((service) {
      if (service is! Map<String, dynamic>) return false;
      final serviceCategory = service['category']?.toString().toLowerCase() ?? '';
      final selectedCategory = category.toLowerCase();
      return serviceCategory.contains(selectedCategory.replaceAll(' ', '').replaceAll('services', '')) ||
          serviceCategory == selectedCategory;
    }).length;
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        focusNode: _searchFocusNode,
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search services...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
                _searchFocusNode.unfocus();
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChip() {
    final hasActiveFilter = _selectedCategories.isNotEmpty && !_selectedCategories.contains('All');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showFilterDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasActiveFilter ? Primary.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasActiveFilter ? Primary : Colors.grey.withOpacity(0.3),
                  width: hasActiveFilter ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: hasActiveFilter ? Primary : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasActiveFilter ? '${_selectedCategories.length} selected' : 'Filter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasActiveFilter ? Primary : Colors.grey[700],
                    ),
                  ),
                  if (hasActiveFilter) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategories = {'All'};
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyBookingsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Bookings',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    if (status == null) return const SizedBox.shrink();

    Color chipColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'active':
        chipColor = Colors.green.withOpacity(0.12);
        textColor = Colors.green[700]!;
        break;
      case 'inactive':
        chipColor = Colors.red.withOpacity(0.12);
        textColor = Colors.red[700]!;
        break;
      case 'pending':
        chipColor = Colors.orange.withOpacity(0.12);
        textColor = Colors.orange[700]!;
        break;
      default:
        chipColor = Colors.grey.withOpacity(0.12);
        textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ✅ CHANGED: New method to get image URL from service data
  String? _getImageUrl(dynamic imageData) {
    if (imageData == null) return null;

    // Handle List of images
    if (imageData is List && imageData.isNotEmpty) {
      final firstImage = imageData[0];
      if (firstImage is String && firstImage.isNotEmpty) {
        return firstImage;
      }
    }

    // Handle single string URL
    if (imageData is String && imageData.isNotEmpty) {
      return imageData;
    }

    return null;
  }

  Widget _buildServiceCard({
    required dynamic service,
  }) {
    if (service is! Map<String, dynamic>) {
      return const SizedBox.shrink();
    }

    final serviceMap = service as Map<String, dynamic>;

    // ✅ CHANGED: Get image URL instead of base64
    String? imageUrl = _getImageUrl(serviceMap['image']);
    Widget imageWidget;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // ✅ CHANGED: Use NetworkImage for URL-based images
      imageWidget = Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[100],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        color: Primary,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[100],
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.08),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // ✅ UNCHANGED: Placeholder for missing images
      imageWidget = Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Primary.withOpacity(0.15),
              Primary.withOpacity(0.05),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 32,
            color: Primary.withOpacity(0.6),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailsScreen(serviceId: serviceMap['_id']?.toString() ?? ''),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            imageWidget,
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          serviceMap['name']?.toString() ?? 'Unnamed Service',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (serviceMap['category'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            serviceMap['category'].toString(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (serviceMap['description'] != null)
                    Text(
                      serviceMap['description'].toString(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusChip(serviceMap['status']?.toString()),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingScreen(
                                serviceId: serviceMap['_id'] ?? '',
                                serviceName: serviceMap['name'] ?? 'Service',
                                costPerSlot: serviceMap['cost'] ?? 0,
                                currency: serviceMap['currency'] ?? 'INR',
                                maxSlots: serviceMap['slots'] ?? 10,
                                // ✅ CHANGED: Pass image URL instead of base64
                                serviceImage: _getImageUrl(serviceMap['image']) ?? '',
                                location: serviceMap['location'] ?? '',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.book_online, size: 14),
                        label: const Text('Book'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        final filteredServices = _getFilteredServices(provider.services);

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            scrolledUnderElevation: 0,
            title: const Text(
              'All Services',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyProductsScreen()),
                    );
                  },
                  icon: Icon(Icons.trolley),
                  tooltip: 'View Products',

                ),
              ),
            ],
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateServiceScreen(communityId: ''),
                ),
              );
            },
            backgroundColor: Primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Add Service',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
          ),
          body: Column(
            children: [
              _buildSearchBar(),
              _buildFilterChip(),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await provider.fetchServices(refresh: true);
                  },
                  color: Primary,
                  child: provider.isLoading
                      ? const Center(
                    child: CircularProgressIndicator(color: Primary),
                  )
                      : provider.hasError
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 40,
                            color: Colors.red[400],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Oops! Something went wrong',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          provider.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => provider.fetchServices(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  )
                      : filteredServices.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty || _selectedCategories.isNotEmpty && !_selectedCategories.contains('All')
                              ? Icons.search_off
                              : Icons.inventory_2_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty || _selectedCategories.isNotEmpty && !_selectedCategories.contains('All')
                              ? 'No services found'
                              : 'No services available',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.isNotEmpty || _selectedCategories.isNotEmpty && !_selectedCategories.contains('All')) ...[
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _selectedCategories = {'All'};
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                              });
                            },
                            child: const Text(
                              'Clear filters',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: filteredServices.length + (provider.isLoadingMoreServices ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filteredServices.length) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            color: Primary,
                            strokeWidth: 2,
                          ),
                        );
                      }

                      final service = filteredServices[index];
                      return _buildServiceCard(service: service);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}