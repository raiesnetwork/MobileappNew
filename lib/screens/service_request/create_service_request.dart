import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/communities_provider.dart';
import '../../providers/service_request_provider.dart';


class CreateServiceRequestScreen extends StatefulWidget {
  final String? communityId;
  final Map<String, dynamic>? request;

  const CreateServiceRequestScreen({Key? key, this.communityId, this.request}) : super(key: key);

  @override
  State<CreateServiceRequestScreen> createState() => _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState extends State<CreateServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = '';
  String _selectedPriority = '';
  String _selectedAssignedTo = '';
  bool _isSubmitting = false;
  bool _isLoadingMembers = true;
  List<Map<String, dynamic>> _communityMembers = [];

  final List<String> _categories = [
    'Access_Request',
    'Billing / Payment',
    'Cleaning',
    'Complaint an issue',
    'Electrical',
    'Feedback',
    'Internet / Network',
    'Maintenance',
    'Others',
    'Plumbing',
    'Software / IT',
    'jhhh',
    'jhhhdfgffe',
  ];

  final List<Map<String, String>> _priorities = [
    {
      'value': 'Critical – Business/essential function is blocked',
      'label': 'Critical',
      'description': 'Business/essential function is blocked'
    },
    {
      'value': 'High – Needs action soon, moderate impact',
      'label': 'High',
      'description': 'Needs action soon, moderate impact'
    },
    {
      'value': 'Medium – Needs attention within a few hours',
      'label': 'Medium',
      'description': 'Needs attention within a few hours'
    },
    {
      'value': 'Low – Not urgent, can wait',
      'label': 'Low',
      'description': 'Not urgent, can wait'
    },
  ];

  @override
  void initState() {
    super.initState();

    if (widget.request != null) {
      _subjectController.text = widget.request!['subject'] ?? '';
      _descriptionController.text = widget.request!['description'] ?? '';
      _selectedCategory = widget.request!['category'] ?? '';
      _selectedPriority = widget.request!['priority'] ?? '';
      _selectedAssignedTo = widget.request!['assignedTo']?['_id'] ?? '';
    }

    // FIX: Delay API call until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCommunityMembers();
    });
  }

  Future<void> _loadCommunityMembers() async {
    if (widget.communityId == null) {
      setState(() {
        _isLoadingMembers = false;
      });
      return;
    }

    try {
      final communityProvider = Provider.of<CommunityProvider>(context, listen: false);
      final result = await communityProvider.fetchCommunityUsers(widget.communityId!);

      print('Community Users Result: $result'); // Debug print

      if (result['error'] == false && result['data'] != null) {
        final members = List<Map<String, dynamic>>.from(result['data']);
        print('Number of members: ${members.length}'); // Debug print
        if (members.isNotEmpty) {
          print('First member structure: ${members[0]}'); // Debug print
        }

        setState(() {
          _communityMembers = members;
          _isLoadingMembers = false;
        });
      } else {
        setState(() {
          _communityMembers = [];
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      print('Error loading community members: $e');
      setState(() {
        _communityMembers = [];
        _isLoadingMembers = false;
      });
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.request != null;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Service Request' : 'Create Service Request', style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        scrolledUnderElevation: 0,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard(
                title: 'Request Details',
                icon: Icons.assignment_outlined,
                children: [
                  _buildTextField(
                    controller: _subjectController,
                    label: 'Subject',
                    required: true,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    required: true,
                    maxLines: 4,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                title: 'Classification',
                icon: Icons.category_outlined,
                children: [
                  _buildCategorySelector(),
                  const SizedBox(height: 14),
                  _buildPrioritySelector(),
                  const SizedBox(height: 14),
                  _buildAssignedToSelector(),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        isEditing ? 'Update Request' : 'Create Request',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, size: 16, color: Colors.blue[700]),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool required,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            children: required
                ? [
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ]
                : null,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(10),
          ),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return '$label is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Category',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _selectedCategory.isEmpty ? null : _selectedCategory,
          decoration: InputDecoration(
            hintText: 'Select a category',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(10),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value ?? '';
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Category is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAssignedToSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Assigned To',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _isLoadingMembers
            ? Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading members...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        )
            : DropdownButtonFormField<String>(
          value: _selectedAssignedTo.isEmpty ? null : _selectedAssignedTo,
          decoration: InputDecoration(
            hintText: 'Select a member (optional)',
            prefixIcon: Icon(Icons.person_outline, color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('Unassigned'),
            ),
            ..._communityMembers.map<DropdownMenuItem<String>>((member) {
              final userData = member['userId'] as Map<String, dynamic>?;

              // Extract name safely
              String name = 'Unknown User';
              if (userData != null) {
                final profile = userData['profile'] as Map<String, dynamic>?;
                if (profile != null && profile['name'] != null && profile['name'].toString().trim().isNotEmpty) {
                  name = profile['name'].toString().trim();
                } else if (userData['email'] != null) {
                  name = userData['email'].toString().split('@').first; // fallback to email prefix
                } else if (userData['email'] != null) {
                  name = userData['email'].toString();
                }
              }

              // Extract user ID
              final String userId = userData?['_id']?.toString() ?? member['_id']?.toString() ?? '';

              return DropdownMenuItem<String>(
                value: userId,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: _getProfileImage(userData),
                      backgroundColor: Colors.grey.shade300,
                    ),

                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );

            }).toList(),
          ],
          onChanged: (value) {
            setState(() {
              _selectedAssignedTo = value ?? '';
            });
          },
          isExpanded: true,
        ),
      ],
    );

  }
  ImageProvider? _getProfileImage(Map<String, dynamic>? userData) {
    if (userData == null) return null;
    final profile = userData['profile'] as Map<String, dynamic>?;
    final imageUrl = profile?['profileImage']?.toString();

    if (imageUrl == null || imageUrl.isEmpty) return null;

    if (imageUrl.startsWith('http')) {
      return NetworkImage(imageUrl);
    } else if (imageUrl.startsWith('data:image')) {
      // Base64 image
      final uri = UriData.parse(imageUrl);
      return MemoryImage(uri.contentAsBytes());
    }
    return null;
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Priority',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ..._priorities.map((priority) {
          final isSelected = _selectedPriority == priority['value'];
          final color = _getPriorityColor(priority['label']!);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPriority = priority['value']!;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.1) : Colors.white,
                border: Border.all(
                  color: isSelected ? color : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.transparent,
                      border: Border.all(color: color, width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: isSelected ? Icon(Icons.check, size: 10, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag, size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(
                              priority['label']!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? color : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          priority['description']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        if (_selectedPriority.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Priority is required',
              style: TextStyle(
                fontSize: 10,
                color: Colors.red[700],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedPriority.isEmpty) {
      if (_selectedPriority.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a priority level'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = Provider.of<ServiceRequestProvider>(context, listen: false);
      Map<String, dynamic> result;

      if (widget.request != null) {
        // Update existing request
        result = await provider.updateServiceRequest(
          requestId: widget.request!['_id'],
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          assignedTo: _selectedAssignedTo.isEmpty ? null : _selectedAssignedTo,
          status: widget.request!['status'],
        );
      } else {
        // Create new request
        result = await provider.createServiceRequest(
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          assignedTo: _selectedAssignedTo.isEmpty ? null : _selectedAssignedTo,
          communityId: widget.communityId,
        );
      }

      if (result['error'] == false && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? (widget.request != null ? 'Service request updated successfully' : 'Service request created successfully')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? (widget.request != null ? 'Failed to update service request' : 'Failed to create service request')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}