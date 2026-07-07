import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

/// Join Group Screen — Enter a 6-character invite code to join a trip.
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final groupProvider = context.read<GroupProvider>();
    groupProvider.setToken(context.read<AuthProvider>().token);

    final group = await groupProvider.joinGroup(code);

    if (group != null && mounted) {
      Navigator.of(context).pushReplacementNamed('/group-lobby', arguments: group.id);
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
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                    ),
                    const Expanded(
                      child: Text(
                        'Join Trip',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accentPurple, AppTheme.accentBlue],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentPurple.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.qr_code_rounded, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Enter Invite Code',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ask your trip leader for the 6-character code',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 40),

                      // Code input
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: glassCardDecoration(opacity: 0.06),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _codeController,
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 6,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 12,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '------',
                                hintStyle: TextStyle(
                                  color: AppTheme.textTertiary.withValues(alpha: 0.4),
                                  fontSize: 28,
                                  letterSpacing: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppTheme.borderDark, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppTheme.accentPurple, width: 2),
                                ),
                              ),
                              onFieldSubmitted: (_) => _handleJoin(),
                            ),
                            const SizedBox(height: 24),

                            // Error
                            Consumer<GroupProvider>(
                              builder: (context, gp, _) {
                                if (gp.errorMessage != null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentRed.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(gp.errorMessage!, style: const TextStyle(color: AppTheme.accentRed, fontSize: 13)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),

                            // Join button
                            Consumer<GroupProvider>(
                              builder: (context, gp, _) {
                                return SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppTheme.accentPurple, AppTheme.accentBlue],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accentPurple.withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: gp.isLoading ? null : _handleJoin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: gp.isLoading
                                          ? const SizedBox(
                                              width: 22, height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Join Trip',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
      ),
    );
  }
}
