import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/coupon_provider.dart';

/// Bottom sheet to send a coupon to a specific user OR a group.
/// Usage:
///   showModalBottomSheet(
///     context: context,
///     builder: (_) => SendCouponSheet(coupon: coupon),
///   );
class SendCouponSheet extends StatefulWidget {
  final Map<String, dynamic> coupon;

  const SendCouponSheet({Key? key, required this.coupon}) : super(key: key);

  @override
  State<SendCouponSheet> createState() => _SendCouponSheetState();
}

class _SendCouponSheetState extends State<SendCouponSheet>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF161616);
  static const _surface = Color(0xFF222222);
  static const _accent = Color(0xFFE8FF3A);
  static const _textPrimary = Color(0xFFF5F5F0);
  static const _textMuted = Color(0xFF888880);

  late TabController _tab;
  String? _selectedUserId;
  final _groupIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CouponProvider>().fetchUserList();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _groupIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Send Coupon',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.coupon['code'] ?? '',
                    style: const TextStyle(
                      color: _accent,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tab,
                labelColor: _bg,
                unselectedLabelColor: _textMuted,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w400, fontSize: 13),
                indicator: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'User'), Tab(text: 'Group')],
              ),
            ),
          ),

          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tab,
              children: [_buildUserTab(), _buildGroupTab()],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUserTab() {
    return Consumer<CouponProvider>(builder: (context, provider, _) {
      if (provider.userList.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(
              color: _accent, strokeWidth: 2),
        );
      }

      return Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: provider.userList.length,
              itemBuilder: (_, i) {
                final user = provider.userList[i];
                final uid = user['_id']?.toString() ?? '';
                final isSelected = _selectedUserId == uid;

                return GestureDetector(
                  onTap: () => setState(() => _selectedUserId = uid),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _accent.withOpacity(0.1)
                          : _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _accent.withOpacity(0.5)
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isSelected
                              ? _accent.withOpacity(0.2)
                              : Colors.white10,
                          child: Text(
                            (user['name'] ?? user['email'] ?? '?')
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? _accent : _textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['name']?.toString() ?? 'Unknown',
                                style: const TextStyle(
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              if (user['email'] != null)
                                Text(
                                  user['email'].toString(),
                                  style: const TextStyle(
                                      color: _textMuted, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: _accent, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _sendButton(
              label: 'Send to User',
              enabled: _selectedUserId != null,
              onTap: _sendToUser,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildGroupTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Group / Community ID',
            style: TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _groupIdController,
            style: const TextStyle(color: _textPrimary, fontFamily: 'Courier'),
            decoration: InputDecoration(
              hintText: 'Paste group ID here',
              hintStyle: const TextStyle(color: _textMuted),
              filled: true,
              fillColor: _surface,
              prefixIcon: const Icon(Icons.group_outlined,
                  color: _textMuted, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _accent.withOpacity(0.5)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The coupon will be added to the community associated with this group.',
            style: TextStyle(color: _textMuted, fontSize: 12, height: 1.5),
          ),
          const Spacer(),
          _sendButton(
            label: 'Send to Group',
            enabled: true,
            onTap: _sendToGroup,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _sendButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Consumer<CouponProvider>(builder: (_, provider, __) {
      final loading = provider.isSending;
      return GestureDetector(
        onTap: (!loading && enabled) ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: enabled ? _accent : _surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Color(0xFF0D0D0D), strokeWidth: 2),
            )
                : Text(
              label,
              style: TextStyle(
                color: enabled
                    ? const Color(0xFF0D0D0D)
                    : _textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    });
  }

  void _sendToUser() async {
    if (_selectedUserId == null) return;
    final provider = context.read<CouponProvider>();
    final success = await provider.sendCouponToUser(
      couponId: widget.coupon['_id'],
      receiverId: _selectedUserId!,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Coupon sent successfully!'
            : (provider.sendErrorMessage ?? 'Failed to send')),
        backgroundColor: success
            ? const Color(0xFF1A3A1A)
            : const Color(0xFF3A1A1A),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _sendToGroup() async {
    final groupId = _groupIdController.text.trim();
    if (groupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a group ID'),
        backgroundColor: Color(0xFF3A1A1A),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final provider = context.read<CouponProvider>();
    final success = await provider.sendCouponToGroup(
      couponId: widget.coupon['_id'],
      groupId: groupId,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Coupon sent to group!'
            : (provider.sendErrorMessage ?? 'Failed to send')),
        backgroundColor: success
            ? const Color(0xFF1A3A1A)
            : const Color(0xFF3A1A1A),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}