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

  Widget _buildRestaurantImage(
    String url, {
    required double width,
    required double height,
    required double borderRadius,
  }) {
    return AppNetworkImage(
      imageUrl: url,
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
                      width: 156,
                      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
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
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(6),
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
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Colors.amber,
                                      size: 13,
                                    ),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
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
                                    color: AppColors.textDark,
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
                                          color: AppColors.textMuted,
                                          decoration: TextDecoration.lineThrough,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryPink.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${discountPercent.toStringAsFixed(0)}% off',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primaryPink,
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
                                        color: AppColors.primaryPink,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.two_wheeler_rounded,
                                          size: 12,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          deliveryFee,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.inputBorder,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.inputBorder,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
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
                              color: AppColors.primaryPink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryPink.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPink
                                      .withValues(alpha: 0.08),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.inputBorder,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.inputBorder,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
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
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search restaurants by name or city...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
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
                              color: AppColors.textMuted,
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
                          colors: [Color(0xFFFA4468), Color(0xFFFF7A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPink.withValues(alpha: 0.3),
                            blurRadius: 12,
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
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Special Deal 🔥',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
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
                                                  color: Colors.white,
                                                  size: 9,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Explore Delicious Menus',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap here to view all special deals & hot offers from all restaurants!',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.local_fire_department_rounded,
                                      color: Colors.white,
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF1F3F5),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.storefront_outlined,
                                    size: 42,
                                    color: AppColors.textMuted
                                        .withValues(alpha: 0.5),
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
                                      color: AppColors.textMuted,
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFF1F3F5),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.035),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
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
                                          logoImage: logo,
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
                                                        color:
                                                            AppColors.textDark,
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
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color(0xFFFFF3E0),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
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
                                                            color: Color(
                                                                0xFFE65100),
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
                                                      color:
                                                          AppColors.primaryPink,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        loc,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors
                                                              .textMuted,
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
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppColors.textMuted,
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
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .primaryPink
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
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
                                                                FontWeight.w700,
                                                            color: AppColors
                                                                .primaryPink,
                                                          ),
                                                        ),
                                                        SizedBox(width: 4),
                                                        Icon(
                                                          Icons
                                                              .arrow_forward_ios_rounded,
                                                          size: 10,
                                                          color: AppColors
                                                              .primaryPink,
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
