import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/coupon_provider.dart';

class CreateCouponScreen extends StatefulWidget {
  const CreateCouponScreen({Key? key}) : super(key: key);

  @override
  State<CreateCouponScreen> createState() => _CreateCouponScreenState();
}

class _CreateCouponScreenState extends State<CreateCouponScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Coupon',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Consumer<CouponProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image picker
                  _buildImagePicker(),
                  const SizedBox(height: 20),

                  _buildCard(
                    title: 'Basic Info',
                    children: [
                      _field(_nameCtrl, 'Coupon Name',
                          required: true,
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
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildCard(
                    title: 'Coupon Type',
                    children: [
                      _buildTypeChips(),
                      if (_type == 'coupon') ...[
                        const SizedBox(height: 12),
                        _buildCouponTypeChips(),
                      ],
                      const SizedBox(height: 16),
                      ..._buildTypeFields(),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildCard(
                    title: 'Expiry Date',
                    children: [_buildDatePicker()],
                  ),

                  const SizedBox(height: 16),

                  _buildCard(
                    title: 'Optional',
                    children: [
                      _field(_linkCtrl, 'Coupon Link (URL)',
                          icon: Icons.link_rounded),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (provider.createErrorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade400, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              provider.createErrorMessage!,
                              style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isCreating ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                        Primary.withOpacity(0.5),
                        padding:
                        const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: provider.isCreating
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                          : const Text(
                        'Create Coupon',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _buildCard(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
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
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(color: Colors.grey[500], fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.grey[400], size: 18)
            : null,
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
          borderSide: BorderSide(color: Primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Colors.red.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
          ? '$label is required'
          : null
          : null,
    );
  }

  Widget _buildTypeChips() {
    const icons = {
      'coupon': Icons.local_offer_rounded,
      'coins': Icons.monetization_on_rounded,
      'rewards': Icons.card_giftcard_rounded,
    };
    const colors = {
      'coupon': Color(0xFF3B82F6),
      'coins': Color(0xFFF59E0B),
      'rewards': Color(0xFF8B5CF6),
    };

    return Row(
      children: _types.map((t) {
        final selected = _type == t;
        final color = colors[t]!;
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
                    ? color.withOpacity(0.08)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? color.withOpacity(0.4)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  Icon(icons[t],
                      color: selected ? color : Colors.grey[400],
                      size: 20),
                  const SizedBox(height: 4),
                  Text(
                    t[0].toUpperCase() + t.substring(1),
                    style: TextStyle(
                      color: selected ? color : Colors.grey[500],
                      fontSize: 11,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400,
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
                  vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: selected
                    ? Primary.withOpacity(0.08)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? Primary.withOpacity(0.4)
                      : Colors.grey.shade200,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Primary : Colors.grey[500],
                  fontSize: 12,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w400,
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
              required: true,
              icon: Icons.card_giftcard_rounded),
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
          initialDate:
          _expiry ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate:
          DateTime.now().add(const Duration(days: 730)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(
                primary: Primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          ),
        );
        if (date != null) setState(() => _expiry = date);
      },
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _expiry != null
                ? Primary.withOpacity(0.4)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: _expiry != null ? Primary : Colors.grey[400],
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              _expiry != null
                  ? 'Expires ${_expiry!.day}/${_expiry!.month}/${_expiry!.year}'
                  : 'Select Expiry Date',
              style: TextStyle(
                color: _expiry != null
                    ? Colors.black87
                    : Colors.grey[400],
                fontSize: 14,
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
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _imageFile != null
                ? Primary.withOpacity(0.4)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _imageFile != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_imageFile!, fit: BoxFit.cover),
              Container(color: Colors.black.withOpacity(0.3)),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_rounded,
                      color: Primary, size: 20),
                ),
              ),
            ],
          ),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_photo_alternate_outlined,
                  color: Primary, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Add coupon image (optional)',
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select an expiry date'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Coupon created! 🎉'),
        backgroundColor: Primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ));
      Navigator.pop(context);
    }
  }
}