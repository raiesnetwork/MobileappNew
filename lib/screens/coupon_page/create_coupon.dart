import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/coupon_provider.dart';

class CreateCouponScreen extends StatefulWidget {
  const CreateCouponScreen({Key? key}) : super(key: key);

  @override
  State<CreateCouponScreen> createState() => _CreateCouponScreenState();
}

class _CreateCouponScreenState extends State<CreateCouponScreen> {
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _card = Color(0xFF242424);
  static const _accent = Color(0xFFE8FF3A);
  static const _textPrimary = Color(0xFFF5F5F0);
  static const _textMuted = Color(0xFF888880);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _discountAmountCtrl = TextEditingController();
  final _discountPercentCtrl = TextEditingController();
  final _coinAmountCtrl = TextEditingController();
  final _rewardTypeCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();

  String _type = 'coupon';
  String _couponType = 'discount-in-percentage';
  DateTime? _expiry;
  File? _imageFile;

  final _types = ['coupon', 'coins', 'rewards'];
  final _couponTypes = ['discount-in-percentage', 'discount-amount'];

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _detailsCtrl, _codeCtrl, _linkCtrl,
      _discountAmountCtrl, _discountPercentCtrl,
      _coinAmountCtrl, _rewardTypeCtrl, _currencyCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
        title: const Text(
          'Create Coupon',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Consumer<CouponProvider>(builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image picker
                _buildImagePicker(),
                const SizedBox(height: 24),

                _section('Basic Info'),
                const SizedBox(height: 12),
                _field(_nameCtrl, 'Coupon Name', required: true,
                    icon: Icons.local_offer_rounded),
                const SizedBox(height: 12),
                _field(_detailsCtrl, 'Description',
                    required: true,
                    maxLines: 3,
                    icon: Icons.description_rounded),
                const SizedBox(height: 12),
                _field(_codeCtrl, 'Coupon Code',
                    required: true,
                    icon: Icons.confirmation_number_rounded,
                    caps: TextCapitalization.characters),

                const SizedBox(height: 24),
                _section('Type'),
                const SizedBox(height: 12),
                _buildTypeChips(),
                const SizedBox(height: 16),

                if (_type == 'coupon') ...[
                  _buildCouponTypeChips(),
                  const SizedBox(height: 16),
                ],

                ..._buildTypeFields(),

                const SizedBox(height: 24),
                _section('Expiry Date'),
                const SizedBox(height: 12),
                _buildDatePicker(),

                const SizedBox(height: 24),
                _section('Optional'),
                const SizedBox(height: 12),
                _field(_linkCtrl, 'Coupon Link (URL)',
                    icon: Icons.link_rounded),

                const SizedBox(height: 32),

                // Error
                if (provider.createErrorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1010),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFFF6B6B), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            provider.createErrorMessage!,
                            style: const TextStyle(
                                color: Color(0xFFFF6B6B), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Submit
                GestureDetector(
                  onTap: provider.isCreating ? null : _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: provider.isCreating
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: _bg, strokeWidth: 2.5),
                      )
                          : const Text(
                        'Create Coupon',
                        style: TextStyle(
                          color: _bg,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _section(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: _textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String label, {
        bool required = false,
        int maxLines = 1,
        IconData? icon,
        TextCapitalization caps = TextCapitalization.sentences,
        TextInputType keyboard = TextInputType.text,
      }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      textCapitalization: caps,
      keyboardType: keyboard,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted, fontSize: 14),
        prefixIcon: icon != null
            ? Icon(icon, color: _textMuted, size: 18)
            : null,
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          BorderSide(color: _accent.withOpacity(0.5)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
      ),
      validator: required
          ? (v) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
    );
  }

  Widget _buildTypeChips() {
    const labels = {
      'coupon': Icons.local_offer_rounded,
      'coins': Icons.monetization_on_rounded,
      'rewards': Icons.card_giftcard_rounded,
    };
    return Row(
      children: _types.map((t) {
        final selected = _type == t;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _type = t),
            child: Container(
              margin: EdgeInsets.only(
                  right: t != _types.last ? 8 : 0),
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: selected
                    ? _accent.withOpacity(0.12)
                    : _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? _accent.withOpacity(0.5)
                      : Colors.white10,
                ),
              ),
              child: Column(
                children: [
                  Icon(labels[t],
                      color: selected ? _accent : _textMuted,
                      size: 20),
                  const SizedBox(height: 4),
                  Text(
                    t[0].toUpperCase() + t.substring(1),
                    style: TextStyle(
                      color: selected ? _accent : _textMuted,
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCouponTypeChips() {
    return Row(
      children: _couponTypes.map((t) {
        final selected = _couponType == t;
        final label = t == 'discount-in-percentage'
            ? '% Percentage'
            : '₹ Fixed Amount';
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _couponType = t),
            child: Container(
              margin: EdgeInsets.only(
                  right: t != _couponTypes.last ? 8 : 0),
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF42A5F5).withOpacity(0.12)
                    : _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF42A5F5).withOpacity(0.5)
                      : Colors.white10,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF42A5F5)
                      : _textMuted,
                  fontSize: 12,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildTypeFields() {
    switch (_type) {
      case 'coupon':
        if (_couponType == 'discount-amount') {
          return [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _field(_discountAmountCtrl, 'Amount',
                      required: true,
                      icon: Icons.money_rounded,
                      keyboard: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_currencyCtrl, 'Currency',
                      required: true,
                      icon: Icons.attach_money_rounded),
                ),
              ],
            ),
          ];
        } else {
          return [
            _field(_discountPercentCtrl, 'Percentage (e.g. 50)',
                required: true,
                icon: Icons.percent_rounded,
                keyboard: TextInputType.number),
          ];
        }
      case 'coins':
        return [
          _field(_coinAmountCtrl, 'Coin Amount',
              required: true,
              icon: Icons.monetization_on_rounded,
              keyboard: TextInputType.number),
        ];
      case 'rewards':
        return [
          _field(_rewardTypeCtrl, 'Reward Type',
              required: true, icon: Icons.card_giftcard_rounded),
        ];
      default:
        return [];
    }
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _expiry ??
              DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate:
          DateTime.now().add(const Duration(days: 730)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: _accent,
                onPrimary: _bg,
                surface: Color(0xFF242424),
                onSurface: _textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (date != null) setState(() => _expiry = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expiry != null
                ? _accent.withOpacity(0.4)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: _expiry != null ? _accent : _textMuted,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              _expiry != null
                  ? 'Expires ${_expiry!.day}/${_expiry!.month}/${_expiry!.year}'
                  : 'Select Expiry Date',
              style: TextStyle(
                color: _expiry != null ? _textPrimary : _textMuted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _imageFile != null
                ? _accent.withOpacity(0.4)
                : Colors.white10,
            style: _imageFile != null
                ? BorderStyle.solid
                : BorderStyle.solid,
          ),
        ),
        child: _imageFile != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_imageFile!, fit: BoxFit.cover),
              Container(color: Colors.black45),
              const Center(
                child: Icon(Icons.edit_rounded,
                    color: Colors.white, size: 28),
              ),
            ],
          ),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: _textMuted, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Add coupon image (optional)',
              style: TextStyle(color: _textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SUBMIT
  // ─────────────────────────────────────────────────────────────────────────────
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select an expiry date'),
        backgroundColor: Color(0xFF3A1A1A),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    Map<String, dynamic>? discountAmount;
    double? discountPercentage;
    int? coinAmount;
    String? rewardType;

    if (_type == 'coupon') {
      if (_couponType == 'discount-amount') {
        discountAmount = {
          'amount': double.tryParse(_discountAmountCtrl.text) ?? 0,
          'currency': _currencyCtrl.text.trim(),
        };
      } else {
        discountPercentage =
            double.tryParse(_discountPercentCtrl.text);
      }
    } else if (_type == 'coins') {
      coinAmount = int.tryParse(_coinAmountCtrl.text);
    } else if (_type == 'rewards') {
      rewardType = _rewardTypeCtrl.text.trim();
    }

    final success = await context.read<CouponProvider>().createCoupon(
      name: _nameCtrl.text.trim(),
      details: _detailsCtrl.text.trim(),
      type: _type,
      expiry: _expiry!.toIso8601String(),
      code: _codeCtrl.text.trim(),
      couponType: _type == 'coupon' ? _couponType : null,
      imageFile: _imageFile,
      link: _linkCtrl.text.trim().isNotEmpty
          ? _linkCtrl.text.trim()
          : null,
      discountAmount: discountAmount,
      discountPercentage: discountPercentage,
      coinAmount: coinAmount,
      rewardType: rewardType,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Coupon created! 🎉'),
        backgroundColor: Color(0xFF1A3A1A),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    }
  }
}