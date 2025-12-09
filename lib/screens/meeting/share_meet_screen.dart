import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/generate_link_provider.dart';

class ShareMeetScreen extends StatefulWidget {
  final String meetLink;
  final String linkId;
  final String description;
  final DateTime startDateTime;
  final DateTime endDateTime;

  const ShareMeetScreen({
    Key? key,
    required this.meetLink,
    required this.linkId,
    required this.description,
    required this.startDateTime,
    required this.endDateTime,
  }) : super(key: key);

  @override
  State<ShareMeetScreen> createState() => _ShareMeetScreenState();
}

class _ShareMeetScreenState extends State<ShareMeetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _userIdController = TextEditingController();

  String _shareType = 'personal';
  List<Map<String, String>> _emailList = [];
  List<Map<String, String>> _memberList = [];

  bool _showRecurrence = false;
  String _frequency = 'weekly';
  int _interval = 1;
  List<int> _daysOfWeek = [];
  DateTime? _recurrenceEndDate;

  @override
  void dispose() {
    _emailController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.meetLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Link copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _addEmail() {
    if (_emailController.text.isNotEmpty) {
      setState(() {
        _emailList.add({
          'email': _emailController.text,
        });
        _emailController.clear();
      });
    }
  }

  void _addMember() {
    if (_userIdController.text.isNotEmpty) {
      setState(() {
        _memberList.add({'value': _userIdController.text});
        _userIdController.clear();
      });
    }
  }

  Future<void> _shareMeeting() async {
    // Validate that user has added recipients based on share type
    if (_shareType == 'mail' && _emailList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one email recipient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_shareType == 'personal' && _memberList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = Provider.of<MeetProvider>(context, listen: false);

    Map<String, dynamic>? recurrenceSettings;
    if (_showRecurrence) {
      recurrenceSettings = {
        'frequency': _frequency,
        'interval': _interval,
        if (_daysOfWeek.isNotEmpty) 'daysOfWeek': _daysOfWeek,
        if (_recurrenceEndDate != null)
          'endDate': _recurrenceEndDate!.toIso8601String(),
      };
    }

    final success = await provider.shareMeetLink(
      meetLink: widget.meetLink,
      dateAndTimeFrom: widget.startDateTime.toUtc().toIso8601String(),
      dateAndTimeTo: widget.endDateTime.toUtc().toIso8601String(),
      description: widget.description,
      type: _shareType,
      members: _shareType == 'personal' || _shareType == 'groups'
          ? _memberList
          : null,
      mail: _shareType == 'mail' ? _emailList : null,
      recurrenceSettings: recurrenceSettings,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Meeting invitation sent successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to share meeting'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Share Meeting',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Consumer<MeetProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Meeting Link Display Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your Meeting Link',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.meetLink,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _copyLink,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Meeting Details Display (Read-only)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Meeting Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.description_rounded,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Start Time
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline_rounded,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a')
                                      .format(widget.startDateTime),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // End Time
                        Row(
                          children: [
                            Icon(
                              Icons.stop_circle_outlined,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a')
                                      .format(widget.endDateTime),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Share Type Selection
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share With',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildShareTypeOption(
                            'personal', 'Personal', Icons.person_rounded),
                        const SizedBox(height: 12),
                        _buildShareTypeOption(
                            'mail', 'Email', Icons.email_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email/Member Input
                  if (_shareType == 'mail') ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Recipients',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: 'Email address',
                                    prefixIcon:
                                    const Icon(Icons.email_outlined),
                                    filled: true,
                                    fillColor: const Color(0xFFF8F9FA),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _addEmail,
                                icon: const Icon(Icons.add_circle),
                                color: const Color(0xFF6366F1),
                                iconSize: 32,
                              ),
                            ],
                          ),
                          if (_emailList.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _emailList.map((email) {
                                return Chip(
                                  label: Text(email['email']!),
                                  deleteIcon:
                                  const Icon(Icons.close, size: 18),
                                  onDeleted: () {
                                    setState(() {
                                      _emailList.remove(email);
                                    });
                                  },
                                  backgroundColor:
                                  const Color(0xFF6366F1).withOpacity(0.1),
                                  deleteIconColor: const Color(0xFF6366F1),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else if (_shareType == 'personal') ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Members',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _userIdController,
                                  decoration: InputDecoration(
                                    hintText: 'User ID',
                                    prefixIcon:
                                    const Icon(Icons.person_outline),
                                    filled: true,
                                    fillColor: const Color(0xFFF8F9FA),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _addMember,
                                icon: const Icon(Icons.add_circle),
                                color: const Color(0xFF6366F1),
                                iconSize: 32,
                              ),
                            ],
                          ),
                          if (_memberList.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _memberList.map((member) {
                                return Chip(
                                  label: Text(member['value']!),
                                  deleteIcon:
                                  const Icon(Icons.close, size: 18),
                                  onDeleted: () {
                                    setState(() {
                                      _memberList.remove(member);
                                    });
                                  },
                                  backgroundColor:
                                  const Color(0xFF6366F1).withOpacity(0.1),
                                  deleteIconColor: const Color(0xFF6366F1),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Recurrence Settings
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recurring Meeting',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Switch(
                              value: _showRecurrence,
                              onChanged: (value) {
                                setState(() => _showRecurrence = value);
                              },
                              activeColor: const Color(0xFF6366F1),
                            ),
                          ],
                        ),
                        if (_showRecurrence) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Frequency Selector
                          const Text(
                            'Frequency',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildFrequencyChip('daily', 'Daily'),
                              const SizedBox(width: 8),
                              _buildFrequencyChip('weekly', 'Weekly'),
                              const SizedBox(width: 8),
                              _buildFrequencyChip('monthly', 'Monthly'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Days of Week (only for weekly)
                          if (_frequency == 'weekly') ...[
                            const Text(
                              'Repeat On',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildDayChip(1, 'Mon'),
                                _buildDayChip(2, 'Tue'),
                                _buildDayChip(3, 'Wed'),
                                _buildDayChip(4, 'Thu'),
                                _buildDayChip(5, 'Fri'),
                                _buildDayChip(6, 'Sat'),
                                _buildDayChip(7, 'Sun'),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Interval
                          Row(
                            children: [
                              const Text(
                                'Repeat every',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: DropdownButton<int>(
                                    value: _interval,
                                    underline: const SizedBox(),
                                    items: List.generate(10, (index) => index + 1)
                                        .map((i) => DropdownMenuItem(
                                      value: i,
                                      child: Text('$i'),
                                    ))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _interval = value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _frequency == 'daily'
                                    ? 'day(s)'
                                    : _frequency == 'weekly'
                                    ? 'week(s)'
                                    : 'month(s)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Share Button
                  ElevatedButton(
                    onPressed: provider.isLoading ? null : _shareMeeting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded),
                        SizedBox(width: 8),
                        Text(
                          'Send Invitation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShareTypeOption(String value, String label, IconData icon) {
    final isSelected = _shareType == value;
    return InkWell(
      onTap: () => setState(() {
        _shareType = value;
        _emailList.clear();
        _memberList.clear();
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF6366F1) : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF6366F1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyChip(String value, String label) {
    final isSelected = _frequency == value;
    return InkWell(
      onTap: () => setState(() => _frequency = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(int day, String label) {
    final isSelected = _daysOfWeek.contains(day);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _daysOfWeek.remove(day);
          } else {
            _daysOfWeek.add(day);
          }
        });
      },
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : const Color(0xFFF8F9FA),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}