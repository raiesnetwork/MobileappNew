import 'package:flutter/material.dart';
import 'package:ixes.app/providers/communities_provider.dart';

import 'package:provider/provider.dart';

import '../../constants/constants.dart';

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
  final TextEditingController _communityNameController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedInviteType = 'mail';

  @override
  void initState() {
    super.initState();
    if (widget.communityName != null) {
      _communityNameController.text = widget.communityName!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context
            .read<CommunityProvider>()
            .checkCommunityStatus(widget.communityName!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Community Invitations',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<CommunityProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildCommunityCheckSection(provider),
                  const SizedBox(height: 16),
                  if (provider.canSendInvites)
                    _buildSendInvitationSection(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommunityCheckSection(CommunityProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: Primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Check Community Status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _communityNameController,
              decoration: InputDecoration(
                labelText: 'Community Name',
                hintText: 'Enter community name',
                prefixIcon: Icon(Icons.group_rounded, color: Primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: provider.isCheckingStatus
                    ? null
                    : () {
                        if (_communityNameController.text.trim().isNotEmpty) {
                          provider.checkCommunityStatus(
                              _communityNameController.text.trim());
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: provider.isCheckingStatus
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Checking Status...',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : const Text('Check Status',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            if (provider.checkErrorMessage != null) ...[
              const SizedBox(height: 20),
              _buildErrorCard(provider.checkErrorMessage!),
            ],
            if (provider.communityData != null) ...[
              const SizedBox(height: 20),
              _buildStatusCard(provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSendInvitationSection(CommunityProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Send Invitations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInviteTypeButton(
                      label: 'Email',
                      icon: Icons.email_rounded,
                      value: 'mail',
                      isSelected: _selectedInviteType == 'mail',
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: _buildInviteTypeButton(
                      label: 'SMS',
                      icon: Icons.sms_rounded,
                      value: 'mobile',
                      isSelected: _selectedInviteType == 'mobile',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _selectedInviteType == 'mail'
                  ? _buildEmailField()
                  : _buildPhoneField(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    provider.isSendingInvitation ? null : _sendInvitation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: provider.isSendingInvitation
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Sending...',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Send Invitation',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            if (provider.sendInvitationMessage != null) ...[
              const SizedBox(height: 20),
              _buildInvitationResultCard(provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInviteTypeButton({
    required String label,
    required IconData icon,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedInviteType = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Primary : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Primary : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      key: const ValueKey('email'),
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'Email Address',
        hintText: 'example@email.com',
        prefixIcon: Icon(Icons.email_rounded, color: Primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      key: const ValueKey('phone'),
      controller: _phoneController,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '+91 9876543210',
        helperText: 'Enter 10-digit mobile number (country code auto-added)',
        helperStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
        prefixIcon: Icon(Icons.phone_rounded, color: Primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.red[700], size: 22),
              const SizedBox(width: 8),
              Text(
                'Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.red[700], fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Troubleshooting Tips:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red[900],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                _buildTipRow('Check community name spelling'),
                _buildTipRow('Verify internet connection'),
                _buildTipRow('Try again in a moment'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(String tip) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: Colors.red[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(CommunityProvider provider) {
    final status = provider.inviteStatus;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getStatusColor(status).withOpacity(0.1),
            _getStatusColor(status).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _getStatusColor(status).withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(_getStatusIcon(status), color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Community Found',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      provider.communityData!['name'],
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status!.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          _buildStatusMessage(status),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationResultCard(CommunityProvider provider) {
    final isSuccess = provider.invitationSent == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isSuccess ? Colors.green[200]! : Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                color: isSuccess ? Colors.green[700] : Colors.red[700],
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                isSuccess ? 'Success!' : 'Failed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? Colors.green[700] : Colors.red[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            provider.sendInvitationMessage!,
            style: TextStyle(
              color: isSuccess ? Colors.green[700] : Colors.red[700],
              fontSize: 14,
            ),
          ),
          if (isSuccess) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedInviteType == 'mail'
                        ? Icons.email_rounded
                        : Icons.sms_rounded,
                    color: Colors.green[700],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Invitation sent via ${_selectedInviteType == 'mail' ? 'email' : 'SMS'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusMessage(String status) {
    String message;
    IconData icon;
    Color color;

    switch (status) {
      case 'ACCEPTED':
        message =
            'You are a member of this community and can send invitations!';
        icon = Icons.verified_rounded;
        color = Colors.green;
        break;
      case 'PENDING':
        message = 'Your invitation is pending approval';
        icon = Icons.hourglass_empty_rounded;
        color = Colors.orange;
        break;
      case 'REJECTED':
        message = 'Your invitation was rejected';
        icon = Icons.block_rounded;
        color = Colors.red;
        break;
      default:
        message = 'You are not a member of this community';
        icon = Icons.info_rounded;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
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
        return Icons.check_circle_rounded;
      case 'PENDING':
        return Icons.access_time_rounded;
      case 'REJECTED':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  bool _isValidPhone(String phone) {
    String trimmedPhone = phone.trim();

    if (trimmedPhone.startsWith('+')) {
      String cleanPhone =
          trimmedPhone.substring(1).replaceAll(RegExp(r'[\s\-\(\)]'), '');
      return RegExp(r'^\d+$').hasMatch(cleanPhone) &&
          cleanPhone.length >= 10 &&
          cleanPhone.length <= 15;
    }

    String cleanPhone = trimmedPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (RegExp(r'^\d{10}$').hasMatch(cleanPhone) &&
        cleanPhone.startsWith(RegExp(r'[6-9]'))) {
      return true;
    }

    return false;
  }

  void _sendInvitation() {
    final provider = context.read<CommunityProvider>();
    String contact = _selectedInviteType == 'mail'
        ? _emailController.text.trim()
        : _phoneController.text.trim();

    if (contact.isEmpty) {
      _showSnackBar(
        'Please enter ${_selectedInviteType == 'mail' ? 'email address' : 'phone number'}',
        isError: true,
      );
      return;
    }

    if (_selectedInviteType == 'mail' && !_isValidEmail(contact)) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }

    if (_selectedInviteType == 'mobile') {
      if (!_isValidPhone(contact)) {
        _showSnackBar(
          'Please enter a valid phone number with country code (e.g., +919876543210)',
          isError: true,
        );
        return;
      }

      if (!contact.startsWith('+')) {
        String cleanPhone = contact.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        if (RegExp(r'^\d{10}$').hasMatch(cleanPhone) &&
            cleanPhone.startsWith(RegExp(r'[6-9]'))) {
          contact = '+91$cleanPhone';
        }
      }
    }

    if (provider.communityData == null) {
      _showSnackBar('Please check community status first', isError: true);
      return;
    }

    provider.sendInvitationLink(
      communityId: provider.communityData!['_id'],
      type: _selectedInviteType,
      contact: contact,
    );

    if (_selectedInviteType == 'mail') {
      _emailController.clear();
    } else {
      _phoneController.clear();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  void dispose() {
    _communityNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
