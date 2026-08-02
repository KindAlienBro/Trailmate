import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/theme_switcher_sheet.dart';
import '../../core/app_colors.dart';
import '../../core/theme.dart';

/// Ultra-Premium Home Dashboard
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _enterController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  
  late PageController _carouselController;
  int _currentCarouselIndex = 0;

  int _tokensUsed = 0;
  int _tokenLimit = 10000;
  bool _isLoadingTokens = true;

  @override
  void initState() {
    super.initState();
    
    _enterController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );

    _carouselController = PageController(viewportFraction: 0.85);

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
      
      _enterController.forward();
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
      if (mounted) setState(() => _isLoadingTokens = false);
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return Scaffold(
      backgroundColor: colors.primaryBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient Base
          Container(
            decoration: BoxDecoration(gradient: colors.primaryGradient),
          ),
          
          // Organic Blurry Orbs
          Positioned(
            top: -150,
            right: -50,
            child: _buildBlurOrb(colors.accentPrimary, 400),
          ),
          
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(colors),
                    const SizedBox(height: 24),
                    _buildActionCarousel(colors),
                    const SizedBox(height: 32),
                    Expanded(child: _buildTripsList(colors)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildHeader(AppColorScheme colors) {
    final theme = Theme.of(context);
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final name = auth.currentUser?.name ?? 'Traveler';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Premium Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: colors.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentPrimary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Greeting Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to explore,',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Actions (Theme / Logout)
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.borderColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.settings_outlined, color: colors.textPrimary, size: 20),
                      onPressed: () => ThemeSwitcherSheet.show(context),
                    ),
                    IconButton(
                      icon: Icon(Icons.logout_rounded, color: colors.textPrimary, size: 20),
                      onPressed: () async {
                        await auth.logout();
                        if (mounted) {
                          Navigator.of(context).pushReplacementNamed('/login');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCarousel(AppColorScheme colors) {
    return SizedBox(
      height: 200,
      child: PageView(
        controller: _carouselController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentCarouselIndex = index);
        },
        children: [
          _buildCarouselCard(
            colors: colors,
            title: 'Start a Trip',
            subtitle: 'Create a new group and invite friends',
            icon: Icons.add_circle_outline,
            gradient: colors.accentGradient,
            shadowColor: colors.accentPrimary,
            onTap: () => Navigator.of(context).pushNamed('/create-group'),
            index: 0,
          ),
          _buildCarouselCard(
            colors: colors,
            title: 'Join a Trip',
            subtitle: 'Enter an invite code to sync up',
            icon: Icons.group_add_outlined,
            gradient: colors.dangerGradient,
            shadowColor: colors.accentDanger,
            onTap: () => Navigator.of(context).pushNamed('/join-group'),
            index: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselCard({
    required AppColorScheme colors,
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required Color shadowColor,
    required VoidCallback onTap,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isSelected = _currentCarouselIndex == index;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(
        right: 16,
        top: isSelected ? 0 : 20,
        bottom: isSelected ? 0 : 20,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: isSelected ? 0.4 : 0.0),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripsList(AppColorScheme colors) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceColor.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        border: Border(
          top: BorderSide(color: colors.borderColor.withValues(alpha: 0.5)),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                child: Text(
                  'My Active Trips',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Consumer<GroupProvider>(
                  builder: (context, groupProvider, _) {
                    if (groupProvider.isLoading) {
                      return Center(
                        child: CircularProgressIndicator(color: colors.accentPrimary),
                      );
                    }

                    if (groupProvider.myGroups.isEmpty) {
                      return _buildEmptyState(colors, theme);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      physics: const BouncingScrollPhysics(),
                      itemCount: groupProvider.myGroups.length,
                      itemBuilder: (context, index) {
                        return _buildGroupTile(groupProvider.myGroups[index], colors, theme);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorScheme colors, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.6, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              'assets/illustrations/no_trips.png',
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Active Trips',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Swipe through the carousel above to start a new adventure!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildGroupTile(GroupModel group, AppColorScheme colors, ThemeData theme) {
    final statusColor = switch (group.status) {
      'active' => colors.accentSecondary,
      'planning' => colors.accentWarning,
      'completed' => colors.textTertiary,
      _ => colors.textTertiary,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            context.read<GroupProvider>().setCurrentGroup(group);
            Navigator.of(context).pushNamed('/group-lobby', arguments: group.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Status Icon with Soft Glow
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.navigation_rounded,
                      color: statusColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.people_alt_rounded, size: 14, color: colors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            '${group.members.length} Explorers',
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                          ),
                          const Spacer(),
                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              group.status.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
