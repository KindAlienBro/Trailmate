import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../core/app_colors.dart';
import '../../core/theme.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _codeFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();

    final groupProvider = context.read<GroupProvider>();
    groupProvider.setToken(context.read<AuthProvider>().token);

    final group = await groupProvider.joinGroup(code);

    if (group != null && mounted) {
      Navigator.of(context).pushReplacementNamed('/group-lobby', arguments: group.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isFocused = _codeFocus.hasFocus;

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient Base
          Container(decoration: BoxDecoration(gradient: colors.primaryGradient)),
          
          // Organic Blurry Orbs
          Positioned(
            top: -100, right: -50,
            child: _buildBlurOrb(colors.accentExtra, 350),
          ),
          Positioned(
            bottom: -50, left: -100,
            child: _buildBlurOrb(colors.accentPrimary, 400),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
                      ),
                      Expanded(
                        child: Text(
                          'Join Trip',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                    child: Column(
                      children: [
                        // Hero Icon
                        Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            color: colors.accentExtra.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.qr_code_rounded, size: 40, color: colors.accentExtra),
                        ),
                        const SizedBox(height: 32),
                        
                        Text(
                          'Enter Invite Code',
                          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ask your trip leader for the 6-character code',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
                        ),
                        const SizedBox(height: 56),

                        // Input Container
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: colors.surfaceColor.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: colors.borderColor.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 5),
                            ],
                          ),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: isFocused ? [
                                    BoxShadow(color: colors.accentExtra.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)
                                  ] : [],
                                ),
                                child: TextFormField(
                                  controller: _codeController,
                                  focusNode: _codeFocus,
                                  textAlign: TextAlign.center,
                                  textCapitalization: TextCapitalization.characters,
                                  maxLength: 6,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 16,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: '------',
                                    hintStyle: theme.textTheme.headlineMedium?.copyWith(
                                      color: colors.textTertiary.withValues(alpha: 0.4),
                                      letterSpacing: 16,
                                    ),
                                    filled: true,
                                    fillColor: colors.surfaceColor.withValues(alpha: isFocused ? 0.8 : 0.4),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide(color: colors.borderColor.withValues(alpha: 0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide(color: colors.borderColor.withValues(alpha: 0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide(color: colors.accentExtra, width: 2),
                                    ),
                                  ),
                                  onFieldSubmitted: (_) => _handleJoin(),
                                ),
                              ),
                              const SizedBox(height: 24),

                              Consumer<GroupProvider>(
                                builder: (context, gp, _) {
                                  if (gp.errorMessage != null) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 24),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: colors.accentDanger.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: colors.accentDanger.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline, color: colors.accentDanger, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(gp.errorMessage!, style: TextStyle(color: colors.accentDanger, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),

                              Consumer<GroupProvider>(
                                builder: (context, gp, _) {
                                  return SizedBox(
                                    width: double.infinity, height: 60,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [colors.accentExtra, colors.accentPrimary]),
                                        borderRadius: BorderRadius.circular(32),
                                        boxShadow: [
                                          BoxShadow(color: colors.accentExtra.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 5)),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: gp.isLoading ? null : _handleJoin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                        ),
                                        child: gp.isLoading
                                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                                            : Text(
                                                'Join Trip',
                                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurOrb(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
