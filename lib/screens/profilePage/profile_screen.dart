import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/screens/profilePage/componants/chengepassword.dart';
import 'package:ixes.app/screens/profilePage/componants/edit_profile.dart';
import 'package:provider/provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/campaign_provider.dart';
import '../../providers/profile_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
      _scrollController.addListener(() {
        final collapsed = _scrollController.offset > 160;
        if (collapsed != _isCollapsed) {
          setState(() => _isCollapsed = collapsed);
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeUserData() async {
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();

    if (profileProvider.userProfile != null) {
      _animationController.forward();
      profileProvider.getUserProfile();
      profileProvider.getDashboardData();
      return;
    }

    if (authProvider.user == null) {
      final hasData = await authProvider.hasUserDataInStorage();
      if (hasData) await authProvider.loadUserFromStorage();
    }

    profileProvider
        .getUserProfile()
        .then((_) => _animationController.forward());
    profileProvider.getDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ProfileProvider>(
      builder: (context, authProvider, profileProvider, _) {
        final user = authProvider.user;
        final profile = profileProvider.userProfile;
        final dashboard = profileProvider.dashboardData;

        if (profile == null && profileProvider.isLoadingProfile) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F9FB),
            body: Center(
              child: CircularProgressIndicator(color: Primary),
            ),
          );
        }

        if (user == null && profile == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FB),
            body: _buildEmptyState(authProvider),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildProfileContent(
                  user, profile, dashboard, authProvider, profileProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AuthProvider authProvider) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_off_outlined,
              size: 48, color: Colors.grey[400]),
        ),
        const SizedBox(height: 20),
        const Text('No Profile Found',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Text('We couldn\'t load your profile data',
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: () => _initializeUserData(),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Try Again',
              style: TextStyle(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Primary,
            foregroundColor: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ]),
    );
  }

  Widget _buildProfileContent(
      user,
      Map<String, dynamic>? profile,
      Map<String, dynamic>? dashboard,
      AuthProvider authProvider,
      ProfileProvider profileProvider,
      ) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Redesigned App Bar ──────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 230,
          floating: false,
          pinned: true,
          backgroundColor: Primary,
          elevation: 0,

          // Title only visible when header is collapsed
          title: AnimatedOpacity(
            opacity: _isCollapsed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _isCollapsed
                ? _CollapsedProfileTitle(
              user: user,
              profile: profile,
              getProfileImage: _getProfileImage,
            )
                : const SizedBox.shrink(),
          ),
          centerTitle: false,
          actions: [
            _AppBarIconButton(
              icon: Icons.edit_outlined,
              onPressed: () =>
                  _navigateToEditProfile(context, profileProvider),
              tooltip: 'Edit Profile',
            ),
            _AppBarIconButton(
              icon: Icons.logout_rounded,
              onPressed: () =>
                  _handleLogout(context, authProvider, profileProvider),
              tooltip: 'Logout',
            ),
            const SizedBox(width: 4),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: _buildProfileHeader(user, profile),
          ),
        ),

        // ── Stats strip ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _buildDashboardStats(dashboard),
        ),

        // ── Personal info card ──────────────────────────────────────────
        SliverToBoxAdapter(child: _buildProfileInfo(profile)),

        // ── Action cards ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _buildActionCards(context, authProvider, profileProvider),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ── Expanded header ─────────────────────────────────────────────────────
  Widget _buildProfileHeader(user, Map<String, dynamic>? profile) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B35E8), Color(0xFF9B59F5)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative blobs
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.only(top: 8, bottom: 16, left: 24, right: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFE0D4FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFFF3EEFF),
                      backgroundImage: _getProfileImage(profile),
                      child: _getProfileImage(profile) == null
                          ? Text(
                        user?.username?.isNotEmpty == true
                            ? user.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Primary,
                        ),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Name
                  Text(
                    profile?['name'] ?? user?.username ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Contact chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (profile?['mobile'] != null ||
                          user?.mobile != null)
                        _ContactChip(
                          icon: Icons.phone_rounded,
                          label: profile?['mobile'] ?? user?.mobile ?? '',
                        ),
                      if (profile?['email'] != null)
                        _ContactChip(
                          icon: Icons.email_rounded,
                          label: profile!['email'],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats ────────────────────────────────────────────────────────────────
  Widget _buildDashboardStats(Map<String, dynamic>? dashboard) {
    final stats = [
      _StatData(
        label: 'Communities',
        value: dashboard?['totalCommunities']?.toString() ?? '0',
        icon: Icons.groups_rounded,
        color: const Color(0xFF4F8EF7),
        bgColor: const Color(0xFFEBF2FF),
      ),
      _StatData(
        label: 'Campaigns',
        value: dashboard?['totalCampaigns']?.toString() ?? '0',
        icon: Icons.campaign_rounded,
        color: const Color(0xFF9B59F5),
        bgColor: const Color(0xFFF3EEFF),
      ),
      _StatData(
        label: 'Services',
        value: dashboard?['totalServices']?.toString() ?? '0',
        icon: Icons.room_service_rounded,
        color: const Color(0xFFFF8C42),
        bgColor: const Color(0xFFFFF1E8),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
          child: Row(
            children: List.generate(stats.length, (i) {
              final s = stats[i];
              return Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildStatTile(s)),
                    if (i < stats.length - 1)
                      Container(
                        width: 1,
                        height: 44,
                        color: const Color(0xFFEEEEF5),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(_StatData s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: s.bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(s.icon, color: s.color, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          s.value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9494AA),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ── Personal info ────────────────────────────────────────────────────────
  Widget _buildProfileInfo(Map<String, dynamic>? profile) {
    if (profile == null) return const SizedBox.shrink();

    final infoItems = [
      if (profile['birthdate'] != null)
        _InfoItem(
            icon: Icons.cake_rounded,
            label: 'Birthday',
            value: profile['birthdate']),
      if (profile['location'] != null)
        _InfoItem(
            icon: Icons.location_on_rounded,
            label: 'Location',
            value: profile['location']),
      if (profile['address'] != null)
        _InfoItem(
            icon: Icons.home_rounded,
            label: 'Address',
            value: profile['address']),
    ];

    if (infoItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              ...infoItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: Primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9494AA),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4)),
                        const SizedBox(height: 2),
                        Text(item.value,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1A1A2E),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ]),
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Action cards ─────────────────────────────────────────────────────────
  Widget _buildActionCards(BuildContext context, AuthProvider authProvider,
      ProfileProvider profileProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: [
            _buildActionTile(
              icon: Icons.edit_rounded,
              iconBg: const Color(0xFFEBF2FF),
              iconColor: const Color(0xFF4F8EF7),
              title: 'Edit Profile',
              subtitle: 'Update your personal information',
              isFirst: true,
              onTap: () => _navigateToEditProfile(context, profileProvider),
            ),
            const Divider(height: 1, indent: 72, color: Color(0xFFF0F0F8)),
            _buildActionTile(
              icon: Icons.lock_rounded,
              iconBg: const Color(0xFFFFF1E8),
              iconColor: const Color(0xFFFF8C42),
              title: 'Change Password',
              subtitle: 'Update your account password',
              isLast: true,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage())),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // Logout button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFFFE0E0), width: 1.5),
              backgroundColor: const Color(0xFFFFF5F5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: authProvider.isLoading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFFEF4444)),
            )
                : const Icon(Icons.logout_rounded, size: 20),
            label: Text(
              authProvider.isLoading ? 'Signing out…' : 'Sign Out',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.2),
            ),
            onPressed: authProvider.isLoading
                ? null
                : () => _handleLogout(context, authProvider, profileProvider),
          ),
        ),
      ]),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9494AA),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 22, color: Color(0xFFCCCCDD)),
        ]),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  void _navigateToEditProfile(
      BuildContext context, ProfileProvider profileProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    ).then((_) {
      profileProvider.getUserProfile();
      profileProvider.getDashboardData();
    });
  }

  void _handleLogout(BuildContext context, AuthProvider authProvider,
      ProfileProvider profileProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
          SizedBox(width: 8),
          Text('Sign Out',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        content: const Text(
          "Are you sure you want to sign out?\nYou'll need to log in again.",
          style: TextStyle(color: Color(0xFF5A5A7A), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF9494AA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      context.read<CampaignProvider>().clearCampaigns();
      context.read<AnnouncementProvider>().resetAnnouncements();

      await authProvider.logout(context);
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  ImageProvider? _getProfileImage(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final raw = profile['profileImage']?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return null;

    if (raw.startsWith('data:image')) {
      try {
        final b64 = raw.split(',').last.replaceAll(RegExp(r'\s+'), '');
        return MemoryImage(base64Decode(b64));
      } catch (e) {
        debugPrint('Base64 decode failed: $e');
        return null;
      }
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return NetworkImage(raw);
    }
    return null;
  }
}

// ── Private helper widgets ───────────────────────────────────────────────────

class _CollapsedProfileTitle extends StatelessWidget {
  final dynamic user;
  final Map<String, dynamic>? profile;
  final ImageProvider? Function(Map<String, dynamic>?) getProfileImage;

  const _CollapsedProfileTitle({
    required this.user,
    required this.profile,
    required this.getProfileImage,
  });

  @override
  Widget build(BuildContext context) {
    final img = getProfileImage(profile);
    final name = profile?['name'] ?? user?.username ?? '';
    final initial =
    name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Row(children: [
      CircleAvatar(
        radius: 17,
        backgroundColor: Colors.white.withOpacity(0.25),
        backgroundImage: img,
        child: img == null
            ? Text(initial,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white))
            : null,
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ]);
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _AppBarIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ContactChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 13),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem(
      {required this.icon, required this.label, required this.value});
}