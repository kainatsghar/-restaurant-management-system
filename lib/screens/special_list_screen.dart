import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/app_network_image.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'item_detail_screen.dart';
import 'profile_screen.dart';
import 'restaurant_detail_screen.dart';
import 'user_orders_screen.dart';
import 'user_restaurants_screen.dart';

class SpecialListScreen extends StatefulWidget {
  const SpecialListScreen({super.key});

  @override
  State<SpecialListScreen> createState() => _SpecialListScreenState();
}

class _SpecialListScreenState extends State<SpecialListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Categories, 2: Dishes

  // In-memory cart
  final Map<String, int> _orderCart = {};
  final Map<String, double> _orderPrices = {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int get _totalCartCount =>
      _orderCart.values.fold(0, (total, qty) => total + qty);

  double get _totalCartPrice => _orderCart.entries.fold(
      0.0,
      (total, entry) =>
          total + (entry.value * (_orderPrices[entry.key] ?? 0.0)));

  void _addToCart(Map<String, dynamic> item) {
    final String id = (item['item_id'] ?? item['prod_id'] ?? '').toString();
    final double price = (item['item_price'] as num?)?.toDouble() ?? 0.0;

    _orderCart[id] = (_orderCart[id] ?? 0) + 1;
    _orderPrices[id] = price;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white,
                  width: 1.6,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_totalCartCount ${_totalCartCount == 1 ? "Product" : "Products"} added to cart',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Text(
              'Rs. ${_totalCartPrice.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryPink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        duration: const Duration(seconds: 2),
        elevation: 4,
      ),
    );
  }

  Widget _buildImage(
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
      fallbackIcon: Icons.local_fire_department_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.inputBorder,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textDark,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Special Deals & Menus',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text('🔥', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        Text(
                          'Exclusive specials from all restaurants',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 46,
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
                    hintText: 'Search special dishes or categories...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryPink,
                      size: 20,
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Filter Tabs: All Specials / Categories / Dishes (Horizontally scrollable to avoid overflow)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                children: [
                  _buildFilterTab(0, 'All Specials'),
                  const SizedBox(width: 8),
                  _buildFilterTab(1, 'Special Categories'),
                  const SizedBox(width: 8),
                  _buildFilterTab(2, 'Special Dishes'),
                ],
              ),
            ),

            // Main Content Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('categories')
                    .snapshots(),
                builder: (context, catSnapshot) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('items')
                        .snapshots(),
                    builder: (context, itemSnapshot) {
                      if (catSnapshot.connectionState ==
                              ConnectionState.waiting ||
                          itemSnapshot.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryPink,
                          ),
                        );
                      }

                      final catDocs = catSnapshot.data?.docs ?? [];
                      final itemDocs = itemSnapshot.data?.docs ?? [];

                      // 1. Filter Special Categories
                      final specialCategories = catDocs.where((doc) {
                        final data = doc.data();
                        final isSpecial = data['is_special'] == true;
                        final type = (data['category_type'] ?? '').toString().toLowerCase();
                        final name = (data['category_name'] ?? data['cat_name'] ?? '').toString().toLowerCase();
                        final tag = (data['special_tag'] ?? '').toString().toLowerCase();

                        final isSpecialCandidate = isSpecial ||
                            type.contains('special') ||
                            type.contains('deal') ||
                            name.contains('special') ||
                            name.contains('deal') ||
                            tag.isNotEmpty;

                        final q = _searchQuery.toLowerCase().trim();
                        final matchesQuery = q.isEmpty ||
                            name.contains(q) ||
                            type.contains(q) ||
                            tag.contains(q);

                        return isSpecialCandidate && matchesQuery;
                      }).toList();

                      // Set of special category IDs
                      final specialCatIds = specialCategories
                          .map((doc) => [
                                doc.id,
                                (doc.data()['category_id'] ?? '').toString(),
                                (doc.data()['cat_id'] ?? '').toString(),
                              ])
                          .expand((e) => e)
                          .where((id) => id.isNotEmpty)
                          .toSet();

                      // 2. Filter Special Items / Dishes
                      final specialItems = itemDocs.where((doc) {
                        final data = doc.data();
                        final isSpecial = data['is_special'] == true;
                        final catId = (data['category_id'] ?? data['cat_id'] ?? '').toString();
                        final name = (data['item_name'] ?? data['prod_name'] ?? '').toString().toLowerCase();
                        final desc = (data['item_description'] ?? '').toString().toLowerCase();

                        final double discPercent =
                            (data['discount_percent'] as num?)?.toDouble() ?? 0.0;
                        final bool hasDiscount =
                            discPercent > 0 || data['has_discount'] == true;

                        final belongsToSpecialCat = specialCatIds.contains(catId);
                        final isCandidate = isSpecial ||
                            hasDiscount ||
                            belongsToSpecialCat ||
                            name.contains('special') ||
                            name.contains('deal') ||
                            desc.contains('special') ||
                            desc.contains('deal');

                        final q = _searchQuery.toLowerCase().trim();
                        final matchesQuery = q.isEmpty ||
                            name.contains(q) ||
                            desc.contains(q);

                        return isCandidate && matchesQuery;
                      }).toList();

                      final bool hasNoResults =
                          specialCategories.isEmpty && specialItems.isEmpty;

                      if (hasNoResults) {
                        return Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFF3E0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 54,
                                    color: Color(0xFFFFA000),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No specials found matching "$_searchQuery"'
                                      : 'No Special Deals Available Yet',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Restaurant owners can mark categories and dishes as special deals to appear here!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Special Deals Hero Banner
                            Container(
                              margin: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF5252), Color(0xFFFF7A00)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF5252).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'HOT SPECIALS 🔥',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Exclusive Chef Deals & Offers',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Order directly from these hand-picked specials!',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.9),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.restaurant_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ==========================================
                            // 1. SPECIAL CATEGORIES SECTION
                            // ==========================================
                            if (_selectedFilterIndex == 0 ||
                                _selectedFilterIndex == 1) ...[
                              if (specialCategories.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 6),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Color(0xFFFFA000),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Special Categories',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${specialCategories.length} Categories',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primaryPink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 160,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    itemCount: specialCategories.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final catDoc = specialCategories[index];
                                      final data = catDoc.data();
                                      final name = (data['category_name'] ??
                                              data['cat_name'] ??
                                              data['name'] ??
                                              'Special')
                                          .toString();
                                      final pic = (data['cat_pic'] ??
                                              data['imageUrl'] ??
                                              '')
                                          .toString();
                                      final tag = (data['special_tag'] ??
                                              data['category_type'] ??
                                              'Special')
                                          .toString();
                                      final restId = (data['restaurant_id'] ??
                                              data['user_id'] ??
                                              '')
                                          .toString();

                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  RestaurantDetailScreen(
                                                restaurantId: restId,
                                                restaurantName: name,
                                                logoImage: pic,
                                                location: 'Special Category Menu',
                                                description: tag,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: 128,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: const Color(0xFFFFD54F)
                                                  .withValues(alpha: 0.8),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.04),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Stack(
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    child: _buildImage(
                                                      pic,
                                                      width: 116,
                                                      height: 85,
                                                      borderRadius: 12,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 10,
                                                    left: 10,
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFFF5252),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .local_fire_department_rounded,
                                                            color: Colors.white,
                                                            size: 10,
                                                          ),
                                                          SizedBox(width: 2),
                                                          Text(
                                                            'HOT',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textDark,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                                child: Text(
                                                  tag,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.primaryPink,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ],

                            // ==========================================
                            // 2. SPECIAL DISHES / FOOD ITEMS
                            // ==========================================
                            if (_selectedFilterIndex == 0 ||
                                _selectedFilterIndex == 2) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 6),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.fastfood_rounded,
                                      color: AppColors.primaryPink,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Special Dishes & Deals',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${specialItems.isNotEmpty ? specialItems.length : itemDocs.length} Items',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Items vertical list
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: specialItems.isNotEmpty
                                    ? specialItems.length
                                    : itemDocs.length,
                                itemBuilder: (context, index) {
                                  final doc = specialItems.isNotEmpty
                                      ? specialItems[index]
                                      : itemDocs[index];
                                  final data = doc.data();
                                  final name = (data['item_name'] ??
                                          data['prod_name'] ??
                                          '')
                                      .toString();
                                  final priceVal = data['item_price'] ??
                                      data['prod_price'] ??
                                      0.0;
                                  final double rawPrice = priceVal is num
                                      ? priceVal.toDouble()
                                      : (double.tryParse(
                                              priceVal.toString()) ??
                                          0.0);
                                  final double discountPercent =
                                      (data['discount_percent'] as num?)?.toDouble() ?? 0.0;
                                  final double rawOrigPrice =
                                      (data['original_price'] as num?)?.toDouble() ?? rawPrice;

                                  final double displayOriginalPrice =
                                      (discountPercent > 0 && rawOrigPrice <= rawPrice)
                                          ? (rawOrigPrice > 0 ? rawOrigPrice : rawPrice)
                                          : rawOrigPrice;
                                  final double displayFinalPrice = (discountPercent > 0)
                                      ? (rawOrigPrice > rawPrice && rawPrice > 0
                                          ? rawPrice
                                          : (displayOriginalPrice * (1.0 - (discountPercent / 100.0))))
                                      : rawPrice;
                                  final double price = displayFinalPrice;
                                  final pic = (data['item_pic'] ??
                                          data['prod_pic'] ??
                                          '')
                                      .toString();
                                  final desc = (data['item_description'] ??
                                          data['prod_desc'] ??
                                          '')
                                      .toString();
                                  final catName = (data['category_name'] ??
                                          data['cat_name'] ??
                                          'Special Deal')
                                      .toString();

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFF1F3F5),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ItemDetailScreen(
                                                itemId: doc.id,
                                                itemName: name,
                                                itemPrice: price,
                                                itemImageUrl: pic,
                                                itemDescription: desc,
                                                categoryId: (data['category_id'] ?? data['cat_id'] ?? '').toString(),
                                                categoryName: catName,
                                                restaurantId: (data['restaurant_id'] ?? '').toString(),
                                                restaurantName: (data['restaurant_name'] ?? '').toString(),
                                                initialData: data,
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              // Item Image
                                              Stack(
                                                children: [
                                                  _buildImage(
                                                    pic,
                                                    width: 76,
                                                    height: 76,
                                                    borderRadius: 14,
                                                  ),
                                                  Positioned(
                                                    top: 4,
                                                    left: 4,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                              horizontal: 5,
                                                              vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            const Color(0xFFFFA000),
                                                        borderRadius:
                                                            BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'SPECIAL',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 14),

                                              // Item Details
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.textDark,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      catName,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors.primaryPink,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (desc.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        desc,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppColors.textMuted,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                    const SizedBox(height: 4),
                                                    if (discountPercent > 0) ...[
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'Rs. ${displayOriginalPrice.toStringAsFixed(0)}',
                                                            style: const TextStyle(
                                                              fontSize: 11.5,
                                                              color: AppColors.textMuted,
                                                              decoration: TextDecoration.lineThrough,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 5),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                                horizontal: 5, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.primaryPink
                                                                  .withValues(alpha: 0.12),
                                                              borderRadius:
                                                                  BorderRadius.circular(4),
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
                                                    Text(
                                                      'Rs. ${displayFinalPrice.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontSize: 14.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.primaryPink,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Add to Cart Button
                                              _AddToCartButton(
                                                onAdd: () => _addToCart({
                                                  'item_id': doc.id,
                                                  'item_name': name,
                                                  'item_price': price,
                                                  'item_pic': pic,
                                                }),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1,
        icons: const [
          Icons.storefront_rounded,
          Icons.local_offer_outlined,
          Icons.receipt_long_rounded,
          Icons.person_outline_rounded,
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const UserRestaurantsScreen()),
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

  Widget _buildFilterTab(int index, String title) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPink : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryPink
                : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primaryPink.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddToCartButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.editGreen,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.editGreen.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
