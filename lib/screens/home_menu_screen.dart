import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'categories_screen.dart';
import 'item_detail_screen.dart';
import 'login_screen.dart';
import 'menu_screen.dart';
import 'profile_screen.dart';
import 'restaurant_orders_screen.dart';

class HomeMenuScreen extends StatefulWidget {
  const HomeMenuScreen({super.key});

  @override
  State<HomeMenuScreen> createState() => _HomeMenuScreenState();
}

class _HomeMenuScreenState extends State<HomeMenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  bool _isSearchVisible = false;
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  Set<String> _selectedCategoryIds = {};
  List<String> _restaurantIds = [];
  Set<String> _myCategoryIds = {};

  // In-memory order counter / cart state
  final Map<String, int> _orderCart = {};
  final Map<String, double> _orderPrices = {};

  @override
  void initState() {
    super.initState();
    _loadRestaurantIds();
    AuthService().cleanAllItemsCollection();
  }

  Future<void> _loadRestaurantIds() async {
    final ids = await AuthService().getCurrentRestaurantIds();
    if (mounted) {
      setState(() {
        _restaurantIds = ids;
      });
    }
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
            // Compact white outlined rounded box with checkmark
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

            // Compact product count text
            Expanded(
              child: Text(
                '$_totalCartCount ${_totalCartCount == 1 ? "Product" : "Products"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // Compact price text
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
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
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
    if (url.trim().isEmpty) {
      return _buildFallbackImage(width, height, borderRadius);
    }

    if (!url.startsWith('http')) {
      final file = File(url);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _buildFallbackImage(width, height, borderRadius),
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _buildFallbackImage(width, height, borderRadius),
      ),
    );
  }

  Widget _buildFallbackImage(double width, double height, double borderRadius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: AppColors.textMuted.withValues(alpha: 0.6),
          size: width * 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Centered "Menu" Title + Rounded Search Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Left: Logout / Profile button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _confirmLogout(context),
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
                            Icons.logout_rounded,
                            color: AppColors.primaryPink,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Center(
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Restaurant Orders Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RestaurantOrdersScreen(),
                                ),
                              );
                            },
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
                                Icons.receipt_long_rounded,
                                color: AppColors.primaryPink,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Search Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isSearchVisible = !_isSearchVisible;
                                if (!_isSearchVisible) {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _searchFocusNode.unfocus();
                                } else {
                                  _searchFocusNode.requestFocus();
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _isSearchVisible
                                    ? AppColors.primaryPink.withValues(alpha: 0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isSearchVisible
                                      ? AppColors.primaryPink
                                      : AppColors.inputBorder,
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
                              child: Icon(
                                _isSearchVisible ? Icons.close : Icons.search_rounded,
                                color: _isSearchVisible
                                    ? AppColors.primaryPink
                                    : AppColors.textDark,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Animated Collapsible Search Bar
            if (_isSearchVisible)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryPink.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPink.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
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
                      hintText: 'Search items...',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
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
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 13),
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
                    // ==========================================
                    // 1. CATEGORIES SECTION (Horizontal List)
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (_selectedCategoryId != null || _selectedCategoryIds.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _selectedCategoryName = null;
                                  _selectedCategoryIds.clear();
                                });
                              },
                              child: const Text(
                                'Show All',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryPink,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Horizontal Categories Stream
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('categories')
                          .snapshots()
                          .map((snapshot) {
                            final currentUid = FirebaseAuth.instance.currentUser?.uid;
                            if (currentUid == null) return <Map<String, dynamic>>[];
                            final myDocs = snapshot.docs.where((doc) {
                              final data = doc.data();
                              final restId = (data['restaurant_id'] ?? '').toString();
                              final userId = (data['user_id'] ?? '').toString();
                              return _restaurantIds.contains(restId) ||
                                  _restaurantIds.contains(userId) ||
                                  restId == currentUid ||
                                  userId == currentUid;
                            }).toList();

                            _myCategoryIds = myDocs
                                .map((doc) => [
                                      doc.id,
                                      (doc.data()['category_id'] ?? '').toString(),
                                      (doc.data()['cat_id'] ?? '').toString(),
                                    ])
                                .expand((element) => element)
                                .where((id) => id.isNotEmpty)
                                .toSet();

                            return myDocs.map((doc) {
                              final data = doc.data();
                              final String rawCatId = (data['category_id'] ??
                                      data['cat_id'] ??
                                      '')
                                  .toString()
                                  .trim();
                              final String catId =
                                  rawCatId.isNotEmpty ? rawCatId : doc.id;
                              return {
                                'cat_id': catId,
                                'doc_id': doc.id,
                                'cat_name': (data['category_name'] ??
                                        data['cat_name'] ??
                                        data['name'] ??
                                        '')
                                    .toString(),
                                'cat_pic': (data['cat_pic'] ??
                                        data['imageUrl'] ??
                                        '')
                                    .toString(),
                              };
                            }).toList();
                          }),
                      builder: (context, catSnapshot) {
                        if (catSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 135,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryPink,
                              ),
                            ),
                          );
                        }

                        final categories = catSnapshot.data ?? [];

                        if (categories.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            child: Text(
                              'No categories available',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          );
                        }

                        return SizedBox(
                          height: 138,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final String docId =
                                  (cat['doc_id'] ?? '').toString();
                              final String rawId =
                                  (cat['cat_id'] ?? '').toString();
                              final String name =
                                  (cat['cat_name'] ?? '').toString();
                              final String pic =
                                  (cat['cat_pic'] ?? '').toString();
                              final bool isSelected = _selectedCategoryId != null &&
                                  (_selectedCategoryId == docId ||
                                      (_selectedCategoryName != null &&
                                          _selectedCategoryName!.isNotEmpty &&
                                          _selectedCategoryName == name));

                              return GestureDetector(
                                key: ValueKey(docId),
                                onTap: () {
                                  final bool willDeselect = isSelected;
                                  setState(() {
                                    if (willDeselect) {
                                      _selectedCategoryId = null;
                                      _selectedCategoryName = null;
                                      _selectedCategoryIds.clear();
                                    } else {
                                      _selectedCategoryId = docId;
                                      _selectedCategoryName = name;
                                      _selectedCategoryIds = {
                                        docId,
                                        if (rawId.isNotEmpty && !_restaurantIds.contains(rawId)) rawId,
                                      };
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 104,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primaryPink
                                          : const Color(0xFFF1F3F5),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? AppColors.primaryPink
                                                .withValues(alpha: 0.15)
                                            : Colors.black
                                                .withValues(alpha: 0.04),
                                        blurRadius: isSelected ? 10 : 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            6, 6, 6, 0),
                                        child: _buildImage(
                                          pic,
                                          width: 92,
                                          height: 82,
                                          borderRadius: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? AppColors.primaryPink
                                                : AppColors.textDark,
                                          ),
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // 2. ITEMS SECTION (Vertical Cards List)
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                      child: Row(
                        children: [
                          const Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (_selectedCategoryName != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPink
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedCategoryName!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryPink,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedCategoryId = null;
                                        _selectedCategoryName = null;
                                        _selectedCategoryIds.clear();
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: AppColors.primaryPink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Items Stream from Firestore
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('items')
                          .snapshots()
                          .map((snapshot) {
                            final currentUid = FirebaseAuth.instance.currentUser?.uid;
                            if (currentUid == null) return <Map<String, dynamic>>[];
                            return snapshot.docs
                                .where((doc) {
                                  final data = doc.data();
                                  final restId = (data['restaurant_id'] ?? '').toString();
                                  final userId = (data['user_id'] ?? '').toString();
                                  final catId = (data['category_id'] ?? data['cat_id'] ?? '').toString();

                                  final matchesRestId = _restaurantIds.contains(restId) ||
                                      _restaurantIds.contains(userId) ||
                                      (restId.isNotEmpty && restId == currentUid) ||
                                      (userId.isNotEmpty && userId == currentUid);
                                  final matchesCategory = _myCategoryIds.isNotEmpty && _myCategoryIds.contains(catId);

                                  if (restId.isNotEmpty || userId.isNotEmpty) {
                                    return matchesRestId;
                                  }
                                  return matchesCategory;
                                })
                                .map((doc) {
                                  final data = doc.data();
                                  final priceVal = data['item_price'] ??
                                      data['prod_price'] ??
                                      0.0;
                                  return {
                                    'item_id': doc.id,
                                    'prod_id': doc.id,
                                    'item_name': (data['item_name'] ??
                                            data['prod_name'] ??
                                            '')
                                        .toString(),
                                    'item_price': priceVal is num
                                        ? priceVal.toDouble()
                                        : (double.tryParse(
                                                priceVal.toString()) ??
                                            0.0),
                                    'item_description':
                                        (data['item_description'] ??
                                                data['prod_desc'] ??
                                                '')
                                            .toString(),
                                    'item_pic': (data['item_pic'] ??
                                            data['prod_pic'] ??
                                            '')
                                        .toString(),
                                    'cat_id': (data['category_id'] ??
                                            data['cat_id'] ??
                                            '')
                                        .toString(),
                                    'cat_name': (data['category_name'] ??
                                            data['cat_name'] ??
                                            '')
                                        .toString(),
                                    'discount_percent':
                                        (data['discount_percent'] as num?)
                                                ?.toDouble() ??
                                            0.0,
                                    'original_price':
                                        (data['original_price'] as num?)
                                            ?.toDouble(),
                                  };
                                }).toList();
                          }),
                      builder: (context, itemSnapshot) {
                        if (itemSnapshot.connectionState ==
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

                        if (itemSnapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 20),
                            child: Center(
                              child: Text(
                                'Error loading items: ${itemSnapshot.error}',
                                style: const TextStyle(
                                    color: AppColors.primaryPink),
                              ),
                            ),
                          );
                        }

                        final allItems = itemSnapshot.data ?? [];

                        // Filter by Category and Search Query
                        final filteredItems = allItems.where((item) {
                          final name = (item['item_name'] ?? '')
                              .toString()
                              .toLowerCase();
                          final catId =
                              (item['cat_id'] ?? '').toString().trim();
                          final catName = (item['cat_name'] ?? '')
                              .toString()
                              .trim()
                              .toLowerCase();

                          final matchesSearch = name.contains(
                              _searchQuery.toLowerCase().trim());
                          final matchesCategory =
                              _selectedCategoryId == null ||
                                  _selectedCategoryId!.isEmpty ||
                                  _selectedCategoryIds.contains(catId) ||
                                  catId == _selectedCategoryId ||
                                  (_selectedCategoryName != null &&
                                      _selectedCategoryName!.isNotEmpty &&
                                      catName.isNotEmpty &&
                                      catName ==
                                          _selectedCategoryName!
                                              .toLowerCase());

                          return matchesSearch && matchesCategory;
                        }).toList();

                        if (filteredItems.isEmpty) {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 24),
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
                                    Icons.restaurant_menu_rounded,
                                    size: 40,
                                    color: AppColors.textMuted
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No items found matching "$_searchQuery"'
                                        : _selectedCategoryName != null
                                            ? 'No items in category "$_selectedCategoryName"'
                                            : 'No items found',
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
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final name =
                                (item['item_name'] ?? '').toString();
                            final price = (item['item_price'] as num?)
                                    ?.toDouble() ??
                                0.0;
                            final pic = (item['item_pic'] ?? '').toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
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
                                        .withValues(alpha: 0.035),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
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
                                          itemId: (item['item_id'] ?? item['prod_id'] ?? '').toString(),
                                          itemName: name,
                                          itemPrice: price,
                                          itemImageUrl: pic,
                                          itemDescription: (item['item_description'] ?? '').toString(),
                                          categoryId: (item['cat_id'] ?? '').toString(),
                                          categoryName: (item['cat_name'] ?? '').toString(),
                                          initialData: item,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Left: Item Thumbnail
                                        _buildImage(
                                          pic,
                                          width: 76,
                                          height: 76,
                                          borderRadius: 14,
                                        ),
                                        const SizedBox(width: 14),

                                        // Middle: Item Name + Pink Price
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
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textDark,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              if ((item['discount_percent'] as num? ?? 0) > 0 &&
                                                  (item['original_price'] as num? ?? 0) > price) ...[
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Rs. ${(item['original_price'] as num).toDouble().toStringAsFixed(0)}',
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
                                                        '${(item['discount_percent'] as num).toDouble().toStringAsFixed(0)}% off',
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
                                                'Rs. ${price.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primaryPink,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Right: Lime Green "+" Button matching screenshot
                                        _AddToCartButton(
                                          onAdd: () => _addToCart(item),
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
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const CategoriesScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MenuScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ),
            );
          }
        },
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.editGreen,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.editGreen.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
