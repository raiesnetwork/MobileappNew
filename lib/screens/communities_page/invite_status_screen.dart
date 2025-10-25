import 'package:flutter/material.dart';
import 'package:ixes.app/providers/communities_provider.dart';
import 'package:provider/provider.dart';

class InviteStatusScreen extends StatefulWidget {
  final String? communityId;
  final String? communityName;

  const InviteStatusScreen({
    Key? key,
    this.communityId,
    this.communityName,
  }) : super(key: key);

  @override
  _InviteStatusScreenState createState() => _InviteStatusScreenState();
}

class _InviteStatusScreenState extends State<InviteStatusScreen> {
  final TextEditingController _communityNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedInviteType = 'mail'; // 'mail' or 'mobile'

  @override
  void initState() {
    super.initState();
    if (widget.communityName != null) {
      _communityNameController.text = widget.communityName!;
      // Auto-check status if community name is provided
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CommunityProvider>().checkCommunityStatus(widget.communityName!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Community Invitations'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Consumer<CommunityProvider>(
          builder: (context, provider, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step 1: Check Community Status
                _buildCommunityCheckSection(provider),

                SizedBox(height: 24),

                // Step 2: Send Invitations (only if user is accepted)
                if (provider.canSendInvites)
                  _buildSendInvitationSection(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  // Step 1: Community Status Check Section
  Widget _buildCommunityCheckSection(CommunityProvider provider) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check Community Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            TextField(
              controller: _communityNameController,
              decoration: InputDecoration(
                labelText: 'Community Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.isCheckingStatus
                    ? null
                    : () {
                  if (_communityNameController.text.trim().isNotEmpty) {
                    provider.checkCommunityStatus(_communityNameController.text.trim());
                  }
                },
                child: provider.isCheckingStatus
                    ?  const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Checking...'),
                  ],
                )
                    : Text('Check Status'),
              ),
            ),

            SizedBox(height: 16),

            // Enhanced Error Display
            if (provider.checkErrorMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Error',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      provider.checkErrorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Troubleshooting tips:\n• Check community name spelling\n• Verify you have internet connection\n• Try again in a moment',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            if (provider.communityData != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(provider.inviteStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getStatusColor(provider.inviteStatus)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_getStatusIcon(provider.inviteStatus),
                            color: _getStatusColor(provider.inviteStatus)),
                        SizedBox(width: 8),
                        Text(
                          'Community Found!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(provider.inviteStatus),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Name: ${provider.communityData!['name']}'),
                    Text('ID: ${provider.communityData!['_id']}'),
                    Text('Status: ${provider.inviteStatus}'),
                    SizedBox(height: 8),
                    _buildStatusMessage(provider.inviteStatus!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Step 2: Send Invitation Section
  Widget _buildSendInvitationSection(CommunityProvider provider) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Invitations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            // Invitation Type Selection
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: Text('Email'),
                    value: 'mail',
                    groupValue: _selectedInviteType,
                    onChanged: (value) {
                      setState(() {
                        _selectedInviteType = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: Text('SMS'),
                    value: 'mobile',
                    groupValue: _selectedInviteType,
                    onChanged: (value) {
                      setState(() {
                        _selectedInviteType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Contact Input
            if (_selectedInviteType == 'mail')
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  hintText: 'example@email.com',
                ),
                keyboardType: TextInputType.emailAddress,
              )
            else
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),

                  helperText: ' enter 10-digit mobile number',
                ),
                keyboardType: TextInputType.phone,
              ),

            SizedBox(height: 16),

            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.isSendingInvitation ? null : _sendInvitation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: provider.isSendingInvitation
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Sending...'),
                  ],
                )
                    : Text(
                  'Send Invitation',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Send Result
            if (provider.sendInvitationMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: provider.invitationSent == true
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: provider.invitationSent == true
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          provider.invitationSent == true ? Icons.check_circle : Icons.error,
                          color: provider.invitationSent == true ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text(
                          provider.invitationSent == true ? 'Success!' : 'Failed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: provider.invitationSent == true
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      provider.sendInvitationMessage!,
                      style: TextStyle(
                        color: provider.invitationSent == true
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    if (provider.invitationSent == true) ...[
                      SizedBox(height: 8),
                      Text(
                        'The invitation link has been sent via ${_selectedInviteType == 'mail' ? 'email' : 'SMS'}.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Updated phone validation method
  bool _isValidPhone(String phone) {
    String trimmedPhone = phone.trim();

    // Check if it starts with country code
    if (trimmedPhone.startsWith('+')) {
      // Remove + and spaces/dashes
      String cleanPhone = trimmedPhone.substring(1).replaceAll(RegExp(r'[\s\-\(\)]'), '');
      // Must be all digits and reasonable length (10-15 digits)
      return RegExp(r'^\d+$').hasMatch(cleanPhone) &&
          cleanPhone.length >= 10 &&
          cleanPhone.length <= 15;
    }

    // If no country code, assume Indian number and auto-add +91
    String cleanPhone = trimmedPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (RegExp(r'^\d{10}$').hasMatch(cleanPhone) && cleanPhone.startsWith(RegExp(r'[6-9]'))) {
      return true; // Valid 10-digit Indian number
    }

    return false;
  }

  // Updated send invitation method with enhanced phone formatting
  void _sendInvitation() {
    final provider = context.read<CommunityProvider>();
    String contact = _selectedInviteType == 'mail'
        ? _emailController.text.trim()
        : _phoneController.text.trim();

    // Enhanced validation
    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter ${_selectedInviteType == 'mail' ? 'email address' : 'phone number'}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Email validation
    if (_selectedInviteType == 'mail' && !_isValidEmail(contact)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Phone validation and formatting
    if (_selectedInviteType == 'mobile') {
      if (!_isValidPhone(contact)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid phone number with country code (e.g., +919876543210)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Auto-format Indian numbers without country code
      if (!contact.startsWith('+')) {
        String cleanPhone = contact.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        if (RegExp(r'^\d{10}$').hasMatch(cleanPhone) && cleanPhone.startsWith(RegExp(r'[6-9]'))) {
          contact = '+91$cleanPhone'; // Add India country code
          print('Auto-formatted phone: $contact');
        }
      }
    }

    // Check if community data is available
    if (provider.communityData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please check community status first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Send the invitation with properly formatted contact
    provider.sendInvitationLink(
      communityId: provider.communityData!['_id'],
      type: _selectedInviteType,
      contact: contact, // Now properly formatted with country code
    );

    // Clear the input after sending
    if (_selectedInviteType == 'mail') {
      _emailController.clear();
    } else {
      _phoneController.clear();
    }
  }

  // Helper validation methods
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Widget _buildStatusMessage(String status) {
    switch (status) {
      case 'ACCEPTED':
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '✅ You are a member of this community and can send invitations!',
            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
          ),
        );
      case 'PENDING':
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '⏳ Your invitation is pending approval',
            style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold),
          ),
        );
      case 'REJECTED':
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '❌ Your invitation was rejected',
            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
          ),
        );
      default:
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '❓ Unknown status: $status',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        );
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ACCEPTED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'ACCEPTED':
        return Icons.check_circle;
      case 'PENDING':
        return Icons.access_time;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  void dispose() {
    _communityNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}