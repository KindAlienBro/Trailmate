import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/theme_provider.dart';
class ThemeSwitcherSheet extends StatelessWidget {
  ThemeSwitcherSheet({super.key});

  static void show(BuildContext context) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ThemeSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      decoration: BoxDecoration(
        color: colors.primaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 24),
          ...AppThemeMode.values.map((mode) {
            final isSelected = themeProvider.currentMode == mode;
            final themeScheme = AppColorScheme.fromMode(mode);
            return _buildThemeCard(
              context,
              mode: mode,
              scheme: themeScheme,
              isSelected: isSelected,
              onTap: () {
                themeProvider.setTheme(mode);
              },
            );
          }),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context, {
    required AppThemeMode mode,
    required AppColorScheme scheme,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? scheme.accentPrimary : scheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.accentPrimary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.borderColor),
              ),
              child: Center(
                child: Text(
                  scheme.emoji,
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scheme.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    scheme.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: scheme.swatchColors.map((c) {
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.brightness == Brightness.dark
                                ? Colors.white24
                                : Colors.black12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: scheme.accentPrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: scheme.textOnAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
