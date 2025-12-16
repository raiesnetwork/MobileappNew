import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/service_provider.dart';

class CreateServiceScreen extends StatefulWidget {
  final String communityId;

  const CreateServiceScreen({super.key, required this.communityId});

  @override
  _CreateServiceScreenState createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _mainCategoryController = TextEditingController();
  final _subCategoryController = TextEditingController();
  final _openHourFromController = TextEditingController();
  final _openHourEndController = TextEditingController();
  final _costController = TextEditingController();
  final _slotsController = TextEditingController();
  final _currencyController = TextEditingController();
  final _costPerController = TextEditingController();
  String? _serviceProvider;
  final _availableDays = <String>[];
  bool _isSubmitting = false;
  File? _selectedImage;

  // Categories and Subcategories map
  final Map<String, List<String>> _categories = {
    'RentalServices': [
      'Community Hall Rental',
      'Sports Facilities',
      'Event Space Rental',
      'Meeting Rooms',
    ],
    'EducationalServices': [
      'Workshops',
      'Classes',
      'Tutoring Services',
      'Skill Development',
    ],
    'HealthAndWellnessServices': [
      'Fitness Classes',
      'Wellness Programs',
      'Health Clinics',
      'Counseling Services',
    ],
    'FinancialServices': [
      'Accounting',
      'Investments',
      'Taxation',
      'Insurance',
    ],
    'ConsultingServices': [
      'Management Consulting',
      'IT Consulting',
      'Human Resources Consulting',
      'Marketing Consulting',
    ],
    'MatrimonialServices': [
      'Matchmaking',
      'Wedding Planning',
      'Relationship Coaching',
      'Pre-Marriage Counseling',
    ],
    'OrganizationServices': [
      'Event Management',
      'Training and Development',
      'HR Management',
      'Office Administration',
    ],
  };

  String? _selectedCategory;
  String? _selectedSubCategory;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _mainCategoryController.dispose();
    _subCategoryController.dispose();
    _openHourFromController.dispose();
    _openHourEndController.dispose();
    _costController.dispose();
    _slotsController.dispose();
    _currencyController.dispose();
    _costPerController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formattedTime = picked.format(context);
      controller.text = formattedTime;
    }
  }

  Future<void> _createService() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_availableDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one available day')),
        );
        return;
      }
      if (_serviceProvider == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a service provider')),
        );
        return;
      }
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image')),
        );
        return;
      }

      setState(() => _isSubmitting = true);
      final provider = Provider.of<ServicesProvider>(context, listen: false);
      await provider.createService(
        name: _nameController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        communityId: widget.communityId,
        category: _mainCategoryController.text,
        subCategory: _subCategoryController.text,
        openHourFrom: _openHourFromController.text,
        openHourEnd: _openHourEndController.text,
        cost: _costController.text,
        slots: _slotsController.text,
        currency: _currencyController.text,
        costPer: _costPerController.text,
        serviceProvider: _serviceProvider!,
        availableDays: _availableDays,
        image: _selectedImage,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.hasError
                ? provider.message
                : 'Service created successfully',
          ),
          backgroundColor: provider.hasError ? Colors.red : Colors.green,
        ),
      );

      if (!provider.hasError) {
        Navigator.pop(context);
      }
      setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Service',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Primary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration('Service Name *'),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _buildInputDecoration('Description *'),
                  maxLines: 4,
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _selectedImage == null
                            ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to upload image from gallery',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                            : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200,
                          ),
                        ),
                        if (_selectedImage != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeImage,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Primary,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: _buildInputDecoration('Location *'),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: _buildInputDecoration('Main Category *'),
                  items: _categories.keys.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                      _selectedSubCategory = null; // Reset subcategory when category changes
                      _mainCategoryController.text = value ?? '';
                      _subCategoryController.text = ''; // Clear subcategory controller
                    });
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSubCategory,
                  decoration: _buildInputDecoration('Sub Category *'),
                  items: _selectedCategory == null
                      ? []
                      : _categories[_selectedCategory]!.map((subCategory) {
                    return DropdownMenuItem<String>(
                      value: subCategory,
                      child: Text(subCategory),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubCategory = value;
                      _subCategoryController.text = value ?? '';
                    });
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _openHourFromController,
                  decoration: _buildInputDecoration('Open Hour From (e.g., 09:00) *'),
                  readOnly: true,
                  onTap: () => _selectTime(_openHourFromController),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _openHourEndController,
                  decoration: _buildInputDecoration('Open Hour End (e.g., 17:00) *'),
                  readOnly: true,
                  onTap: () => _selectTime(_openHourEndController),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _costController,
                  decoration: _buildInputDecoration('Cost *'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (num.tryParse(value!) == null || num.parse(value) < 0) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _slotsController,
                  decoration: _buildInputDecoration('Slots *'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (int.tryParse(value!) == null || int.parse(value) <= 0) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _currencyController.text.isEmpty ? null : _currencyController.text,
                  decoration: _buildInputDecoration('Currency *'),
                  items: const [
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'INR', child: Text('INR')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                  ],
                  onChanged: (value) => setState(() => _currencyController.text = value!),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _costPerController,
                  decoration: _buildInputDecoration('Cost Per (e.g., Hour) *'),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _serviceProvider,
                  decoration: _buildInputDecoration('Service Provider *'),
                  items: const [
                    DropdownMenuItem(value: 'USER', child: Text('User')),
                    DropdownMenuItem(value: 'COMMUNITY', child: Text('Community')),
                  ],
                  onChanged: (value) => setState(() => _serviceProvider = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Available Days *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      .map((day) => ChoiceChip(
                    label: Text(
                      day,
                      style: TextStyle(
                        color: _availableDays.contains(day) ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: _availableDays.contains(day),
                    selectedColor: Colors.blue,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _availableDays.add(day);
                        } else {
                          _availableDays.remove(day);
                        }
                      });
                    },
                  ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed:_createService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 56),
                    elevation: 2,
                    shadowColor: Colors.grey.withOpacity(0.3),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text(
                    'Create Service',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}