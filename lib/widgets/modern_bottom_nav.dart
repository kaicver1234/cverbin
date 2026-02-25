import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

/// Ultra Modern bottom navigation bar - Performance optimized (No heavy animations)
class ModernBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<ModernNavItem> items;

  const ModernBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    
    return Container(
      margin: EdgeInsets.fromLTRB(
        responsive.horizontalPadding,
        0,
        responsive.horizontalPadding,
        responsive.horizontalPadding,
      ),
      height: responsive.bottomNavHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildNavItem(
              context: context,
              item: items[i],
              isActive: currentIndex == i,
              onTap: () => onTap(i),
            ),
            if (i < items.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required ModernNavItem item,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final responsive = ResponsiveHelper(context);
    final btnSize = responsive.bottomNavButtonSize;
    final iconSize = responsive.scale(24).clamp(18.0, 30.0);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: btnSize + 8,
          height: responsive.bottomNavHeight,
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            alignment: isActive ? Alignment.topCenter : Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: btnSize,
              height: btnSize,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.22),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive
                    ? Colors.black.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.6),
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModernNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const ModernNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}
