import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'item_detail_screen.dart';
import 'login_screen.dart';
import 'nearby_restaurants_map_screen.dart';
import 'profile_screen.dart';
import 'restaurant_detail_screen.dart';
import 'special_list_screen.dart';
import 'user_orders_screen.dart';

class UserRestaurantsScreen extends StatefulWidget {
  const UserRestaurantsScreen({super.key});

  @override
  State<UserRestaurantsScreen> createState() => _UserRestaurantsScreenState();
}

class _UserRestaurantsScreenState extends State<UserRestaurantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  static String getRestaurantFallbackImage(String restaurantName, [String docId = '']) {
    final nameLower = restaurantName.toLowerCase().trim();
    if (nameLower.contains('coffee') || nameLower.contains('cafe') || nameLower.contains('tea')) {
      return 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('burger') || nameLower.contains('fast') || nameLower.contains('kfc') || nameLower.contains('crispy')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('pizza') || nameLower.contains('piza') || nameLower.contains('italian')) {
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('bbq') || nameLower.contains('meat') || nameLower.contains('grill') || nameLower.contains('steak') || nameLower.contains('tikka')) {
      return 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('biryani') || nameLower.contains('rice') || nameLower.contains('karahi') || nameLower.contains('desi') || nameLower.contains('spice')) {
      return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('cake') || nameLower.contains('sweet') || nameLower.contains('baker') || nameLower.contains('dessert')) {
      return 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500&auto=format&fit=crop&q=80';
    }

