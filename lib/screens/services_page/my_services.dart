import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/service_provider.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  final Set<String> _expandedCards = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ServicesProvider>(context, listen: false);
      provider.fetchMyServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            scrolledUnderElevation: 0,
            title: const Text(
              'My Services',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
                letterSpacing: 0.2,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: const Color(0xFFEEEEF2), height: 1),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async => provider.fetchMyServices(),
            color: Primary,
            child: _buildBody(provider),
          ),
        );
      },
    );
  }

  Widget _buildBody(ServicesProvider provider) {
    if (provider.isMyServicesLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Primary),
          strokeWidth: 2,
        ),
      );
    }
    if (provider.hasMyServicesError) return _buildErrorState(provider);
    if (provider.myServices.isEmpty) return _buildEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: provider.myServices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final service = provider.myServices[index];
        return _buildServiceCard(service, provider);
      },
    );
  }

  Widget _buildServiceCard(
      Map<String, dynamic> service, ServicesProvider provider) {
    final serviceId = service['_id']?.toString() ?? '';
    final name = service['name']?.toString() ?? 'Unnamed Service';
    final image = service['image']?.toString();
    final description = service['description']?.toString() ?? 'No description';
    final category = service['category']?.toString() ?? 'N/A';
    final subCategory = service['subCategory']?.toString() ?? 'N/A';
    final cost = (service['cost'] is int
        ? (service['cost'] as int).toDouble()
        : (service['cost'] ?? 0.0)) as double;
    final capacity = service['capacity'] as int? ?? 0;
    final currency = service['currency']?.toString() ?? '';
    final availableDays = List<String>.from(service['availableDays'] ?? []);
    final location = service['location']?.toString() ?? 'N/A';
    final status = service['status']?.toString() ?? 'N/A';
    final costPer = service['costPer']?.toString() ?? '';
    final openHourFrom = service['openHourFrom']?.toString() ?? '';
    final openHourEnd = service['openHourEnd']?.toString() ?? '';

    final isExpanded = _expandedCards.contains(serviceId);
    final isActive = status == 'ACTIVE';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() {
              isExpanded
                  ? _expandedCards.remove(serviceId)
                  : _expandedCards.add(serviceId);
            }),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildServiceImage(image),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + status dot
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusDot(isActive),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Description
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7A7A8C),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // ✅ Wrap prevents overflow — chips flow to next line if needed
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildChip(
                              '$currency $cost / $costPer',
                              const Color(0xFF00C48C),
                              const Color(0xFFE6FAF5),
                            ),
                            _buildChip(
                              category,
                              const Color(0xFF6C63FF),
                              const Color(0xFFF0EEFF),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded Section ──────────────────────────────────────
          if (isExpanded) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: const Color(0xFFF0F0F4),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildToggleButton(provider, serviceId, isActive),
                      ),
                      const SizedBox(width: 8),
                      _buildMenuButton(
                          context, serviceId, name, description, provider),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildDetailsGrid(
                    category: category,
                    subCategory: subCategory,
                    cost: cost,
                    currency: currency,
                    costPer: costPer,
                    capacity: capacity,
                    location: location,
                    openHourFrom: openHourFrom,
                    openHourEnd: openHourEnd,
                  ),
                  if (availableDays.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildAvailableDays(availableDays),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusDot(bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? const Color(0xFF00C48C)
                : const Color(0xFFFF6B6B),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive
                ? const Color(0xFF00C48C)
                : const Color(0xFFFF6B6B),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildServiceImage(String? image) {
    const double size = 62;
    const radius = BorderRadius.all(Radius.circular(10));

    if (image != null &&
        image.isNotEmpty &&
        (image.startsWith('http://') || image.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          image,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _imagePlaceholder(size);
          },
          errorBuilder: (_, __, ___) => _imagePlaceholder(size),
        ),
      );
    }
    return _imagePlaceholder(size);
  }

  Widget _imagePlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.business_center_rounded,
          color: Primary.withOpacity(0.5), size: 26),
    );
  }

  Widget _buildToggleButton(
      ServicesProvider provider, String serviceId, bool isActive) {
    return GestureDetector(
      onTap: provider.isServiceActionLoading
          ? null
          : () => _handleServiceToggle(provider, serviceId, isActive),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFFF0F0)
              : const Color(0xFFF0FFF8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFFFFCDD2)
                : const Color(0xFFC8F5E2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 16,
              color: isActive
                  ? const Color(0xFFFF6B6B)
                  : const Color(0xFF00C48C),
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? 'Deactivate' : 'Activate',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF00C48C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String serviceId,
      String name, String description, ServicesProvider provider) {
    return Container(
      height: 38,
      width: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8EE)),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_horiz_rounded,
            color: Color(0xFF7A7A8C), size: 18),
        color: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 8,
        itemBuilder: (_) => [
          _popupItem(
              'edit', Icons.edit_outlined, 'Edit', const Color(0xFF6C63FF)),
          _popupItem('delete', Icons.delete_outline_rounded, 'Delete',
              const Color(0xFFFF6B6B)),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            _showEditServiceDialog(
                context, serviceId, name, description, provider);
          } else if (value == 'delete') {
            _showDeleteConfirmationDialog(context, serviceId, provider);
          }
        },
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid({
    required String category,
    required String subCategory,
    required double cost,
    required String currency,
    required String costPer,
    required int capacity,
    required String location,
    required String openHourFrom,
    required String openHourEnd,
  }) {
    final items = [
      _DetailItem(Icons.category_outlined, 'Category', category),
      _DetailItem(Icons.layers_outlined, 'Subcategory', subCategory),
      _DetailItem(
          Icons.monetization_on_outlined, 'Cost', '$currency $cost / $costPer'),
      _DetailItem(Icons.people_outline_rounded, 'Capacity', '$capacity'),
      _DetailItem(Icons.location_on_outlined, 'Location', location),
      _DetailItem(
          Icons.schedule_outlined, 'Hours', '$openHourFrom – $openHourEnd'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: items
          .map((item) => _buildDetailTile(item.icon, item.label, item.value))
          .toList(),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEF4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Primary.withOpacity(0.7)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFAAAAAA),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDays(List<String> days) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Days',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7A7A8C),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: days
              .map((day) => Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              day,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Primary.withOpacity(0.85),
              ),
            ),
          ))
              .toList(),
        ),
      ],
    );
  }

  // ── States ─────────────────────────────────────────────────────

  Widget _buildErrorState(ServicesProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F0), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  size: 34, color: Color(0xFFFF6B6B)),
            ),
            const SizedBox(height: 12),
            Text(
              provider.myServicesMessage,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A7A8C),
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => provider.fetchMyServices(),
              child: const Text('Retry',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Primary.withOpacity(0.06), shape: BoxShape.circle),
              child: Icon(Icons.business_center_outlined,
                  size: 38, color: Primary.withOpacity(0.6)),
            ),
            const SizedBox(height: 14),
            const Text(
              'No services yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your added services will appear here',
              style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────

  Future<void> _handleServiceToggle(
      ServicesProvider provider, String serviceId, bool isActive) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
        ),
        const SizedBox(width: 10),
        Text(isActive ? 'Deactivating...' : 'Activating...',
            style: const TextStyle(fontSize: 13)),
      ]),
      backgroundColor: const Color(0xFF2D2D3A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 2),
    ));

    if (isActive) {
      await provider.deactivateMyService(serviceId);
    } else {
      await provider.activateMyService(serviceId);
    }

    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(provider.serviceActionMessage,
          style: const TextStyle(fontSize: 13)),
      backgroundColor: provider.hasServiceActionError
          ? const Color(0xFFFF6B6B)
          : const Color(0xFF00C48C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _showEditServiceDialog(
      BuildContext context,
      String serviceId,
      String currentName,
      String currentDescription,
      ServicesProvider provider) async {
    final nameController = TextEditingController(text: currentName);
    final descController = TextEditingController(text: currentDescription);

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.all(20),
        title: const Text('Edit Service',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(nameController, 'Service Name'),
            const SizedBox(height: 10),
            _buildTextField(descController, 'Description', maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            ),
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Updated successfully',
                      style: TextStyle(fontSize: 13)),
                  backgroundColor: const Color(0xFF00C48C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ));
              }
            },
            child: const Text('Update',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEEEEF4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEEEEF4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Primary),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context,
      String serviceId, ServicesProvider provider) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.all(20),
        title: const Text('Delete Service',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E))),
        content: const Text('This action cannot be undone. Are you sure?',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A7A8C))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(SnackBar(
                content: Row(children: const [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white)),
                  ),
                  SizedBox(width: 10),
                  Text('Deleting...', style: TextStyle(fontSize: 13)),
                ]),
                backgroundColor: const Color(0xFF2D2D3A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                duration: const Duration(seconds: 2),
              ));

              await provider.deleteService(serviceId: serviceId);

              if (!mounted) return;
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(SnackBar(
                content: Text(provider.myServicesMessage,
                    style: const TextStyle(fontSize: 13)),
                backgroundColor: provider.hasMyServicesError
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF00C48C),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                duration: const Duration(seconds: 3),
              ));
            },
            child: const Text('Delete',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  const _DetailItem(this.icon, this.label, this.value);
}