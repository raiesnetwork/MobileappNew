import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/announcement_provider.dart';

// ── Design tokens (mirrors AnnouncementScreen _T) ────────────────────────────
class _T {
  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const accent = Color(0xFF6366F1);
  static const accentLight = Color(0xFFEEF0FD);
  static const accentMid = Color(0xFFD4D7FB);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const divider = Color(0xFFF0F1F5);
  static const red = Color(0xFFEF4444);
  static const redLight = Color(0xFFFEE2E2);
  static const green = Color(0xFF10B981);
  static const shadow = Color(0x0A000000);
}

class CreateAnnouncementScreen extends StatefulWidget {
  final String communityId;
  final Map<String, dynamic>? announcement;

  const CreateAnnouncementScreen({
    super.key,
    required this.communityId,
    this.announcement,
  });

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
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
      String? templateType = widget.announcement!['templateType'];
      _templateType =
      _validTemplateTypes.contains(templateType) ? templateType : 'event';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _T.accent),
        ),
        child: child!,
      ),
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _T.accent),
        ),
        child: child!,
      ),
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
      _showSnackBar('Please fill all required fields', _T.red);
      return;
    }

    if (_startDateController.text.isNotEmpty &&
        _endDateController.text.isNotEmpty) {
      final startDate = DateTime.parse(_startDateController.text);
      final endDate = DateTime.parse(_endDateController.text);
      if (endDate.isBefore(startDate)) {
        _showSnackBar('End date cannot be before start date', _T.red);
        return;
      }
    }

    if (_startDateController.text == _endDateController.text &&
        _timeController.text.isNotEmpty &&
        _endTimeController.text.isNotEmpty) {
      final startTime = DateFormat('HH:mm').parse(_timeController.text);
      final endTime = DateFormat('HH:mm').parse(_endTimeController.text);
      if (endTime.isBefore(startTime)) {
        _showSnackBar(
            'End time cannot be before start time on the same date', _T.red);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final provider =
      Provider.of<AnnouncementProvider>(context, listen: false);
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
      _showSnackBar(
          result['message'], result['error'] ? _T.red : _T.green);
      if (!result['error']) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackBar('Error saving announcement: ${e.toString()}', _T.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.announcement != null;

    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.surface,
        foregroundColor: _T.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'Edit Announcement' : 'Create Announcement',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _T.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _T.divider),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section: Basic Info ────────────────────────────────────────
              _SectionHeader(
                icon: Icons.campaign_rounded,
                label: 'Basic Info',
                color: _T.accent,
                bg: _T.accentLight,
              ),
              const SizedBox(height: 12),
              _FormCard(
                children: [
                  _FieldItem(
                    label: 'Title',
                    required: true,
                    child: TextFormField(
                      controller: _titleController,
                      style: const TextStyle(
                          fontSize: 14, color: _T.textPrimary),
                      decoration: _inputDecoration('e.g. Community Meetup'),
                      validator: (v) =>
                      v?.isEmpty ?? true ? 'Title is required' : null,
                    ),
                  ),
                  _Divider(),
                  _FieldItem(
                    label: 'Description',
                    required: true,
                    child: TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(
                          fontSize: 14, color: _T.textPrimary),
                      decoration:
                      _inputDecoration('Describe your announcement…'),
                      maxLines: 3,
                      validator: (v) =>
                      v?.isEmpty ?? true ? 'Description is required' : null,
                    ),
                  ),
                  _Divider(),
                  _FieldItem(
                    label: 'Category',
                    required: true,
                    child: DropdownButtonFormField<String>(
                      value: _templateType,
                      decoration: _inputDecoration('Select type'),
                      style: const TextStyle(
                          fontSize: 14, color: _T.textPrimary),
                      dropdownColor: _T.surface,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _T.textTertiary, size: 20),
                      items: _validTemplateTypes.map((type) {
                        final icons = {
                          'event': Icons.event_rounded,
                          'job': Icons.work_rounded,
                          'general': Icons.campaign_rounded,
                        };
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(icons[type],
                                  size: 16, color: _T.textSecondary),
                              const SizedBox(width: 8),
                              Text(type[0].toUpperCase() + type.substring(1)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _templateType = v),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Category is required'
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Section: Schedule ──────────────────────────────────────────
              _SectionHeader(
                icon: Icons.calendar_today_rounded,
                label: 'Schedule',
                color: const Color(0xFF10B981),
                bg: const Color(0xFFD1FAE5),
              ),
              const SizedBox(height: 12),
              _FormCard(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _FieldItem(
                          label: 'Start Date',
                          child: TextFormField(
                            controller: _startDateController,
                            style: const TextStyle(
                                fontSize: 14, color: _T.textPrimary),
                            decoration: _inputDecoration('YYYY-MM-DD',
                                suffix: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: _T.textTertiary)),
                            readOnly: true,
                            onTap: () => _selectDate('startDate'),
                            validator: (v) {
                              if (v?.isEmpty ?? true) return null;
                              try {
                                DateTime.parse(v!);
                                return null;
                              } catch (_) {
                                return 'Invalid date';
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FieldItem(
                          label: 'End Date',
                          child: TextFormField(
                            controller: _endDateController,
                            style: const TextStyle(
                                fontSize: 14, color: _T.textPrimary),
                            decoration: _inputDecoration('YYYY-MM-DD',
                                suffix: const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                    color: _T.textTertiary)),
                            readOnly: true,
                            onTap: () => _selectDate('endDate'),
                            validator: (v) {
                              if (v?.isEmpty ?? true) return null;
                              try {
                                DateTime.parse(v!);
                                return null;
                              } catch (_) {
                                return 'Invalid date';
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  _Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: _FieldItem(
                          label: 'Start Time',
                          child: TextFormField(
                            controller: _timeController,
                            style: const TextStyle(
                                fontSize: 14, color: _T.textPrimary),
                            decoration: _inputDecoration('HH:mm',
                                suffix: const Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
                                    color: _T.textTertiary)),
                            readOnly: true,
                            onTap: () => _selectTime('time'),
                            validator: (v) {
                              if (v?.isEmpty ?? true) return null;
                              try {
                                DateFormat('HH:mm').parse(v!);
                                return null;
                              } catch (_) {
                                return 'Invalid time';
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FieldItem(
                          label: 'End Time',
                          child: TextFormField(
                            controller: _endTimeController,
                            style: const TextStyle(
                                fontSize: 14, color: _T.textPrimary),
                            decoration: _inputDecoration('HH:mm',
                                suffix: const Icon(
                                    Icons.access_time_filled_rounded,
                                    size: 16,
                                    color: _T.textTertiary)),
                            readOnly: true,
                            onTap: () => _selectTime('endTime'),
                            validator: (v) {
                              if (v?.isEmpty ?? true) return null;
                              try {
                                DateFormat('HH:mm').parse(v!);
                                return null;
                              } catch (_) {
                                return 'Invalid time';
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Section: Details ───────────────────────────────────────────
              _SectionHeader(
                icon: Icons.info_outline_rounded,
                label: 'Details',
                color: const Color(0xFF8B5CF6),
                bg: const Color(0xFFEDE9FE),
              ),
              const SizedBox(height: 12),
              _FormCard(
                children: [
                  _FieldItem(
                    label: 'Location',
                    child: TextFormField(
                      controller: _locationController,
                      style: const TextStyle(
                          fontSize: 14, color: _T.textPrimary),
                      decoration: _inputDecoration('e.g. Community Hall',
                          suffix: const Icon(Icons.location_on_rounded,
                              size: 16, color: _T.textTertiary)),
                    ),
                  ),
                  _Divider(),
                  _FieldItem(
                    label: 'Contact Info',
                    child: TextFormField(
                      controller: _contactInfoController,
                      style: const TextStyle(
                          fontSize: 14, color: _T.textPrimary),
                      decoration: _inputDecoration(
                          'e.g. email or phone number',
                          suffix: const Icon(Icons.contact_mail_outlined,
                              size: 16, color: _T.textTertiary)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Submit Button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveAnnouncement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.accent,
                    disabledBackgroundColor: _T.accentMid,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEdit
                            ? Icons.check_rounded
                            : Icons.add_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEdit
                            ? 'Update Announcement'
                            : 'Create Announcement',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
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

// ── Reusable helpers ──────────────────────────────────────────────────────────

InputDecoration _inputDecoration(String hint, {Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle:
    const TextStyle(color: _T.textTertiary, fontSize: 14),
    suffixIcon: suffix,
    filled: true,
    fillColor: _T.bg,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _T.accentMid, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _T.red, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _T.red, width: 1.5),
    ),
    errorStyle: const TextStyle(fontSize: 12, color: _T.red),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _T.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;

  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.divider),
        boxShadow: const [
          BoxShadow(
              color: _T.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _FieldItem extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;

  const _FieldItem({
    required this.label,
    this.required = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _T.textTertiary,
                letterSpacing: 0.3,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                    fontSize: 12,
                    color: _T.red,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: _T.divider),
    );
  }
}