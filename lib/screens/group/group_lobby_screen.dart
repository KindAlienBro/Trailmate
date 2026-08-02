import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../core/app_colors.dart';
import '../../core/theme.dart';
import '../../utils/polyline_decoder.dart';

class GroupLobbyScreen extends StatefulWidget {
  final String groupId;

  const GroupLobbyScreen({super.key, required this.groupId});

  @override
  State<GroupLobbyScreen> createState() => _GroupLobbyScreenState();
}

class _GroupLobbyScreenState extends State<GroupLobbyScreen> {
  bool _isRefreshing = false;
  final MapController _mapController = MapController();

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
      SnackBar(
        content: const Text('Invite code copied!'),
        backgroundColor: AppColors.of(context).accentPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareInviteCode(String code, String groupName) {
    Share.share('Join my group "$groupName" on RoUniity! Use invite code: $code');
  }

  void _startTrip(GroupModel group) async {
    final navProvider = context.read<NavigationProvider>();
    final authProvider = context.read<AuthProvider>();

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
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      body: Consumer2<GroupProvider, AuthProvider>(
        builder: (context, groupProvider, authProvider, _) {
          final group = groupProvider.currentGroup;
          
          if (group == null || group.id != widget.groupId) {
            return Center(child: CircularProgressIndicator(color: colors.accentPrimary));
          }

          final isLeader = group.isLeader(authProvider.currentUser!.id);

          return Stack(
            children: [
              // MAP BACKGROUND
              Positioned.fill(
                bottom: MediaQuery.of(context).size.height * 0.4,
                child: _buildMapPreview(group, colors),
              ),

              // HEADER
              Positioned(
                top: 0, left: 0, right: 0,
                child: _buildHeader(group, colors, theme),
              ),

              // DRAGGABLE BOTTOM SHEET LOBBY
              _buildDraggableLobby(group, isLeader, colors, theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapPreview(GroupModel group, AppColorScheme colors) {
    LatLng? origin;
    LatLng? dest;
    List<LatLng> polyline = [];
    
    if (group.route.hasRoute) {
      if (group.route.origin.hasLocation) {
        origin = LatLng(group.route.origin.lat!, group.route.origin.lng!);
      }
      if (group.route.destination.hasLocation) {
        dest = LatLng(group.route.destination.lat!, group.route.destination.lng!);
      }
      if (group.route.polyline != null) {
        polyline = decodePolyline(group.route.polyline!);
      }
    }

    final bounds = (origin != null && dest != null) ? LatLngBounds.fromPoints([origin, dest, ...polyline]) : null;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: origin ?? const LatLng(0, 0),
        initialZoom: 12,
        initialCameraFit: bounds != null ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)) : null,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.trialmate',
        ),
        if (polyline.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(points: polyline, color: colors.accentPrimary, strokeWidth: 5.0),
            ],
          ),
        MarkerLayer(
          markers: [
            if (origin != null)
              Marker(point: origin, width: 40, height: 40, child: Icon(Icons.location_on, color: colors.accentSecondary, size: 40)),
            if (dest != null)
              Marker(point: dest, width: 40, height: 40, child: Icon(Icons.location_on, color: colors.accentDanger, size: 40)),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(GroupModel group, AppColorScheme colors, ThemeData theme) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.primaryBackground.withValues(alpha: 0.8), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: colors.surfaceColor.withValues(alpha: 0.8), shape: BoxShape.circle),
                  child: Icon(Icons.arrow_back_rounded, color: colors.textPrimary, size: 20),
                ),
              ),
              Expanded(
                child: Text(
                  group.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 56),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableLobby(GroupModel group, bool isLeader, AppColorScheme colors, ThemeData theme) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: colors.primaryBackground.withValues(alpha: 0.85),
                border: Border(top: BorderSide(color: colors.borderColor.withValues(alpha: 0.5))),
              ),
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _loadGroup,
                    color: colors.accentPrimary,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40, height: 5,
                              decoration: BoxDecoration(
                                color: colors.textTertiary.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildInviteCodeCard(group, colors, theme),
                          const SizedBox(height: 32),
                          _buildRouteDetails(group, isLeader, colors, theme),
                          const SizedBox(height: 32),
                          _buildMembersList(group, colors, theme),
                        ],
                      ),
                    ),
                  ),
                  
