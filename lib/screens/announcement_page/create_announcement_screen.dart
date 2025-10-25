import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/announcement_provider.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final String communityId;
  final Map<String, dynamic>? announcement;

  const CreateAnnouncementScreen({
    super.key,
    required this.communityId,
    this.announcement,
  });

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactInfoController = TextEditingController();
  final _locationController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _timeController = TextEditingController();
  final _endTimeController = TextEditingController();
  String? _templateType;
  bool _isSubmitting = false;

  // Valid template types for the dropdown
  static const List<String> _validTemplateTypes = ['event', 'job', 'general'];

  @override
  void initState() {
    super.initState();
    if (widget.announcement != null) {
      _titleController.text = widget.announcement!['title'] ?? '';
      _descriptionController.text = widget.announcement!['description'] ?? '';
      _contactInfoController.text = widget.announcement!['contactInfo'] ?? '';
      _locationController.text = widget.announcement!['location'] ?? '';
      _startDateController.text = widget.announcement!['startDate'] ?? '';
      _endDateController.text = widget.announcement!['endDate'] ?? '';
      _timeController.text = widget.announcement!['time'] ?? '';
      _endTimeController.text = widget.announcement!['endTime'] ?? '';
      // Validate templateType and default to 'event' if invalid
      String? templateType = widget.announcement!['templateType'];
      _templateType = _validTemplateTypes.contains(templateType) ? templateType : 'event';
      if (templateType != null && !_validTemplateTypes.contains(templateType)) {
        print('Invalid templateType "${templateType}" received, defaulting to "event"');
      }
    } else {
      _templateType = 'event';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contactInfoController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _timeController.dispose();
    _endTimeController.dispose();
    super.dispose();
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
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        if (field == 'startDate') {
          _startDateController.text = DateFormat('yyyy-MM-dd').format(date);
        } else {
          _endDateController.text = DateFormat('yyyy-MM-dd').format(date);
        }
      });
    }
  }

  Future<void> _selectTime(String field) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        final formattedTime = DateFormat('HH:mm').format(
          DateTime(2025, 1, 1, time.hour, time.minute),
        );
        if (field == 'time') {
          _timeController.text = formattedTime;
        } else {
          _endTimeController.text = formattedTime;
        }
      });
    }
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return;
    }

    // Validate endDate is not before startDate if both are provided
    if (_startDateController.text.isNotEmpty && _endDateController.text.isNotEmpty) {
      final startDate = DateTime.parse(_startDateController.text);
      final endDate = DateTime.parse(_endDateController.text);
      if (endDate.isBefore(startDate)) {
        _showSnackBar('End date cannot be before start date', Colors.red);
        return;
      }
    }

    // Validate endTime is not before time if both are provided on the same date
    if (_startDateController.text == _endDateController.text &&
        _timeController.text.isNotEmpty &&
        _endTimeController.text.isNotEmpty) {
      final startTime = DateFormat('HH:mm').parse(_timeController.text);
      final endTime = DateFormat('HH:mm').parse(_endTimeController.text);
      if (endTime.isBefore(startTime)) {
        _showSnackBar('End time cannot be before start time on the same date', Colors.red);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'communityId': widget.communityId,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'contactInfo': _contactInfoController.text.trim(),
      'startDate': _startDateController.text,
      'endDate': _endDateController.text,
      'time': _timeController.text,
      'endTime': _endTimeController.text,
      'location': _locationController.text.trim(),
      'templateType': _templateType,
      'image': '',
      'company': '',
      'experience': '',
      'employmentType': '',
      'salaryRange': '',
      'url': '',
      'currency': '',
    };

    print('CreateAnnouncementScreen - Sending Payload: ${jsonEncode(payload)}');

    try {
      final provider = Provider.of<AnnouncementProvider>(context, listen: false);
      Map<String, dynamic> result;
      if (widget.announcement == null) {
        result = await provider.createAnnouncement(
          communityId: widget.communityId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          contactInfo: _contactInfoController.text.trim(),
          startDate: _startDateController.text,
          endDate: _endDateController.text,
          time: _timeController.text,
          endTime: _endTimeController.text,
          location: _locationController.text.trim(),
          templateType: _templateType!,
          image: '',
          company: '',
          experience: '',
          employmentType: '',
          salaryRange: '',
          url: '',
          currency: '',
        );
      } else {
        result = await provider.updateAnnouncement(
          id: widget.announcement!['_id'],
          communityId: widget.communityId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          contactInfo: _contactInfoController.text.trim(),
          startDate: _startDateController.text,
          endDate: _endDateController.text,
          time: _timeController.text,
          endTime: _endTimeController.text,
          location: _locationController.text.trim(),
          templateType: _templateType!,
          image: '',
          company: '',
          experience: '',
          employmentType: '',
          salaryRange: '',
          url: '',
          currency: '',
        );
      }

      if (!mounted) return;

      setState(() => _isSubmitting = false);
      _showSnackBar(result['message'], result['error'] ? Colors.red : Colors.green);
      if (!result['error']) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Exception in saveAnnouncement: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackBar('Error saving announcement: ${e.toString()}', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.announcement == null ? 'Create Announcement' : 'Edit Announcement',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF800080),
        foregroundColor: Colors.white,
        elevation: 2,
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
                decoration: InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                maxLines: 3,
                validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Template Type *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                value: _templateType,
                items: _validTemplateTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type[0].toUpperCase() + type.substring(1)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _templateType = value);
                },
                validator: (value) => value == null || value.isEmpty ? 'Template Type is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactInfoController,
                decoration: InputDecoration(
                  labelText: 'Contact Info',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startDateController,
                decoration: InputDecoration(
                  labelText: 'Start Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                readOnly: true,
                onTap: () => _selectDate('startDate'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return null;
                  try {
                    DateTime.parse(value!);
                    return null;
                  } catch (e) {
                    return 'Invalid date format';
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endDateController,
                decoration: InputDecoration(
                  labelText: 'End Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                readOnly: true,
                onTap: () => _selectDate('endDate'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return null;
                  try {
                    DateTime.parse(value!);
                    return null;
                  } catch (e) {
                    return 'Invalid date format';
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timeController,
                decoration: InputDecoration(
                  labelText: 'Time (HH:mm)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                readOnly: true,
                onTap: () => _selectTime('time'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return null;
                  try {
                    DateFormat('HH:mm').parse(value!);
                    return null;
                  } catch (e) {
                    return 'Invalid time format';
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endTimeController,
                decoration: InputDecoration(
                  labelText: 'End Time (HH:mm)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                readOnly: true,
                onTap: () => _selectTime('endTime'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return null;
                  try {
                    DateFormat('HH:mm').parse(value!);
                    return null;
                  } catch (e) {
                    return 'Invalid time format';
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveAnnouncement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF800080),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    widget.announcement == null ? 'Create Announcement' : 'Update Announcement',
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
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