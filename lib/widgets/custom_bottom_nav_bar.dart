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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF16171B),
              Color(0xFF1F151F),
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: const Color(0xFFFA4468).withValues(alpha: 0.45),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFA4468).withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
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
        splashColor: AppColors.primaryPink.withValues(alpha: 0.2),
        highlightColor: AppColors.primaryPink.withValues(alpha: 0.1),
        child: SizedBox(
          height: 64,
          child: Center(
            child: isActive
                ? Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFA4468),
                          Color(0xFFFF6283),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFA4468).withValues(alpha: 0.45),
                          blurRadius: 10,
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
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 26,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
