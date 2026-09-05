import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../core/app_colors.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isJoining = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    
    // Auto-focus the hidden text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    if (code.length < 6) return; // Wait until fully typed

    FocusScope.of(context).unfocus();
    setState(() => _isJoining = true);

    try {
      final groupProvider = context.read<GroupProvider>();
      groupProvider.setToken(context.read<AuthProvider>().token);

      final group = await groupProvider.joinGroup(code);

      if (group != null && mounted) {
        Navigator.of(context).pushReplacementNamed('/group-lobby', arguments: group.id);
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Widget _buildSegment(String char, bool isActive, AppColorScheme colors) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isActive ? colors.surfaceColor : colors.surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? colors.accentPrimary : colors.borderColor.withValues(alpha: 0.3),
          width: isActive ? 2.5 : 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colors.accentPrimary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      alignment: Alignment.center,
      child: Text(
        char,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: isActive ? colors.accentPrimary : colors.textPrimary,
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colors.primaryBackground, // Deep background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: Stack(
        children: [
          // Dynamic gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryBackground,
                    colors.accentPrimary.withValues(alpha: 0.05),
                    colors.primaryBackground,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          
          // Subtle glowing orb top right
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accentPrimary.withValues(alpha: 0.1),
                backgroundBlendMode: BlendMode.screen,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),
          ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(36),
                          decoration: BoxDecoration(
                            color: colors.cardColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Floating Icon
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(seconds: 2),
                                curve: Curves.easeInOutSine,
                                builder: (context, val, child) {
                                  return Transform.translate(
                                    offset: Offset(0, -5.0 * math.sin(val * 3.14159 * 2)), // Float effect
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.accentPrimary.withValues(alpha: 0.1),
                                    border: Border.all(color: colors.accentPrimary.withValues(alpha: 0.3)),
                                  ),
                                  child: Icon(Icons.flight_takeoff_rounded, size: 40, color: colors.accentPrimary),
                                ),
                              ),
                              const SizedBox(height: 28),
                              
                              Text(
                                'Join a Trip',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: colors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Enter the 6-character invite code\nprovided by your trip leader.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 48),
                              
                              // Hidden TextField & Custom Segments
                              GestureDetector(
                                onTap: () => FocusScope.of(context).requestFocus(_focusNode),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // The hidden real TextField
                                    Opacity(
                                      opacity: 0,
                                      child: TextField(
                                        focusNode: _focusNode,
                                        controller: _codeController,
                                        keyboardType: TextInputType.text,
                                        textCapitalization: TextCapitalization.characters,
                                        maxLength: 6,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                                        ],
                                        onChanged: (val) {
                                          setState(() {});
                                          if (val.length == 6) {
                                            _handleJoin();
                                          }
                                        },
                                      ),
                                    ),
                                    
                                    // Visual Segmented Control
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(6, (index) {
                                        final text = _codeController.text;
                                        final char = index < text.length ? text[index].toUpperCase() : '';
                                        final isActive = index == text.length || (index == 5 && text.length == 6);
                                        return _buildSegment(char, isActive && _focusNode.hasFocus, colors);
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Error Message
                              Consumer<GroupProvider>(
                                builder: (context, gp, _) {
                                  if (gp.errorMessage != null) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 24),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEBEE).withValues(alpha: 0.9), // Light red
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFFEF9A9A)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                gp.errorMessage!,
                                                style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }
                              ),

                              // Join Button
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 56,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  gradient: LinearGradient(
                                    colors: _codeController.text.length == 6
                                        ? [colors.accentPrimary, colors.accentSecondary ?? colors.accentPrimary]
                                        : [colors.surfaceColor, colors.surfaceColor],
                                  ),
                                  boxShadow: _codeController.text.length == 6
                                      ? [
                                          BoxShadow(
                                            color: colors.accentPrimary.withValues(alpha: 0.4),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          )
                                        ]
                                      : [],
                                ),
                                child: ElevatedButton(
                                  onPressed: (_isJoining || _codeController.text.length < 6) ? null : _handleJoin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                    elevation: 0,
                                  ),
                                  child: _isJoining
                                      ? const SizedBox(
                                          width: 24, height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                        )
                                      : Text(
                                          'Join Trip',
                                          style: TextStyle(
                                            fontSize: 18, 
                                            fontWeight: FontWeight.bold, 
                                            color: _codeController.text.length == 6 ? Colors.white : colors.textTertiary,
                                            letterSpacing: 0.5
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
