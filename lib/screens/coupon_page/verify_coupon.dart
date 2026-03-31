import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/coupon_provider.dart';

class VerifyCouponSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> coupon)? onApplied;
  final bool inline;

  const VerifyCouponSheet({Key? key, this.onApplied, this.inline = false})
      : super(key: key);

  @override
  State<VerifyCouponSheet> createState() => _VerifyCouponSheetState();
}

class _VerifyCouponSheetState extends State<VerifyCouponSheet> {
  final _codeController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;

  @override
  void dispose() {
    _codeController.dispose();
    context.read<CouponProvider>().clearVerifyState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (widget.inline) return content;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: content,
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.inline) ...[
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_offer_rounded,
                    color: Primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apply Coupon',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Enter code to get discount',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Input row
          Row(
            children: [
              Expanded(
                child: StatefulBuilder(
                  builder: (_, setS) => TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'COUPON CODE',
                      hintStyle: TextStyle(
                        color: Colors.grey[300],
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
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
                        borderSide:
                        BorderSide(color: Primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      suffixIcon: _codeController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.grey[400], size: 18),
                        onPressed: () {
                          _codeController.clear();
                          context
                              .read<CouponProvider>()
                              .clearVerifyState();
                          setState(() => _appliedCoupon = null);
                          setS(() {});
                        },
                      )
                          : null,
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Consumer<CouponProvider>(builder: (_, provider, __) {
                return SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: provider.isVerifying ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      Primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20),
                    ),
                    child: provider.isVerifying
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : const Text(
                      'Apply',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 16),

          // Result
          Consumer<CouponProvider>(builder: (_, provider, __) {
            if (provider.verifyErrorMessage != null) {
              return _resultTile(
                icon: Icons.cancel_rounded,
                color: Colors.red.shade400,
                bgColor: Colors.red.shade50,
                title: 'Invalid Coupon',
                subtitle: provider.verifyErrorMessage!,
              );
            }

            if (_appliedCoupon != null) {
              final discount = _discountText(_appliedCoupon!);
              return _resultTile(
                icon: Icons.check_circle_rounded,
                color: Colors.green.shade500,
                bgColor: Colors.green.shade50,
                title: 'Coupon Applied! ${discount.isNotEmpty ? '🎉' : ''}',
                subtitle: discount.isNotEmpty
                    ? 'You save $discount'
                    : _appliedCoupon!['name'] ?? 'Coupon valid',
                onAction: !widget.inline
                    ? null
                    : () => widget.onApplied?.call(_appliedCoupon!),
                actionLabel: 'Use this',
              );
            }

            return const SizedBox.shrink();
          }),
        ],
      ),

    );
  }

  Widget _resultTile({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String subtitle,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  actionLabel ?? 'Use',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _discountText(Map<String, dynamic> coupon) {
    if (coupon['discountPercentage'] != null) {
      return '${coupon['discountPercentage']}%';
    } else if (coupon['discountAmount'] != null) {
      final cur = coupon['discountCurrency'] ?? '';
      return '$cur${coupon['discountAmount']}';
    }
    return '';
  }

  void _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final result =
    await context.read<CouponProvider>().verifyCoupon(code: code);

    if (result['success'] == true && mounted) {
      setState(() => _appliedCoupon = result['coupon']);
      if (!widget.inline) {
        widget.onApplied?.call(result['coupon']);
      }
    }
  }
}
