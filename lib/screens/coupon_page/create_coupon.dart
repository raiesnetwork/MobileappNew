
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/coupon_provider.dart';


class CreateCouponScreen extends StatefulWidget {
  const CreateCouponScreen({Key? key}) : super(key: key);

  @override
  State<CreateCouponScreen> createState() => _CreateCouponScreenState();
}

class _CreateCouponScreenState extends State<CreateCouponScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _codeController = TextEditingController();
  final _imageController = TextEditingController();
  final _linkController = TextEditingController();
  final _discountAmountController = TextEditingController();
  final _discountPercentageController = TextEditingController();
  final _coinAmountController = TextEditingController();
  final _rewardTypeController = TextEditingController();
  final _currencyController = TextEditingController();

  String _selectedType = 'coupon';
  String _selectedCouponType = 'discount-in-percentage';
  DateTime? _selectedExpiry;

  final List<String> _types = ['coupon', 'coins', 'rewards'];
  final List<String> _couponTypes = ['discount-amount', 'discount-in-percentage'];

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    _codeController.dispose();
    _imageController.dispose();
    _linkController.dispose();
    _discountAmountController.dispose();
    _discountPercentageController.dispose();
    _coinAmountController.dispose();
    _rewardTypeController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Coupon'),
        elevation: 0,
      ),
      body: Consumer<CouponProvider>(
        builder: (context, couponProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.purple[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create New Coupon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Fill in the details to create your coupon',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Basic Information
                  _buildSectionTitle('Basic Information'),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Coupon Name',
                    hint: 'Enter coupon name',
                    required: true,
                    prefixIcon: Icons.local_offer,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _detailsController,
                    label: 'Description',
                    hint: 'Enter coupon description',
                    required: true,
                    maxLines: 3,
                    prefixIcon: Icons.description,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _codeController,
                    label: 'Coupon Code',
                    hint: 'Enter unique coupon code',
                    required: true,
                    prefixIcon: Icons.confirmation_number,
                  ),

                  const SizedBox(height: 24),

                  // Type Selection
                  _buildSectionTitle('Coupon Type'),
                  const SizedBox(height: 16),

                  _buildDropdown(
                    value: _selectedType,
                    label: 'Type',
                    items: _types,
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                    prefixIcon: Icons.category,
                  ),

                  const SizedBox(height: 16),

                  // Coupon Type (only for coupon type)
                  if (_selectedType == 'coupon') ...[
                    _buildDropdown(
                      value: _selectedCouponType,
                      label: 'Coupon Type',
                      items: _couponTypes,
                      onChanged: (value) {
                        setState(() {
                          _selectedCouponType = value!;
                        });
                      },
                      prefixIcon: Icons.percent,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Type-specific fields
                  ..._buildTypeSpecificFields(),

                  const SizedBox(height: 24),

                  // Expiry Date
                  _buildSectionTitle('Expiry Date'),
                  const SizedBox(height: 16),

                  _buildDatePicker(),

                  const SizedBox(height: 24),

                  // Optional Fields
                  _buildSectionTitle('Optional Fields'),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _imageController,
                    label: 'Image URL',
                    hint: 'Enter image URL (optional)',
                    prefixIcon: Icons.image,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _linkController,
                    label: 'Coupon Link',
                    hint: 'Enter coupon link (optional)',
                    prefixIcon: Icons.link,
                  ),

                  const SizedBox(height: 32),

                  // Error Message
                  if (couponProvider.createErrorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              couponProvider.createErrorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Create Button
                  ElevatedButton(
                    onPressed: couponProvider.isCreating ? null : _createCoupon,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                    child: couponProvider.isCreating
                        ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Creating Coupon...'),
                      ],
                    )
                        : const Text(
                      'Create Coupon',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: required
          ? (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        return null;
      }
          : null,
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? prefixIcon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item.replaceAll('-', ' ').toUpperCase()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedExpiry ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        if (date != null) {
          setState(() {
            _selectedExpiry = date;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text(
              _selectedExpiry != null
                  ? 'Expires: ${_selectedExpiry!.day}/${_selectedExpiry!.month}/${_selectedExpiry!.year}'
                  : 'Select Expiry Date',
              style: TextStyle(
                fontSize: 16,
                color: _selectedExpiry != null ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeSpecificFields() {
    switch (_selectedType) {
      case 'coupon':
        if (_selectedCouponType == 'discount-amount') {
          return [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _discountAmountController,
                    label: 'Discount Amount',
                    hint: 'Enter amount',
                    required: true,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.money,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _currencyController,
                    label: 'Currency',
                    hint: 'USD, EUR, etc.',
                    required: true,
                    prefixIcon: Icons.attach_money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ];
        } else {
          return [
            _buildTextField(
              controller: _discountPercentageController,
              label: 'Discount Percentage',
              hint: 'Enter percentage (e.g., 50)',
              required: true,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.percent,
            ),
            const SizedBox(height: 16),
          ];
        }
      case 'coins':
        return [
          _buildTextField(
            controller: _coinAmountController,
            label: 'Coin Amount',
            hint: 'Enter coin amount',
            required: true,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.monetization_on,
          ),
          const SizedBox(height: 16),
        ];
      case 'rewards':
        return [
          _buildTextField(
            controller: _rewardTypeController,
            label: 'Reward Type',
            hint: 'Enter reward type',
            required: true,
            prefixIcon: Icons.card_giftcard,
          ),
          const SizedBox(height: 16),
        ];
      default:
        return [];
    }
  }

  void _createCoupon() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expiry date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final couponProvider = context.read<CouponProvider>();

    // Prepare type-specific data
    Map<String, dynamic>? discountAmount;
    double? discountPercentage;
    int? coinAmount;
    String? rewardType;

    if (_selectedType == 'coupon') {
      if (_selectedCouponType == 'discount-amount') {
        if (_discountAmountController.text.isNotEmpty && _currencyController.text.isNotEmpty) {
          discountAmount = {
            'amount': double.tryParse(_discountAmountController.text) ?? 0,
            'currency': _currencyController.text.trim(),
          };
        }
      } else {
        discountPercentage = double.tryParse(_discountPercentageController.text);
      }
    } else if (_selectedType == 'coins') {
      coinAmount = int.tryParse(_coinAmountController.text);
    } else if (_selectedType == 'rewards') {
      rewardType = _rewardTypeController.text.trim();
    }

    final success = await couponProvider.createCoupon(
      name: _nameController.text.trim(),
      details: _detailsController.text.trim(),
      type: _selectedType,
      expiry: _selectedExpiry!.toIso8601String(),
      code: _codeController.text.trim(),
      couponType: _selectedType == 'coupon' ? _selectedCouponType : null,
      image: _imageController.text.trim().isNotEmpty ? _imageController.text.trim() : null,
      link: _linkController.text.trim().isNotEmpty ? _linkController.text.trim() : null,
      discountAmount: discountAmount,
      discountPercentage: discountPercentage,
      coinAmount: coinAmount,
      rewardType: rewardType,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coupon created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();}}}