                  // Start Button fixed at bottom
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [colors.primaryBackground, colors.primaryBackground.withValues(alpha: 0.0)],
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity, height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: colors.accentGradient,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [BoxShadow(color: colors.accentPrimary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 5))],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: (!isLeader && group.status != 'active') ? null : () => _startTrip(group),
                            icon: Icon(isLeader ? Icons.navigation_rounded : Icons.login_rounded, color: Colors.white),
                            label: Text(
                              isLeader ? 'Start Trip' : 'Join Navigation',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInviteCodeCard(GroupModel group, AppColorScheme colors, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        children: [
          Text('Invite Code', style: theme.textTheme.titleSmall?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 12),
          Text(
            group.inviteCode,
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 8, color: colors.textPrimary),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(Icons.copy_rounded, 'Copy', colors.accentPrimary, () => _copyInviteCode(group.inviteCode), colors),
              const SizedBox(width: 16),
              _buildActionButton(Icons.share_rounded, 'Share', colors.accentExtra, () => _shareInviteCode(group.inviteCode, group.name), colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap, AppColorScheme colors) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  Widget _buildRouteDetails(GroupModel group, bool isLeader, AppColorScheme colors, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Route', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
            if (isLeader)
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Route editing coming soon!'), backgroundColor: colors.accentPrimary));
                },
                icon: Icon(Icons.edit_location_alt_outlined, size: 18, color: colors.accentPrimary),
                label: Text(group.route.hasRoute ? 'Edit' : 'Add Route', style: TextStyle(color: colors.accentPrimary)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surfaceColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.borderColor),
          ),
          child: group.route.hasRoute ? Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: colors.accentPrimary.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(Icons.my_location_rounded, color: colors.accentPrimary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(group.route.origin.name.isNotEmpty ? group.route.origin.name : group.route.origin.address, style: theme.textTheme.bodyLarge?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 17, top: 4, bottom: 4),
                child: Align(alignment: Alignment.centerLeft, child: Container(width: 2, height: 24, color: colors.borderColor)),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: colors.accentSecondary.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(Icons.location_on_rounded, color: colors.accentSecondary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(group.route.destination.name.isNotEmpty ? group.route.destination.name : group.route.destination.address, style: theme.textTheme.bodyLarge?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(Icons.route_outlined, group.route.distanceText, colors, theme),
                  _buildStat(Icons.access_time_rounded, group.route.durationText, colors, theme),
                  _buildStat(Icons.place_outlined, '${group.route.waypoints.length} stops', colors, theme),
                ],
              ),
            ],
          ) : Center(child: Text('No route planned yet.', style: TextStyle(color: colors.textSecondary))),
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String text, AppColorScheme colors, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, size: 24, color: colors.textSecondary),
        const SizedBox(height: 8),
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMembersList(GroupModel group, AppColorScheme colors, ThemeData theme) {
    final myId = context.read<AuthProvider>().currentUser?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Members', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: colors.surfaceColor, borderRadius: BorderRadius.circular(12)),
              child: Text('${group.members.length}', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: group.members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final member = group.members[index];
            final isMe = member.userId == myId;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isMe ? colors.accentPrimary.withValues(alpha: 0.3) : Colors.transparent),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: member.isLeader ? colors.accentExtra.withValues(alpha: 0.2) : colors.cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: member.isLeader ? colors.accentExtra : colors.textPrimary))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(member.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: colors.accentPrimary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                child: Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.accentPrimary)),
                              ),
                            ]
                          ],
                        ),
                        if (member.isLeader) ...[
                          const SizedBox(height: 4),
                          Text('Trip Leader', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.accentExtra)),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: colors.accentSecondary.withValues(alpha: 0.8), size: 24),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