    final curated = [
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1550547660-d9450f859349?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1578474846511-04ba529f0b88?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1600565193348-f74bd3c7ccdf?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=500&auto=format&fit=crop&q=80',
    ];
    final hash = (restaurantName + docId).hashCode.abs();
    return curated[hash % curated.length];
  }

  @override
  void initState() {
    super.initState();
    AuthService().deletePizzaCategoryAndItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textDark,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(color: AppColors.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  String _getEffectiveImageUrl(String url, String restaurantName, [String docId = '']) {
    String finalUrl = url.trim();
    if (finalUrl.isEmpty) {
      return getRestaurantFallbackImage(restaurantName, docId);
    } else if (!finalUrl.startsWith('http') && !finalUrl.startsWith('data:image') && finalUrl.length < 200) {
      try {
        if (!File(finalUrl).existsSync()) {
          return getRestaurantFallbackImage(restaurantName, docId);
        }
      } catch (_) {
        return getRestaurantFallbackImage(restaurantName, docId);
      }
    }
    return finalUrl;
  }

  Widget _buildRestaurantImage(
    String url, {
    required String restaurantName,
    String docId = '',
    required double width,
    required double height,
    required double borderRadius,
  }) {
    final finalUrl = _getEffectiveImageUrl(url, restaurantName, docId);

    return AppNetworkImage(
      imageUrl: finalUrl,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fit: BoxFit.cover,
      fallbackIcon: Icons.storefront_rounded,
    );
  }

  Widget _buildDishImage(String url) {
    return AppNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: double.infinity,
      borderRadius: 0,
      fit: BoxFit.cover,
      fallbackIcon: Icons.restaurant_rounded,
    );
  }

  Widget _buildDishesDiscountSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Map items
        final List<Map<String, dynamic>> allDishes = docs.map((doc) {
          final data = doc.data();
          final rawItemPrice = (data['item_price'] as num?)?.toDouble() ?? 0.0;
          final discPercent =
              (data['discount_percent'] as num?)?.toDouble() ?? 0.0;
          final rawOrigPrice = (data['original_price'] as num?)?.toDouble() ?? rawItemPrice;

          double origPrice;
          double itemPrice;

          if (discPercent > 0) {
            if (rawOrigPrice > rawItemPrice && rawItemPrice > 0) {
              origPrice = rawOrigPrice;
              itemPrice = rawItemPrice;
            } else {
              origPrice = rawOrigPrice > 0 ? rawOrigPrice : rawItemPrice;
              itemPrice = origPrice * (1.0 - (discPercent / 100.0));
            }
          } else {
            origPrice = rawOrigPrice > 0 ? rawOrigPrice : rawItemPrice;
            itemPrice = rawItemPrice;
          }

          return {
            'item_id': doc.id,
            'item_name': (data['item_name'] ?? data['prod_name'] ?? '').toString(),
            'item_price': itemPrice,
            'original_price': origPrice,
            'discount_percent': discPercent,
            'has_discount': discPercent > 0 || data['has_discount'] == true,
            'item_pic': (data['item_pic'] ?? data['prod_pic'] ?? '').toString(),
            'item_description':
                (data['item_description'] ?? data['prod_desc'] ?? '').toString(),
            'category_id': (data['category_id'] ?? data['cat_id'] ?? '').toString(),
            'category_name':
                (data['category_name'] ?? data['cat_name'] ?? '').toString(),
            'restaurant_id':
                (data['restaurant_id'] ?? data['rest_id'] ?? '').toString(),
            'restaurant_name':
                (data['restaurant_name'] ?? data['rest_name'] ?? '').toString(),
            'rating': (data['rating'] as num?)?.toDouble() ?? 4.6,
          };
        }).where((item) => (item['item_name'] as String).isNotEmpty).toList();

        if (allDishes.isEmpty) {
          return const SizedBox.shrink();
        }

        // Prioritize discounted dishes, but fallback to all dishes so the section always shines
        final discountedDishes = allDishes
            .where((item) => (item['discount_percent'] as double) > 0)
            .toList();

        final List<Map<String, dynamic>> displayDishes =
            discountedDishes.isNotEmpty ? discountedDishes : allDishes;

        // Calculate max discount
        double maxDiscount = 0.0;
        for (var item in displayDishes) {
          final d = (item['discount_percent'] as num?)?.toDouble() ?? 0.0;
          if (d > maxDiscount) maxDiscount = d;
        }
        if (maxDiscount <= 0) maxDiscount = 15.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header: % Icon + "Dishes up to 15% off" + > Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Pink % Circle Badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryPink,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPink.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.percent_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dishes up to ${maxDiscount.toInt()}% off',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Minimum spend applies',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Arrow Button >
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SpecialListScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.inputBorder,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Horizontal Dish Cards Scroll
              SizedBox(
                height: 246,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayDishes.length,
                  itemBuilder: (context, index) {
                    final item = displayDishes[index];
                    final String name = item['item_name'];
                    final double price = item['item_price'];
                    final double originalPrice = item['original_price'];
                    final double discountPercent = item['discount_percent'];
                    final String pic = item['item_pic'];
                    final String restName = (item['restaurant_name'] as String).isNotEmpty
                        ? item['restaurant_name']
                        : 'Partner Kitchen';
                    final double rating = item['rating'] ?? 4.6;
                    final String deliveryTime =
                        index % 2 == 0 ? '5–20 mins' : '10–25 mins';
                    final String deliveryFee =
                        index % 3 == 0 ? 'Free' : 'Rs. 139';

                    return Container(
                      width: 158,
                      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F24),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2E313C),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ItemDetailScreen(
                                  itemId: item['item_id'],
                                  itemName: name,
                                  itemPrice: price,
                                  itemImageUrl: pic,
                                  itemDescription: item['item_description'],
                                  categoryId: item['category_id'],
                                  categoryName: item['category_name'],
                                  restaurantId: item['restaurant_id'],
                                  restaurantName: restName,
                                  initialData: item,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Food Image with Delivery Time Badge
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 104,
                                        child: _buildDishImage(pic),
                                      ),
                                    ),
                                    // Delivery Time Pill on Top-Left
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          deliveryTime,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Restaurant Name & Rating
                                Row(
                                  children: [
                                    const Text('🍛', style: TextStyle(fontSize: 10)),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        restName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFFFA000),
                                      size: 13,
                                    ),
                                    const SizedBox(width: 1),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),

                                // Dish Name
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),

                                // Price & Discount Layout (Top: Actual Price + % off, Bottom: Discounted Price + Delivery)
                                if (discountPercent > 0) ...[
                                  Row(
                                    children: [
                                      Text(
                                        'Rs.${originalPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white38,
                                          decoration: TextDecoration.lineThrough,
                                          decorationColor: Colors.white38,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryPink.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${discountPercent.toStringAsFixed(0)}% off',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFFF5277),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                ],

                                // Discounted Price & Delivery info Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Rs.${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFF5277),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.two_wheeler_rounded,
                                          size: 12,
                                          color: Colors.white54,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          deliveryFee,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white60,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final displayName = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!
        : 'Foodie';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Greeting & Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Hello, ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '$displayName 👋',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryPink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Find and order from top restaurants',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // My Orders & Live Tracking Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const UserOrdersScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1F24),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2E313C),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primaryPink,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Profile Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1F24),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2E313C),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.primaryPink,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Nearby Restaurants Map Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const NearbyRestaurantsMapScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1F24),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryPink.withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPink
                                      .withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.map_rounded,
                              color: AppColors.primaryPink,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Logout Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _confirmLogout(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1F24),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2E313C),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: AppColors.primaryPink,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar for Restaurants
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F24),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF2E313C),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search restaurants by name or city...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF8E92A0),
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryPink,
                      size: 21,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.white60,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),

            // Main Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Promo / Special Offer Banner (Clickable to open SpecialListScreen)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1A1B20), // Deep obsidian charcoal
                            Color(0xFF2E1624), // Rich dark plum/rose
                            Color(0xFF7A152E), // Deep crimson/pink accent
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryPink.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPink.withValues(alpha: 0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SpecialListScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFFA4468),
                                                  Color(0xFFFF6584)
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primaryPink
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Text(
                                              'Special Deal 🔥',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.4),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.15),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Tap to view',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                SizedBox(width: 3),
                                                Icon(
                                                  Icons.arrow_forward_ios_rounded,
                                                  color: Color(0xFFFF6584),
                                                  size: 9,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Explore Delicious Menus',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap here to view all special deals & hot offers from all restaurants!',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.88),
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primaryPink
                                            .withValues(alpha: 0.35),
                                        Colors.black.withValues(alpha: 0.5),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primaryPink
                                          .withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryPink
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.local_fire_department_rounded,
                                      color: Color(0xFFFF6584),
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Foodpanda-style "Dishes up to 15% off" Section
                    _buildDishesDiscountSection(),

                    // Section Title: "All Restaurants"
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'All Restaurants',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Live Partners',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryPink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Real-time List of All Restaurants
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('restaurants')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryPink,
                              ),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'Error loading restaurants: ${snapshot.error}',
                                style: const TextStyle(
                                    color: AppColors.primaryPink),
                              ),
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        final restaurants = docs.map((doc) {
                          final data = doc.data();
                          return {
                            'doc_id': doc.id,
                            'restaurant_id': (data['restaurant_id'] ??
                                    data['unique_id'] ??
                                    doc.id)
                                .toString(),
                            'restaurant_name': (data['restaurant_name'] ??
                                    data['name'] ??
                                    'HeartTale Restaurant')
                                .toString(),
                            'logo_image': (data['logo_image'] ??
                                    data['logo'] ??
                                    data['photoUrl'] ??
                                    '')
                                .toString(),
                            'location': (data['location'] ??
                                    data['address'] ??
                                    'Live Location')
                                .toString(),
                            'description': (data['user_description'] ??
                                    data['description'] ??
                                    'Special Delicious Food & Refreshments')
                                .toString(),
                            'phone': (data['phone'] ?? '').toString(),
                            'email': (data['email'] ?? '').toString(),
                            'rating': (data['rating'] as num?)?.toDouble() ??
                                (data['avg_rating'] as num?)?.toDouble() ??
                                0.0,
                            'rating_count':
                                (data['rating_count'] as num?)?.toInt() ?? 0,
                          };
                        }).toList();

                        // Filter by search query
                        final filteredRestaurants = restaurants.where((r) {
                          final name = (r['restaurant_name'] ?? '')
                              .toString()
                              .toLowerCase()
                              .trim();
                          final loc = (r['location'] ?? '')
                              .toString()
                              .toLowerCase()
                              .trim();
                          final desc = (r['description'] ?? '')
                              .toString()
                              .toLowerCase()
                              .trim();
                          final q = _searchQuery.toLowerCase().trim();
                          return name.contains(q) ||
                              loc.contains(q) ||
                              desc.contains(q);
                        }).toList();

                        if (filteredRestaurants.isEmpty) {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1F24),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF2E313C),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.storefront_outlined,
                                    size: 42,
                                    color: Colors.white38,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No restaurants found matching "$_searchQuery"'
                                        : 'No restaurants registered yet',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredRestaurants.length,
                          itemBuilder: (context, index) {
                            final r = filteredRestaurants[index];
                            final String name =
                                (r['restaurant_name'] ?? '').toString();
                            final String logo =
                                (r['logo_image'] ?? '').toString();
                            final String loc = (r['location'] ?? '').toString();
                            final String desc =
                                (r['description'] ?? '').toString();
                            final String id =
                                (r['restaurant_id'] ?? '').toString();
                            final String phone =
                                (r['phone'] ?? '').toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1A1B20), // Deep obsidian charcoal
                                    Color(0xFF261822), // Dark plum/rose undertone
                                    Color(0xFF381420), // Subtle pinkish-dark glow
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.primaryPink.withValues(alpha: 0.28),
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: AppColors.primaryPink.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    final double rRating =
                                        (r['rating'] as num?)?.toDouble() ??
                                            0.0;
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => RestaurantDetailScreen(
                                          restaurantId: id,
                                          restaurantName: name,
                                          logoImage: _getEffectiveImageUrl(logo, name, id),
                                          location: loc,
                                          description: desc,
                                          phone: phone.isNotEmpty ? phone : null,
                                          rating: rRating,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(18),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Restaurant Logo
                                        _buildRestaurantImage(
                                          logo,
                                          restaurantName: name,
                                          docId: id,
                                          width: 82,
                                          height: 82,
                                          borderRadius: 14,
                                        ),
                                        const SizedBox(width: 14),

                                        // Restaurant Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 2.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.45),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              7),
                                                      border: Border.all(
                                                        color: const Color(0xFFFFA000).withValues(alpha: 0.35),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.star_rounded,
                                                          color:
                                                              Color(0xFFFFA000),
                                                          size: 13,
                                                        ),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          ((r['rating'] as num?)?.toDouble() ?? 0.0) > 0
                                                              ? ((r['rating'] as num?)!.toDouble()).toStringAsFixed(1)
                                                              : '0.0',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),

                                              // Location
                                              if (loc.isNotEmpty)
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on_rounded,
                                                      size: 13,
                                                      color: Color(0xFFFF6584),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        loc,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.white70,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              const SizedBox(height: 4),

                                              // Description / Cuisine
                                              Text(
                                                desc,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.white.withValues(alpha: 0.65),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),

                                              // "View Menu" Button Badge
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4.5),
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [
                                                          Color(0xFFFA4468),
                                                          Color(0xFFFF6584),
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppColors
                                                              .primaryPink
                                                              .withValues(
                                                                  alpha: 0.35),
                                                          blurRadius: 6,
                                                          offset: const Offset(
                                                              0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'View Menu',
                                                          style: TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        SizedBox(width: 4),
                                                        Icon(
                                                          Icons
                                                              .arrow_forward_ios_rounded,
                                                          size: 9.5,
                                                          color: Colors.white,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        icons: const [
          Icons.storefront_rounded,
          Icons.local_offer_outlined,
          Icons.receipt_long_rounded,
          Icons.person_outline_rounded,
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SpecialListScreen()),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserOrdersScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }
        },
      ),
    );
  }
}
