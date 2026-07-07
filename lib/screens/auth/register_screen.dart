import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Premium registration screen
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
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
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Header
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGreen.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Join TrailMate and navigate with friends',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: glassCardDecoration(opacity: 0.06),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'John Doe',
                              prefixIcon: Icon(Icons.person_outline, color: AppTheme.textTertiary),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              if (value.trim().length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textTertiary),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'At least 6 characters',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textTertiary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppTheme.textTertiary,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              hintText: 'Re-enter password',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textTertiary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                  color: AppTheme.textTertiary,
                                ),
                                onPressed: () {
                                  setState(() => _obscureConfirm = !_obscureConfirm);
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleRegister(),
                          ),
                          const SizedBox(height: 28),

                          // Error message
                          Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              if (auth.errorMessage != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentRed.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.accentRed.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            auth.errorMessage!,
                                            style: const TextStyle(color: AppTheme.accentRed, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          // Register button
                          Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              return SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: Container(
                                  decoration: accentButtonDecoration(),
                                  child: ElevatedButton(
                                    onPressed: auth.isLoading ? null : _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Create Account',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Login link
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        context.read<AuthProvider>().clearError();
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: AppTheme.accentBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
