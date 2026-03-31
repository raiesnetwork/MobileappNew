import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/coupon_provider.dart';

class SendCouponSheet extends StatefulWidget {
  final Map<String, dynamic> coupon;

  const SendCouponSheet({Key? key, required this.coupon}) : super(key: key);

  @override
  State<SendCouponSheet> createState() => _SendCouponSheetState();
}

class _SendCouponSheetState extends State<SendCouponSheet>
    with SingleTickerProviderStateMixin {
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
        color: Colors.white,
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
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.send_rounded, color: Primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send Coupon',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.coupon['code'] ?? '',
                        style: TextStyle(
                          color: Primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[500],
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w400, fontSize: 13),
                indicator: BoxDecoration(
                  color: Primary,
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
        return Center(
          child: CircularProgressIndicator(color: Primary, strokeWidth: 2),
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
                final name =
                    user['name']?.toString() ?? 'Unknown';

                return GestureDetector(
                  onTap: () => setState(() => _selectedUserId = uid),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Primary.withOpacity(0.06)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Primary.withOpacity(0.4)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isSelected
                              ? Primary.withOpacity(0.15)
                              : Colors.grey.shade200,
                          child: Text(
                            name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Primary : Colors.grey[600],
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
                                name,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (user['email'] != null)
                                Text(
                                  user['email'].toString(),
                                  style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded,
                              color: Primary, size: 18),
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
          Text(
            'Group / Community ID',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _groupIdController,
            style: const TextStyle(
                color: Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste group ID here',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: Icon(Icons.group_outlined,
                  color: Colors.grey[400], size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'The coupon will be added to the community associated with this group.',
            style:
            TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.5),
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
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (!loading && enabled) ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: loading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          )
              : Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14),
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
        backgroundColor: success ? Primary : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  void _sendToGroup() async {
    final groupId = _groupIdController.text.trim();
    if (groupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a group ID'),
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
        backgroundColor: success ? Primary : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ));
    }
  }
}