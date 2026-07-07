import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/navigation_provider.dart';

class GroupLobbyScreen extends StatefulWidget {
  final String groupId;

  const GroupLobbyScreen({super.key, required this.groupId});

  @override
  State<GroupLobbyScreen> createState() => _GroupLobbyScreenState();
}

class _GroupLobbyScreenState extends State<GroupLobbyScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroup();
    });
  }

  Future<void> _loadGroup() async {
    setState(() => _isRefreshing = true);
    await context.read<GroupProvider>().fetchGroup(widget.groupId);
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareInviteCode(String code, String groupName) {
    Share.share(
      'Join my group "$groupName" on TrailMate! Use invite code: $code',
    );
  }

  void _startTrip(GroupModel group) async {
    final navProvider = context.read<NavigationProvider>();
    final authProvider = context.read<AuthProvider>();

    // Leader sets status to active
    if (group.isLeader(authProvider.currentUser!.id)) {
      await context.read<GroupProvider>().updateStatus(group.id, 'active');
      navProvider.wsService.startTrip(group.id);
    }
    
    if (mounted) {
      await navProvider.startNavigation(group);
      Navigator.of(context).pushReplacementNamed('/live-navigation', arguments: group.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: Consumer2<GroupProvider, AuthProvider>(
            builder: (context, groupProvider, authProvider, _) {
              final group = groupProvider.currentGroup;
              
              if (group == null || group.id != widget.groupId) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlue),
                );
              }

              final isLeader = group.isLeader(authProvider.currentUser!.id);

              return RefreshIndicator(
                onRefresh: _loadGroup,
                color: AppTheme.accentBlue,
                backgroundColor: AppTheme.surfaceDark,
                child: CustomScrollView(
                  slivers: [
                    // App bar
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      pinned: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      title: Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      centerTitle: true,
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Invite Code Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: glassCardDecoration(opacity: 0.08),
                              child: Column(
                                children: [
                                  const Text(
                                    'Invite Code',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    group.inviteCode,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 8,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _copyInviteCode(group.inviteCode),
                                        icon: const Icon(Icons.copy_rounded, size: 18),
                                        label: const Text('Copy'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.accentBlue,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      TextButton.icon(
                                        onPressed: () => _shareInviteCode(group.inviteCode, group.name),
                                        icon: const Icon(Icons.share_rounded, size: 18),
                                        label: const Text('Share'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.accentPurple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Route Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Route',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (isLeader)
                                  TextButton.icon(
                                    onPressed: () {
                                      // TODO: Navigate to route planner
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Route planning coming next!')),
                                      );
                                    },
                                    icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                                    label: Text(group.route.hasRoute ? 'Edit' : 'Add Route'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.accentBlue,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: glassCardDecoration(opacity: 0.04),
                              child: group.route.hasRoute
                                  ? Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.my_location_rounded, color: AppTheme.accentBlue, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                group.route.origin.name.isNotEmpty
                                                    ? group.route.origin.name
                                                    : group.route.origin.address,
                                                style: const TextStyle(color: AppTheme.textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 9, top: 4, bottom: 4),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              width: 2,
                                              height: 16,
                                              color: AppTheme.borderDark,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_rounded, color: AppTheme.accentGreen, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                group.route.destination.name.isNotEmpty
                                                    ? group.route.destination.name
                                                    : group.route.destination.address,
                                                style: const TextStyle(color: AppTheme.textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildRouteStat(
                                              Icons.route_outlined,
                                              group.route.distanceText,
                                            ),
                                            _buildRouteStat(
                                              Icons.access_time_rounded,
                                              group.route.durationText,
                                            ),
                                            _buildRouteStat(
                                              Icons.place_outlined,
                                              '${group.route.waypoints.length} stops',
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: [
                                            Icon(Icons.map_outlined, size: 32, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'No route planned yet',
                                              style: TextStyle(color: AppTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 32),

                            // Members Section
                            Row(
                              children: [
                                const Text(
                                  'Members',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceDark,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${group.members.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: group.members.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final member = group.members[index];
                                final isMe = member.userId == authProvider.currentUser?.id;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceDark.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isMe ? AppTheme.accentBlue.withValues(alpha: 0.3) : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: member.isLeader
                                              ? AppTheme.accentPurple.withValues(alpha: 0.2)
                                              : AppTheme.cardDark,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: member.isLeader ? AppTheme.accentPurple : AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  member.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.accentBlue.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'You',
                                                      style: TextStyle(fontSize: 10, color: AppTheme.accentBlue),
                                                    ),
                                                  ),
                                                ]
                                              ],
                                            ),
                                            if (member.isLeader) ...[
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Trip Leader',
                                                style: TextStyle(fontSize: 12, color: AppTheme.accentPurple),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Status icon (green check for ready)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: AppTheme.accentGreen.withValues(alpha: 0.8),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 100), // padding for bottom button
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Consumer2<GroupProvider, AuthProvider>(
        builder: (context, gp, ap, _) {
          final group = gp.currentGroup;
          if (group == null || group.id != widget.groupId) return const SizedBox.shrink();

          final isLeader = group.isLeader(ap.currentUser!.id);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: Container(
                decoration: accentButtonDecoration(),
                child: ElevatedButton.icon(
                  onPressed: (!isLeader && group.status != 'active')
                      ? null
                      : () => _startTrip(group),
                  icon: Icon(
                    isLeader ? Icons.navigation_rounded : Icons.login_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    isLeader ? 'Start Trip' : 'Join Navigation',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRouteStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
