import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_network_image.dart';

class CategoryCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String? type;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CategoryCard({
    super.key,
    required this.name,
    required this.imageUrl,
    this.type,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Image at Top
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: AppNetworkImage(
                  imageUrl: imageUrl,
                  borderRadius: 12,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.fastfood_rounded,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Category Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                letterSpacing: -0.2,
              ),
            ),

            if (type != null && type!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                type!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],

            const SizedBox(height: 6),

            // Action Buttons: Edit (Green) & Delete (Pink)
            Row(
              children: [
                // Edit button
                Expanded(
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.editGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Delete button
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.deleteBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.deleteIcon,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
