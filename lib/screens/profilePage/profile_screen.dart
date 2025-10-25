import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/screens/profilePage/componants/chengepassword.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final hasData = await authProvider.hasUserDataInStorage();
      if (hasData && authProvider.user == null) {
        await authProvider.loadUserFromStorage();
      }
      await authProvider.debugStorageContents();
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
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black,
            title: const Text(
              'Profile',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _handleLogout(context, authProvider),
                tooltip: "Logout",
              ),
            ],
          ),
          body: _isInitializing
              ? const Center(child: CircularProgressIndicator())
              : user == null
              ? _buildEmptyState(authProvider)
              : _buildProfileContent(user, authProvider),
        );
      },
    );
  }

  Widget _buildEmptyState(AuthProvider authProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No User Data",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Unable to load your profile",
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _retryLoadData(authProvider),
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(user, AuthProvider authProvider) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 🌟 Profile Header with Gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(165, 55, 0, 255),
                  Color.fromARGB(70, 179, 15, 219)
                ],


              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : "U",
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.username,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                Text(
                  user.mobile,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    Chip(
                      label: Text(user.isFamilyHead ? "Family Head" : "Member",style:TextStyle(color: Colors.white) ,),
                      backgroundColor:
                      user.isFamilyHead ? Colors.blue[100] : Primary,
                    ),
                    Chip(
                      label: Text(user.guidStatus ? "Guided" : "New User",style: TextStyle(color: Colors.white),),
                      backgroundColor: user.guidStatus
                          ? Colors.green
                          : Primary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Options Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildOptionTile(Icons.edit, "Edit Profile", () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Coming Soon")));
                  }),
                  _buildDivider(),
                  _buildOptionTile(Icons.lock, "Change Password", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ChangePasswordPage()));
                  }),
                  _buildDivider(),
                  _buildOptionTile(Icons.notifications, "Notifications", () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Coming Soon")));
                  }),
                  _buildDivider(),
                  _buildOptionTile(Icons.info, "About", () {
                    _showAboutDialog(context);
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // 🔴 Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: authProvider.isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.logout),
              label: Text(
                authProvider.isLoading ? "Signing Out..." : "Signout",
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: authProvider.isLoading
                  ? null
                  : () => _handleLogout(context, authProvider),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withOpacity(0.1),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider() => Divider(
    height: 1,
    color: Colors.grey.shade300,
    indent: 16,
    endIndent: 16,
  );

  // Retry load Data
  Future<void> _retryLoadData(AuthProvider authProvider) async {
    setState(() => _isInitializing = true);
    await _initializeUserData();
  }

  void _handleLogout(BuildContext context, AuthProvider authProvider) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authProvider.logout();
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
      applicationIcon: const Icon(Icons.share, size: 50, color: Colors.blue),
      children: const [
        Text(
            "A social platform for connecting, sharing, and engaging with your community."),
      ],
    );
  }
}
