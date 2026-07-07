import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

import '../../providers/navigation_provider.dart';

/// Home screen — Dashboard showing groups, create/join actions.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _tokensUsed = 0;
  int _tokenLimit = 10000;
  bool _isLoadingTokens = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final groupProvider = context.read<GroupProvider>();
      final navProvider = context.read<NavigationProvider>();
      
      groupProvider.setToken(auth.token);
      groupProvider.fetchMyGroups();
      
      if (auth.token != null && auth.currentUser != null) {
        navProvider.initialize(auth.token!, auth.currentUser!.id, auth.currentUser!.name);
        _fetchApiUsage(navProvider);
      }
    });
  }

  Future<void> _fetchApiUsage(NavigationProvider nav) async {
    try {
      final usage = await nav.olaMapsService.getApiUsage();
      if (mounted) {
        setState(() {
          _tokensUsed = usage['used'] ?? 0;
          _tokenLimit = usage['limit'] ?? 10000;
          _isLoadingTokens = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTokens = false);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _animController,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    (auth.currentUser?.name ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey, ${auth.currentUser?.name ?? 'Traveler'}! 👋',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _isLoadingTokens
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGreen),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '🎯 $_tokensUsed / $_tokenLimit Tokens',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentGreen,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              // Logout button
              IconButton(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: AppTheme.textTertiary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action cards
          Row(
            children: [
              Expanded(child: _buildActionCard(
                icon: Icons.add_circle_outline,
                title: 'Create Trip',
                subtitle: 'Start a group',
                gradient: AppTheme.accentGradient,
                onTap: () => Navigator.of(context).pushNamed('/create-group'),
              )),
              const SizedBox(width: 14),
              Expanded(child: _buildActionCard(
                icon: Icons.group_add_outlined,
                title: 'Join Trip',
                subtitle: 'Enter code',
                gradient: const LinearGradient(
                  colors: [AppTheme.accentPurple, AppTheme.accentBlue],
                ),
                onTap: () => Navigator.of(context).pushNamed('/join-group'),
              )),
            ],
          ),
          const SizedBox(height: 32),

          // My Groups
          const Text(
            'My Trips',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _buildGroupsList(),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList() {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, _) {
        if (groupProvider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppTheme.accentBlue),
            ),
          );
        }

        if (groupProvider.myGroups.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: glassCardDecoration(opacity: 0.04),
            child: Column(
              children: [
                Icon(
                  Icons.explore_outlined,
                  size: 56,
                  color: AppTheme.textTertiary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No trips yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create a trip or join one with an invite code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: groupProvider.myGroups.map((group) {
            return _buildGroupTile(group);
          }).toList(),
        );
      },
    );
  }

  Widget _buildGroupTile(GroupModel group) {
    final statusColor = switch (group.status) {
      'active' => AppTheme.accentGreen,
      'planning' => AppTheme.accentOrange,
      'completed' => AppTheme.textTertiary,
      _ => AppTheme.textTertiary,
    };

    return GestureDetector(
      onTap: () {
        context.read<GroupProvider>().setCurrentGroup(group);
        Navigator.of(context).pushNamed('/group-lobby', arguments: group.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: glassCardDecoration(opacity: 0.06),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.navigation_rounded,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${group.members.length} members',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          group.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
