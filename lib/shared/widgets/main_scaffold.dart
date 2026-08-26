import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.dashboard)) return 0;
    if (location.startsWith(AppRoutes.animals)) return 1;
    if (location.startsWith(AppRoutes.vehicles)) return 2;
    if (location.startsWith(AppRoutes.fields)) return 3;
    if (location.startsWith(AppRoutes.stock)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Ana Sayfa',
                  isSelected: selectedIndex == 0,
                  onTap: () => context.go(AppRoutes.dashboard),
                ),
                _NavItem(
                  icon: Icons.pets_rounded,
                  label: 'Hayvanlar',
                  isSelected: selectedIndex == 1,
                  onTap: () => context.go(AppRoutes.animals),
                ),
                _NavItem(
                  icon: Icons.agriculture_rounded,
                  label: 'Araçlar',
                  isSelected: selectedIndex == 2,
                  onTap: () => context.go(AppRoutes.vehicles),
                ),
                _NavItem(
                  icon: Icons.grass_rounded,
                  label: 'Tarlalar',
                  isSelected: selectedIndex == 3,
                  onTap: () => context.go(AppRoutes.fields),
                ),
                _NavItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Stok',
                  isSelected: selectedIndex == 4,
                  onTap: () => context.go(AppRoutes.stock),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
