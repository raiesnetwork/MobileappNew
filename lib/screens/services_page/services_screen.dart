import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ServicesScreenState extends State<ServicesScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _headerAnimController;

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

  // Category icon mapping
  final Map<String, IconData> _categoryIcons = {
    'All': Icons.apps_rounded,
    'Rental Services': Icons.home_work_rounded,
    'Educational Services': Icons.school_rounded,
    'Health and Wellness Services': Icons.favorite_rounded,
    'Financial Services': Icons.account_balance_rounded,
    'Consulting Services': Icons.support_agent_rounded,
    'Matrimonial Services': Icons.favorite_border_rounded,
    'Organizational Services': Icons.corporate_fare_rounded,
  };

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

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
    _headerAnimController.dispose();
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
            normalizedSelectedCategory
                .replaceAll(' ', '')
                .replaceAll('services', ''),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Filter by Category',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1D2E),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => dialogSetState(
                                  () => tempSelectedCategories = {'All'}),
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category list
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shrinkWrap: true,
                      children: _categories.map((category) {
                        final isSelected =
                        tempSelectedCategories.contains(category);
                        final icon =
                            _categoryIcons[category] ?? Icons.label_rounded;
                        return GestureDetector(
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Primary.withOpacity(0.06)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Primary.withOpacity(0.4)
                                    : Colors.grey.shade200,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Primary.withOpacity(0.12)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 16,
                                    color: isSelected
                                        ? Primary
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF1A1D2E)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                if (category != 'All')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Primary.withOpacity(0.1)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_getCategoryCount(category)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Primary
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color:
                                    isSelected ? Primary : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Primary
                                          : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded,
                                      size: 12, color: Colors.white)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Apply button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategories =
                                Set.from(tempSelectedCategories);
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
      final serviceCategory =
          service['category']?.toString().toLowerCase() ?? '';
      final selectedCategory = category.toLowerCase();
      return serviceCategory.contains(selectedCategory
          .replaceAll(' ', '')
          .replaceAll('services', '')) ||
          serviceCategory == selectedCategory;
    }).length;
  }

  // ── Search Bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        focusNode: _searchFocusNode,
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1D2E),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search services...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.grey.shade400, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 12),
            ),
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
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ── Filter + Bookings Row ───────────────────────────────────────────────────
  Widget _buildFilterChip() {
    final hasActiveFilter =
        _selectedCategories.isNotEmpty && !_selectedCategories.contains('All');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Filter button
          GestureDetector(
            onTap: _showFilterDialog,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: hasActiveFilter ? Primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: hasActiveFilter
                        ? Primary.withOpacity(0.25)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: hasActiveFilter ? Colors.white : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasActiveFilter
                        ? '${_selectedCategories.length} Filter${_selectedCategories.length > 1 ? 's' : ''}'
                        : 'Filters',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hasActiveFilter
                          ? Colors.white
                          : Colors.grey.shade700,
                    ),
                  ),
                  if (hasActiveFilter) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategories = {'All'}),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          // My Bookings button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MyBookingsScreen()),
              );
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'My Bookings',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
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

  // ── Status Chip ─────────────────────────────────────────────────────────────
  Widget _buildStatusChip(String? status) {
    if (status == null) return const SizedBox.shrink();

    Color chipColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'active':
        chipColor = const Color(0xFF00C48C).withOpacity(0.1);
        textColor = const Color(0xFF00A876);
        icon = Icons.check_circle_rounded;
        break;
      case 'inactive':
        chipColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red.shade600;
        icon = Icons.cancel_rounded;
        break;
      case 'pending':
        chipColor = const Color(0xFFFFB946).withOpacity(0.12);
        textColor = const Color(0xFFE09000);
        icon = Icons.schedule_rounded;
        break;
      default:
        chipColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey.shade600;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Image URL helper ────────────────────────────────────────────────────────
  String? _getImageUrl(dynamic imageData) {
    if (imageData == null) return null;
    if (imageData is List && imageData.isNotEmpty) {
      final firstImage = imageData[0];
      if (firstImage is String && firstImage.isNotEmpty) return firstImage;
    }
    if (imageData is String && imageData.isNotEmpty) return imageData;
    return null;
  }

  // ── Service Card ────────────────────────────────────────────────────────────
  Widget _buildServiceCard({required dynamic service}) {
    if (service is! Map<String, dynamic>) return const SizedBox.shrink();

    final serviceMap = service as Map<String, dynamic>;
    final String? imageUrl = _getImageUrl(serviceMap['image']);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailsScreen(
                serviceId: serviceMap['_id']?.toString() ?? ''),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  // Image or placeholder
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 160,
                        color: Colors.grey.shade100,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes !=
                                null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                            color: Primary,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                      : _imagePlaceholder(),

                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Category badge – top right
                  if (serviceMap['category'] != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          serviceMap['category'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                  // Status chip – bottom left of image
                  if (serviceMap['status'] != null)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: _buildStatusChip(
                          serviceMap['status']?.toString()),
                    ),
                ],
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    serviceMap['name']?.toString() ?? 'Unnamed Service',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1D2E),
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  if (serviceMap['description'] != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      serviceMap['description'].toString(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ── Bottom row: price + book button ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Starting from',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${serviceMap['currency'] ?? 'INR'} ',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Primary,
                                ),
                              ),
                              Text(
                                '${serviceMap['cost'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                ' / ${serviceMap['costPer'] ?? 'person'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Book button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingScreen(
                                serviceId: serviceMap['_id'] ?? '',
                                serviceName: serviceMap['name'] ?? 'Service',
                                costPerSlot: serviceMap['cost'] ?? 0,
                                currency: serviceMap['currency'] ?? 'INR',
                                maxSlots: serviceMap['slots'] ?? 10,
                                serviceImage:
                                _getImageUrl(serviceMap['image']) ?? '',
                                location: serviceMap['location'] ?? '',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            color: Primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.bolt_rounded,
                                  size: 15, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Book Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
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

  Widget _imagePlaceholder() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Primary.withOpacity(0.12),
            Primary.withOpacity(0.04),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.image_rounded,
            size: 36, color: Primary.withOpacity(0.4)),
      ),
    );
  }

  // ── Empty / Error / Loading States ──────────────────────────────────────────
  Widget _buildEmptyState(bool isFiltered) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                size: 36,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No services found' : 'No services available',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Try adjusting your filters or search'
                  : 'Check back later for new services',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500, height: 1.4),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _selectedCategories = {'All'};
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                }),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(foregroundColor: Primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ServicesProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  color: Colors.red.shade300, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              provider.message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => provider.fetchServices(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        final filteredServices = _getFilteredServices(provider.services);
        final isFiltered = _searchQuery.isNotEmpty ||
            (_selectedCategories.isNotEmpty &&
                !_selectedCategories.contains('All'));

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D2E),
                    letterSpacing: -0.5,
                  ),
                ),
                if (provider.services.isNotEmpty)
                  Text(
                    '${filteredServices.length} available',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MyProductsScreen()),
                    );
                  },
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.trolley,
                        color: Colors.grey.shade600, size: 20),
                  ),
                  tooltip: 'View Products',
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const CreateServiceScreen(communityId: ''),
                ),
              );
            },
            backgroundColor: Primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Add Service',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
          ),
          body: Column(
            children: [
              // White top section: search + filters
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 4),
                    _buildFilterChip(),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              // Subtle divider
              Container(
                height: 1,
                color: Colors.grey.shade100,
              ),
              // Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                  await provider.fetchServices(refresh: true),
                  color: Primary,
                  child: provider.isLoading
                      ? _buildSkeletonList()
                      : provider.hasError
                      ? _buildErrorState(provider)
                      : filteredServices.isEmpty
                      ? _buildEmptyState(isFiltered)
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        16, 16, 16, 100),
                    itemCount: filteredServices.length +
                        (provider.isLoadingMoreServices ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filteredServices.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      return _buildServiceCard(
                          service: filteredServices[index]);
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

  // ── Skeleton loader ──────────────────────────────────────────────────────────
  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: 4,
      itemBuilder: (_, index) => const _SkeletonServiceCard(),
    );
  }
}

// ─── Skeleton Service Card ────────────────────────────────────────────────────
class _SkeletonServiceCard extends StatefulWidget {
  const _SkeletonServiceCard();

  @override
  State<_SkeletonServiceCard> createState() => _SkeletonServiceCardState();
}

class _SkeletonServiceCardState extends State<_SkeletonServiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c =
        Color.lerp(Colors.grey.shade200, Colors.grey.shade100, _anim.value)!;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image skeleton
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 16,
                        width: 160,
                        decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(
                        height: 12,
                        width: 200,
                        decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                            height: 24,
                            width: 80,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(6))),
                        Container(
                            height: 38,
                            width: 100,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(12))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}