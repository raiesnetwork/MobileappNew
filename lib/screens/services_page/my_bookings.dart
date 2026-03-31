import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/service_provider.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  String _selectedFilter = 'all';

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'value': 'all', 'icon': Icons.apps_rounded},
    {'label': 'Paid', 'value': 'SUCCESS', 'icon': Icons.check_circle_rounded},
    {'label': 'Pending', 'value': 'PENDING', 'icon': Icons.schedule_rounded},
    {'label': 'Failed', 'value': 'FAILED', 'icon': Icons.cancel_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicesProvider>().fetchMyBookings();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<ServicesProvider>().loadMoreBookings();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _applyFilter(String value) {
    setState(() => _selectedFilter = value);
    final provider = context.read<ServicesProvider>();
    if (value == 'all') {
      provider.filterBookingsByStatus(null);
    } else {
      provider.filterBookingsByStatus(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1A1D2E),
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'My Bookings',
                style: TextStyle(
                  color: Color(0xFF1A1D2E),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(color: Colors.white),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50, right: 20),
                    child: Consumer<ServicesProvider>(
                      builder: (context, provider, _) => _buildSummaryBadge(provider),
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: _buildFilterBar(),
            ),
          ),
        ],
        body: Consumer<ServicesProvider>(
          builder: (context, provider, child) {
            if (provider.isLoadingBookings && provider.myBookings.isEmpty) {
              return _buildLoadingState();
            }
            if (provider.bookingsError.isNotEmpty && provider.myBookings.isEmpty) {
              return _buildErrorState(provider);
            }
            if (provider.myBookings.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: provider.refreshBookings,
              color: const Color(0xFF6C63FF),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: provider.myBookings.length + (provider.hasMoreBookings ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == provider.myBookings.length) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  return _AnimatedBookingCard(
                    booking: provider.myBookings[index],
                    index: index,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(ServicesProvider provider) {
    final count = provider.myBookings.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count bookings',
        style: const TextStyle(
          color: Color(0xFF6C63FF),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 56,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter['value'];
          return GestureDetector(
            onTap: () => _applyFilter(filter['value']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'],
                    size: 14,
                    color: isSelected ? Colors.white : const Color(0xFF8E92A8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter['label'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF8E92A8),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, index) => const _SkeletonCard(),
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
              child: Icon(Icons.wifi_off_rounded, color: Colors.red.shade300, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.bookingsError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8E92A8), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => provider.fetchMyBookings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6C63FF), size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            'No bookings yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1D2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your service bookings will appear here',
            style: TextStyle(color: Color(0xFF8E92A8), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Booking Card ───────────────────────────────────────────────────

class _AnimatedBookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final int index;

  const _AnimatedBookingCard({required this.booking, required this.index});

  @override
  State<_AnimatedBookingCard> createState() => _AnimatedBookingCardState();
}

class _AnimatedBookingCardState extends State<_AnimatedBookingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _BookingCard(booking: widget.booking),
      ),
    );
  }
}

// ─── Booking Card ────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final service = booking['serviceId'] ?? {};
    final status = booking['paymentStatus'] ?? 'PENDING';

    return GestureDetector(
      onTap: () => _openDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top accent bar based on status
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Service Image
                  _ServiceImage(imageUrl: service['image']),
                  const SizedBox(width: 14),
                  // Service Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service['name'] ?? 'Unknown Service',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1D2E),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.currency_rupee_rounded,
                                size: 13, color: Color(0xFF6C63FF)),
                            Text(
                              '${service['cost'] ?? 0} / ${service['costPer'] ?? 'person'}',
                              style: const TextStyle(
                                color: Color(0xFF6C63FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                service['location'] ?? 'N/A',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status + Date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusPill(status: status),
                      const SizedBox(height: 8),
                      Text(
                        _formatDateShort(booking['bookingDate']),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom row: category tag + tap hint
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  _CategoryTag(label: service['category'] ?? ''),
                  const SizedBox(width: 6),
                  if ((service['subCategory'] ?? '').isNotEmpty)
                    _CategoryTag(
                      label: service['subCategory'],
                      secondary: true,
                    ),
                  const Spacer(),
                  Text(
                    'View details',
                    style: TextStyle(
                      color: const Color(0xFF6C63FF).withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: const Color(0xFF6C63FF).withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetailSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingDetailSheet(booking: booking),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
      case 'PAID':
        return const Color(0xFF00C48C);
      case 'PENDING':
        return const Color(0xFFFFB946);
      case 'FAILED':
        return const Color(0xFFFF5C5C);
      default:
        return Colors.grey.shade300;
    }
  }

  String _formatDateShort(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return 'N/A';
    }
  }
}

// ─── Booking Detail Bottom Sheet ─────────────────────────────────────────────

class _BookingDetailSheet extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingDetailSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    final service = booking['serviceId'] ?? {};
    final creator = service['creatorId'] ?? {};
    final creatorProfile = creator['profile'] ?? {};
    final community = service['communityId'] ?? {};
    final status = booking['paymentStatus'] ?? 'PENDING';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // Header
                  Row(
                    children: [
                      _ServiceImage(imageUrl: service['image'], size: 72),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service['name'] ?? 'Unknown Service',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1D2E),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _StatusPill(status: status, large: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Price highlight card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF8B84FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.currency_rupee_rounded,
                            color: Colors.white, size: 28),
                        const SizedBox(width: 4),
                        Text(
                          '${service['cost'] ?? 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'per ${service['costPer'] ?? 'person'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              service['currency'] ?? 'INR',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description (if available)
                  if ((service['description'] ?? '').isNotEmpty) ...[
                    const _SectionTitle(title: 'About'),
                    const SizedBox(height: 8),
                    Text(
                      service['description'],
                      style: const TextStyle(
                        color: Color(0xFF5A5E72),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Booking Info
                  const _SectionTitle(title: 'Booking Info'),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.receipt_outlined,
                    label: 'Booking ID',
                    value: (booking['_id'] ?? 'N/A').toString().length > 12
                        ? '...${booking['_id'].toString().substring(booking['_id'].toString().length - 8)}'
                        : booking['_id'] ?? 'N/A',
                  ),
                  _InfoTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Booking Date',
                    value: _formatDateFull(booking['bookingDate']),
                  ),
                  _InfoTile(
                    icon: Icons.access_time_rounded,
                    label: 'Created At',
                    value: _formatDateFull(booking['createdAt']),
                  ),
                  const SizedBox(height: 20),

                  // Service Info
                  const _SectionTitle(title: 'Service Details'),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.category_rounded,
                    label: 'Category',
                    value: service['category'] ?? 'N/A',
                  ),
                  _InfoTile(
                    icon: Icons.label_rounded,
                    label: 'Sub-category',
                    value: service['subCategory'] ?? 'N/A',
                  ),
                  _InfoTile(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: service['location'] ?? 'N/A',
                  ),
                  const SizedBox(height: 20),

                  // Provider Info
                  const _SectionTitle(title: 'Provider'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF6C63FF).withOpacity(0.15),
                          child: Text(
                            (creatorProfile['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                creatorProfile['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF1A1D2E),
                                ),
                              ),
                              if ((creator['email'] ?? '').isNotEmpty)
                                Text(
                                  creator['email'],
                                  style: const TextStyle(
                                    color: Color(0xFF8E92A8),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if ((community['name'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionTitle(title: 'Community'),
                    const SizedBox(height: 12),
                    _InfoTile(
                      icon: Icons.group_rounded,
                      label: 'Community',
                      value: community['name'],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateFull(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString()).toLocal();
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'N/A';
    }
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _ServiceImage extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _ServiceImage({this.imageUrl, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Container(
        width: size,
        height: size,
        color: Colors.grey.shade100,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF6C63FF).withOpacity(0.1),
      child: const Icon(Icons.image_rounded, color: Color(0xFF6C63FF), size: 24),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool large;

  const _StatusPill({required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 7 : 5,
            height: large ? 7 : 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: large ? 6 : 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: large ? 12 : 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _color() {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
      case 'PAID':
        return const Color(0xFF00C48C);
      case 'PENDING':
        return const Color(0xFFFFB946);
      case 'FAILED':
        return const Color(0xFFFF5C5C);
      default:
        return Colors.grey;
    }
  }
}

class _CategoryTag extends StatelessWidget {
  final String label;
  final bool secondary;

  const _CategoryTag({required this.label, this.secondary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: secondary
            ? Colors.grey.shade100
            : const Color(0xFF6C63FF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: secondary ? Colors.grey.shade500 : const Color(0xFF6C63FF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8E92A8),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.grey.shade100, height: 1)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8E92A8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton Loader ──────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) {
        final shimmerColor = Color.lerp(
          Colors.grey.shade200,
          Colors.grey.shade100,
          _shimmerAnim.value,
        )!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
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