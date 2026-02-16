import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/screens/profilePage/componants/chengepassword.dart';
import 'package:ixes.app/screens/profilePage/componants/edit_profile.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _isInitializing = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _initializeUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    try {
      final hasData = await authProvider.hasUserDataInStorage();
      if (hasData && authProvider.user == null) {
        await authProvider.loadUserFromStorage();
      }

      // Fetch profile and dashboard data
      await Future.wait([
        profileProvider.getUserProfile(),
        profileProvider.getDashboardData(),
      ]);

      await authProvider.debugStorageContents();
      _animationController.forward();
    } catch (e) {
      debugPrint('Error initializing user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ProfileProvider>(
      builder: (context, authProvider, profileProvider, child) {
        final user = authProvider.user;
        final profile = profileProvider.userProfile;
        final dashboard = profileProvider.dashboardData;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: _isInitializing
              ? const Center(child: CircularProgressIndicator())
              : user == null
              ? _buildEmptyState(authProvider)
              : _buildProfileContent(user, profile, dashboard, authProvider, profileProvider),
        );
      },
    );
  }

  Widget _buildEmptyState(AuthProvider authProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text("No User Data",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text("Unable to load your profile",
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _retryLoadData(authProvider),
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
      user,
      Map<String, dynamic>? profile,
      Map<String, dynamic>? dashboard,
      AuthProvider authProvider,
      ProfileProvider profileProvider
      ) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        slivers: [
          // Custom App Bar with Profile Header
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: Primary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildProfileHeader(user, profile),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () => _navigateToEditProfile(context, profileProvider),
                tooltip: "Edit Profile",
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => _handleLogout(context, authProvider, profileProvider),
                tooltip: "Logout",
              ),
            ],
          ),

          // Dashboard Stats
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: _buildDashboardStats(dashboard),
            ),
          ),

          // Profile Information
          SliverToBoxAdapter(
            child: _buildProfileInfo(profile),
          ),

          // Action Cards
          SliverToBoxAdapter(
            child: _buildActionCards(context, authProvider, profileProvider),
          ),

          // Bottom Spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(user, Map<String, dynamic>? profile) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Primary,
            Color.fromARGB(255, 120, 40, 200),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Image - Reduced size
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.white,
                  backgroundImage: _getProfileImage(profile),
                  child: _getProfileImage(profile) == null
                      ? Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : "U",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Primary,
                    ),
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 10),

              // Name - Reduced size
              Text(
                profile?['name'] ?? user.username,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),

              // Contact Info - Compact layout
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Phone
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_rounded,
                            color: Colors.white.withOpacity(0.9),
                            size: 14),
                        const SizedBox(width: 6),
                        Text(
                          profile?['mobile'] ?? user.mobile,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Email
                    if (profile?['email'] != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.email_rounded,
                              color: Colors.white.withOpacity(0.9),
                              size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              profile!['email'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildDashboardStats(Map<String, dynamic>? dashboard) {
    final stats = [
      {
        'label': 'Communities',
        'value': dashboard?['totalCommunities']?.toString() ?? '0',
        'icon': Icons.groups,
        'color': Colors.blue,
      },
      {
        'label': 'Campaigns',
        'value': dashboard?['totalCampaigns']?.toString() ?? '0',
        'icon': Icons.campaign,
        'color': Colors.purple,
      },
      {
        'label': 'Services',
        'value': dashboard?['totalServices']?.toString() ?? '0',
        'icon': Icons.room_service,
        'color': Colors.orange,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: stats.map((stat) => _buildStatItem(
              stat['label'] as String,
              stat['value'] as String,
              stat['icon'] as IconData,
              stat['color'] as Color,
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo(Map<String, dynamic>? profile) {
    if (profile == null) return const SizedBox.shrink();

    final infoItems = [
      if (profile['birthdate'] != null)
        {'icon': Icons.cake, 'label': 'Birthday', 'value': profile['birthdate']},
      if (profile['location'] != null)
        {'icon': Icons.location_on, 'label': 'Location', 'value': profile['location']},
      if (profile['address'] != null)
        {'icon': Icons.home, 'label': 'Address', 'value': profile['address']},
    ];

    if (infoItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ...infoItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item['icon'] as IconData,
                          color: Primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            item['value'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCards(
      BuildContext context,
      AuthProvider authProvider,
      ProfileProvider profileProvider
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildActionCard(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            color: Colors.blue,
            onTap: () => _navigateToEditProfile(context, profileProvider),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              );
            },
          ),SizedBox(height: 20,),



          SizedBox(
           width: 139,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444), // Modern red
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: authProvider.isLoading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.logout, size: 20),
              label: Text(
                authProvider.isLoading ? "Logging out..." : "Logout",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              onPressed: authProvider.isLoading
                  ? null
                  : () => _handleLogout(context, authProvider, profileProvider),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context, ProfileProvider profileProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    ).then((_) {
      // Refresh profile data after returning from edit screen
      profileProvider.getUserProfile();
      profileProvider.getDashboardData();
    });
  }

  Future<void> _retryLoadData(AuthProvider authProvider) async {
    setState(() => _isInitializing = true);
    await _initializeUserData();
  }

  void _handleLogout(
      BuildContext context,
      AuthProvider authProvider,
      ProfileProvider profileProvider
      ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Sign Out"),
          ],
        ),
        content: const Text(
          "Are you sure you want to sign out? You'll need to log in again to access your account.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Logout handles clearing providers internally
      await authProvider.logout(context);

      // Navigate
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: "HKM Community",
      applicationVersion: "1.0.0",
      applicationIcon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.groups, size: 50, color: Primary),
      ),
      children: const [
        Text(
          "A modern social platform for connecting, sharing, and engaging with your community. Built with Flutter and powered by advanced community management features.",
        ),
      ],
    );
  }

  ImageProvider? _getProfileImage(Map<String, dynamic>? profile) {
    if (profile == null || profile['profileImage'] == null || profile['profileImage'].toString().isEmpty) {
      return null;
    }

    String imageData = profile['profileImage'].toString().trim();

    // Handle Base64 data URL
    if (imageData.startsWith('data:image')) {
      try {
        // Extract base64 part after comma
        String base64String = imageData.split(',').last;

        // Clean whitespace and newlines
        base64String = base64String.replaceAll(RegExp(r'\s+'), '');

        // Fix missing padding
        switch (base64String.length % 4) {
          case 2:
            base64String += '==';
            break;
          case 3:
            base64String += '=';
            break;
        }

        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('Base64 decode failed: $e');
        debugPrint('Problematic base64 string: ${imageData.substring(0, 100)}...');
        return null;
      }
    }

    // Handle regular HTTP URLs
    if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      return NetworkImage(imageData);
    }

    // Fallback: try as network anyway (some APIs return full URL without http prefix?)
    try {
      return NetworkImage(imageData);
    } catch (_) {
      return null;
    }
  }
}