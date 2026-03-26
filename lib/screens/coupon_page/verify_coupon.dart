import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/coupon_provider.dart';

/// Reusable bottom sheet / widget to verify a coupon code at checkout.
///
/// STANDALONE (bottom sheet):
///   showModalBottomSheet(
///     context: context,
///     builder: (_) => const VerifyCouponSheet(),
///   );
///
/// EMBEDDED in checkout (pass onApplied callback):
///   VerifyCouponSheet(
///     onApplied: (coupon) { /* apply discount */ },
///   )
class VerifyCouponSheet extends StatefulWidget {
  /// Called when a coupon is successfully verified.
  /// Receives the coupon map from the server.
  final void Function(Map<String, dynamic> coupon)? onApplied;

  /// If true renders as an inline widget (no drag handle / rounded top).
  final bool inline;

  const VerifyCouponSheet({Key? key, this.onApplied, this.inline = false})
      : super(key: key);

  @override
  State<VerifyCouponSheet> createState() => _VerifyCouponSheetState();
}

class _VerifyCouponSheetState extends State<VerifyCouponSheet> {
  static const _bg = Color(0xFF161616);
  static const _surface = Color(0xFF222222);
  static const _accent = Color(0xFFE8FF3A);
  static const _green = Color(0xFF4CAF50);
  static const _red = Color(0xFFFF6B6B);
  static const _textPrimary = Color(0xFFF5F5F0);
  static const _textMuted = Color(0xFF888880);

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
        color: _bg,
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
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_offer_rounded,
                    color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apply Coupon',
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Enter code to get discount',
                    style: TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Code input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'COUPON CODE',
                    hintStyle: TextStyle(
                      color: _textMuted.withOpacity(0.5),
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: _surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: _accent.withOpacity(0.5)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    suffixIcon: _codeController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: _textMuted, size: 18),
                      onPressed: () {
                        _codeController.clear();
                        context
                            .read<CouponProvider>()
                            .clearVerifyState();
                        setState(() => _appliedCoupon = null);
                      },
                    )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Consumer<CouponProvider>(builder: (_, provider, __) {
                return GestureDetector(
                  onTap: provider.isVerifying ? null : _verify,
                  child: Container(
                    height: 52,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: provider.isVerifying
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Color(0xFF0D0D0D),
                            strokeWidth: 2),
                      )
                          : const Text(
                        'Apply',
                        style: TextStyle(
                          color: Color(0xFF0D0D0D),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 16),

          // Result display
          Consumer<CouponProvider>(builder: (_, provider, __) {
            if (provider.verifyErrorMessage != null) {
              return _resultTile(
                icon: Icons.cancel_rounded,
                color: _red,
                title: 'Invalid Coupon',
                subtitle: provider.verifyErrorMessage!,
              );
            }

            if (_appliedCoupon != null) {
              final discount = _discountText(_appliedCoupon!);
              return _resultTile(
                icon: Icons.check_circle_rounded,
                color: _green,
                title: 'Coupon Applied! ${discount.isNotEmpty ? '🎉' : ''}',
                subtitle: discount.isNotEmpty
                    ? 'You save $discount'
                    : _appliedCoupon!['name'] ?? 'Coupon valid',
                onAction: !widget.inline
                    ? null
                    : () {
                  widget.onApplied?.call(_appliedCoupon!);
                },
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
    required String title,
    required String subtitle,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
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
                    style: const TextStyle(
                        color: _textMuted, fontSize: 12)),
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
                  color: color.withOpacity(0.2),
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

    final result = await context
        .read<CouponProvider>()
        .verifyCoupon(code: code);

    if (result['success'] == true && mounted) {
      setState(() => _appliedCoupon = result['coupon']);
      if (!widget.inline) {
        // Close sheet and pass coupon up
        widget.onApplied?.call(result['coupon']);
      }
    }
  }
}