import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/campaign_provider.dart';

class CreateCampaignScreen extends StatefulWidget {
  final dynamic campaign;
  final String communityId;

  const CreateCampaignScreen({super.key, this.campaign, required this.communityId});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountNeededController = TextEditingController();
  final _amountPerUserController = TextEditingController();
  final _totalMembersController = TextEditingController();
  String _currency = '₹';
  String? _campaignType = 'MANDATORY';
  String? _schedule = 'monthly';
  String? _promotionType = '';
  DateTime? _endDate;
  DateTime? _dueDate;
  File? _selectedImage;
  String? _imageBase64;
  bool _isProcessingImage = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    print('CreateCampaignScreen - Community ID: ${widget.communityId}');
    print('CreateCampaignScreen - Campaign data: ${widget.campaign}');
    if (widget.campaign != null) {
      _titleController.text = widget.campaign['title'] ?? '';
      _descriptionController.text = widget.campaign['description'] ?? '';
      _amountNeededController.text = widget.campaign['totalAmountNeeded']?.toString() ?? '';
      _amountPerUserController.text = widget.campaign['amountPerUser']?.toString() ?? '';
      _totalMembersController.text = widget.campaign['totalMembers']?.toString() ?? '';
      _currency = widget.campaign['currency'] ?? '₹';
      _campaignType = widget.campaign['campaignType'] ?? 'MANDATORY';
      _schedule = widget.campaign['schedule']?.toLowerCase() ?? 'monthly';
      _promotionType = widget.campaign['promotionType'] ?? '';
      _imageBase64 = widget.campaign['coverImageBase64'] ?? widget.campaign['coverImage'] ?? null;

      // Safely parse endDate
      if (widget.campaign['endDate'] != null && _isValidDate(widget.campaign['endDate'])) {
        try {
          _endDate = DateTime.parse(widget.campaign['endDate'].toString());
        } catch (e) {
          print('Invalid endDate format: ${widget.campaign['endDate']}');
          _endDate = null;
        }
      }

      // Safely parse dueDate
      if (widget.campaign['dueDate'] != null && _isValidDate(widget.campaign['dueDate'])) {
        try {
          _dueDate = DateTime.parse(widget.campaign['dueDate'].toString());
        } catch (e) {
          print('Invalid dueDate format: ${widget.campaign['dueDate']}');
          _dueDate = null;
        }
      }
    }
  }

  // Helper to check if a string is a valid date
  bool _isValidDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return false;
    return !RegExp(r'^(one_time|daily|weekly|monthly|quarterly|half_yearly|yearly|2_day)$', caseSensitive: false)
        .hasMatch(dateString);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountNeededController.dispose();
    _amountPerUserController.dispose();
    _totalMembersController.dispose();
    super.dispose();
  }

  Future<void> _showImagePicker() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_selectedImage != null || _imageBase64 != null)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Remove Image'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isProcessingImage = true);

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final bytes = await File(pickedFile.path).readAsBytes();
        setState(() {
          _selectedImage = File(pickedFile.path);
          _imageBase64 = base64Encode(bytes);
          _isProcessingImage = false;
        });
        _showSnackBar('Image processed successfully!', Colors.green);
      } else {
        setState(() => _isProcessingImage = false);
      }
    } catch (e) {
      setState(() => _isProcessingImage = false);
      _showSnackBar('Error processing image: ${e.toString()}', Colors.red);
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageBase64 = null;
    });
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _selectDate(String field) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      setState(() {
        if (field == 'endDate') {
          _endDate = selectedDate;
        } else if (field == 'dueDate') {
          _dueDate = selectedDate;
        }
      });
    }
  }

  Future<void> _saveCampaign() async {
    if (widget.communityId.isEmpty) {
      _showSnackBar('Community ID is required', Colors.red);
      print('CreateCampaignScreen - Error: Community ID is empty');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields correctly', Colors.red);
      print('CreateCampaignScreen - Form validation failed');
      return;
    }

    if (_endDate == null) {
      _showSnackBar('End date is required', Colors.red);
      print('CreateCampaignScreen - End date is missing');
      return;
    }

    if (_campaignType == 'MANDATORY') {
      if (_amountPerUserController.text.isEmpty || double.tryParse(_amountPerUserController.text) == null) {
        _showSnackBar('Amount per user is required for MANDATORY campaigns', Colors.red);
        print('CreateCampaignScreen - Amount per user is missing or invalid');
        return;
      }
      if (_totalMembersController.text.isEmpty || int.tryParse(_totalMembersController.text) == null || int.parse(_totalMembersController.text) <= 0) {
        _showSnackBar('Total members must be a positive number for MANDATORY campaigns', Colors.red);
        print('CreateCampaignScreen - Total members is missing or invalid');
        return;
      }
    }

    if (_campaignType == 'MARKETING' && (_promotionType?.isEmpty ?? true)) {
      _showSnackBar('Promotion type is required for MARKETING campaigns', Colors.red);
      print('CreateCampaignScreen - Promotion type is missing for MARKETING campaign');
      return;
    }

    final double amountPerUser = _amountPerUserController.text.isEmpty
        ? 0
        : double.parse(_amountPerUserController.text);
    final double totalAmountNeeded = _amountNeededController.text.isEmpty
        ? 0
        : double.parse(_amountNeededController.text);
    final int totalMembers = _totalMembersController.text.isEmpty
        ? 0
        : int.parse(_totalMembersController.text);

    final campaignData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'communityId': widget.communityId,
      'communities': [],
      'campaignType': _campaignType,
      'endDate': _endDate != null ? '${_endDate!.toIso8601String()}Z' : null,
      'dueDate': _dueDate != null ? '${_dueDate!.toIso8601String()}Z' : null,
      'amountPerUser': amountPerUser,
      'totalAmountNeeded': totalAmountNeeded,
      'currency': _currency,
      'coverImageBase64': _imageBase64 ?? '', // Send as base64
      'totalMembers': totalMembers,
      'schedule': _schedule?.toUpperCase(),
      'promotionType': _promotionType,
      'productIds': [],
      'serviceIds': [],
      'objectives': {'sendToMultipleCommunities': false},
    };

    print('CreateCampaignScreen - Sending campaign data: ${jsonEncode(campaignData)}');

    try {
      final campaignProvider = context.read<CampaignProvider>();
      Map<String, dynamic> response;

      if (widget.campaign != null) {
        // Editing existing campaign
        response = await campaignProvider.editCampaign(widget.campaign['_id'], campaignData);
      } else {
        // Creating new campaign
        response = await campaignProvider.createCampaign(campaignData);
      }

      if (!mounted) return;

      if (!response['error'] && response['campaign'] != null) {
        print('CreateCampaignScreen - ${widget.campaign != null ? 'Updated' : 'Created'} campaign: ${response['campaign']}');
        _showSnackBar(response['message'], Colors.green);
        Navigator.pop(context, true);
      } else {
        _showSnackBar(response['message'] ?? 'Failed to ${widget.campaign != null ? 'update' : 'create'} campaign', Colors.red);
        print('CreateCampaignScreen - Failed to ${widget.campaign != null ? 'update' : 'create'} campaign: ${response['message']}');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error ${widget.campaign != null ? 'updating' : 'creating'} campaign: ${e.toString()}', Colors.red);
      print('CreateCampaignScreen - Exception: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.campaign == null ? 'Create Campaign' : 'Edit Campaign',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Campaign Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _campaignType,
                decoration: const InputDecoration(
                  labelText: 'Campaign Type *',
                  border: OutlineInputBorder(),
                ),
                items: ['MANDATORY', 'MARKETING'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _campaignType = value);
                },
                validator: (value) => value == null ? 'Campaign type is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountNeededController,
                decoration: const InputDecoration(
                  labelText: 'Total Amount Needed *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Total amount needed is required';
                  if (double.tryParse(value!) == null || double.parse(value) <= 0) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountPerUserController,
                decoration: const InputDecoration(
                  labelText: 'Amount Per User *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (_campaignType == 'MANDATORY') {
                    if (value?.isEmpty ?? true) return 'Amount per user is required for MANDATORY campaigns';
                    if (double.tryParse(value!) == null || double.parse(value) <= 0) {
                      return 'Enter a valid positive number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalMembersController,
                decoration: const InputDecoration(
                  labelText: 'Total Members *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (_campaignType == 'MANDATORY') {
                    if (value?.isEmpty ?? true) return 'Total members is required for MANDATORY campaigns';
                    if (int.tryParse(value!) == null || int.parse(value) <= 0) {
                      return 'Enter a valid positive number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(
                  labelText: 'Currency *',
                  border: OutlineInputBorder(),
                ),
                items: ['₹', 'USD', 'EUR', 'GBP'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _currency = value!);
                },
                validator: (value) => value == null ? 'Currency is required' : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _selectDate('endDate'),
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _endDate == null
                      ? 'Select End Date *'
                      : 'End: ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _selectDate('dueDate'),
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _dueDate == null
                      ? 'Select Due Date'
                      : 'Due: ${DateFormat('MMM dd, yyyy').format(_dueDate!)}',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _schedule,
                decoration: const InputDecoration(
                  labelText: 'Schedule *',
                  border: OutlineInputBorder(),
                ),
                items: ['one_time', 'daily', 'weekly', 'monthly', 'quarterly', 'half_yearly', 'yearly', '2_day'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.replaceAll('_', ' ').toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _schedule = value);
                },
                validator: (value) => value == null ? 'Schedule is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _promotionType,
                decoration: const InputDecoration(
                  labelText: 'Promotion Type',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _promotionType = value);
                },
                validator: (value) {
                  if (_campaignType == 'MARKETING' && (value?.isEmpty ?? true)) {
                    return 'Promotion type is required for MARKETING campaigns';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Cover Image',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isProcessingImage
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Processing image...'),
                      ],
                    ),
                  )
                      : _selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 50),
                              Text('Failed to load image'),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                      : _imageBase64 != null && _imageBase64!.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(_imageBase64!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 50),
                              Text('Failed to load image'),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                      : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 50),
                        SizedBox(height: 8),
                        Text('Tap to add cover image'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveCampaign,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.campaign == null ? 'Create Campaign' : 'Update Campaign',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}