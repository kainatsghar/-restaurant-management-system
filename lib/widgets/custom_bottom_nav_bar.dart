import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData>? icons;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final navIcons = icons ??
        const [
          Icons.home_rounded,
          Icons.restaurant_rounded,
          Icons.menu_book_outlined,
          Icons.person_outline_rounded,
        ];

    // Wrap in SafeArea to ensure the bottom bar is never covered by the phone's navigation bar
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: List.generate(
            navIcons.length,
            (index) => Expanded(
              child: _buildNavItem(
                index: index,
                icon: navIcons[index],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
  }) {
    final bool isActive = currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(32),
        splashColor: AppColors.primaryPink.withValues(alpha: 0.15),
        highlightColor: AppColors.primaryPink.withValues(alpha: 0.08),
        child: SizedBox(
          height: 64,
          child: Center(
            child: isActive
                ? Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPink,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPink.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  )
                : SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(
                      icon,
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                      size: 26,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
