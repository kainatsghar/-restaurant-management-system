import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'categories_screen.dart';
import 'item_detail_screen.dart';
import 'login_screen.dart';
import 'menu_screen.dart';
import 'profile_screen.dart';
import 'restaurant_orders_screen.dart';

class _CategoryFilterData {
  final String? id;
  final String? name;
  final Set<String> ids;

  const _CategoryFilterData({
    this.id,
    this.name,
    this.ids = const {},
  });

  bool get isFiltering => id != null && id!.isNotEmpty;
}

class HomeMenuScreen extends StatefulWidget {
  const HomeMenuScreen({super.key});

  @override
  State<HomeMenuScreen> createState() => _HomeMenuScreenState();
}

class _HomeMenuScreenState extends State<HomeMenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final ValueNotifier<_CategoryFilterData> _categoryFilter =
      ValueNotifier<_CategoryFilterData>(const _CategoryFilterData());

  bool _isSearchVisible = false;
  List<String> _restaurantIds = [];
  Set<String> _myCategoryIds = {};

  Stream<List<Map<String, dynamic>>>? _categoriesStream;
  Stream<List<Map<String, dynamic>>>? _itemsStream;

  // In-memory order counter / cart state
  final Map<String, int> _orderCart = {};
  final Map<String, double> _orderPrices = {};

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
    AuthService().cleanAllItemsCollection();
    AuthService().deletePizzaCategoryAndItems();
  }

  Future<void> _loadRestaurantData() async {
    final ids = await AuthService().getCurrentRestaurantIds();
    if (mounted) {
      setState(() {
        _restaurantIds = ids;
        _setupStreams();
      });
    }
  }

  void _setupStreams() {
    final user = FirebaseAuth.instance.currentUser;
    final currentUid = user?.uid;
    final currentEmail = user?.email?.trim().toLowerCase() ?? '';

    _categoriesStream = FirebaseFirestore.instance
        .collection('categories')
        .snapshots()
        .map((snapshot) {
      if (currentUid == null) return <Map<String, dynamic>>[];
      final myDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final restId = (data['restaurant_id'] ?? '').toString().trim();
        final userId = (data['user_id'] ?? '').toString().trim();
        final email = (data['email'] ?? data['owner_email'] ?? '').toString().trim().toLowerCase();
        final restName = (data['restaurant_name'] ?? '').toString().trim().toLowerCase();

        return (restId.isNotEmpty && _restaurantIds.contains(restId)) ||
            (userId.isNotEmpty && _restaurantIds.contains(userId)) ||
            (email.isNotEmpty && (email == currentEmail || _restaurantIds.contains(email))) ||
            (restName.isNotEmpty && _restaurantIds.contains(restName)) ||
            (restId.isNotEmpty && restId == currentUid) ||
            (userId.isNotEmpty && userId == currentUid);
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
        final String rawCatId =
            (data['category_id'] ?? data['cat_id'] ?? '').toString().trim();
        final String catId = rawCatId.isNotEmpty ? rawCatId : doc.id;
        return {
          'cat_id': catId,
          'doc_id': doc.id,
          'cat_name': (data['category_name'] ??
                  data['cat_name'] ??
                  data['name'] ??
                  '')
              .toString(),
          'cat_pic':
              (data['cat_pic'] ?? data['imageUrl'] ?? '').toString(),
        };
      }).toList();
    });

    _itemsStream = FirebaseFirestore.instance
        .collection('items')
        .snapshots()
        .map((snapshot) {
      if (currentUid == null) return <Map<String, dynamic>>[];
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            final restId = (data['restaurant_id'] ?? '').toString().trim();
            final userId = (data['user_id'] ?? '').toString().trim();
            final email = (data['email'] ?? data['owner_email'] ?? '').toString().trim().toLowerCase();
            final restName = (data['restaurant_name'] ?? '').toString().trim().toLowerCase();
            final catId =
                (data['category_id'] ?? data['cat_id'] ?? '').toString().trim();

            final matchesRestId = (restId.isNotEmpty && _restaurantIds.contains(restId)) ||
                (userId.isNotEmpty && _restaurantIds.contains(userId)) ||
                (email.isNotEmpty && (email == currentEmail || _restaurantIds.contains(email))) ||
                (restName.isNotEmpty && _restaurantIds.contains(restName)) ||
                (restId.isNotEmpty && restId == currentUid) ||
                (userId.isNotEmpty && userId == currentUid);
            final matchesCategory =
                _myCategoryIds.isNotEmpty && _myCategoryIds.contains(catId);

            if (restId.isNotEmpty || userId.isNotEmpty || email.isNotEmpty) {
              return matchesRestId;
            }
            return matchesCategory;
          })
          .map((doc) {
            final data = doc.data();
            final priceVal =
                data['item_price'] ?? data['prod_price'] ?? 0.0;
            return {
              'item_id': doc.id,
              'prod_id': doc.id,
              'item_name':
                  (data['item_name'] ?? data['prod_name'] ?? '').toString(),
              'item_price': priceVal is num
                  ? priceVal.toDouble()
                  : (double.tryParse(priceVal.toString()) ?? 0.0),
              'item_description': (data['item_description'] ??
                      data['prod_desc'] ??
                      '')
                  .toString(),
              'item_pic':
                  (data['item_pic'] ?? data['prod_pic'] ?? '').toString(),
              'cat_id':
                  (data['category_id'] ?? data['cat_id'] ?? '').toString(),
              'cat_name':
                  (data['category_name'] ?? data['cat_name'] ?? '').toString(),
              'discount_percent':
                  (data['discount_percent'] as num?)?.toDouble() ?? 0.0,
              'original_price':
                  (data['original_price'] as num?)?.toDouble(),
            };
          })
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQuery.dispose();
    _categoryFilter.dispose();
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

    setState(() {
      _orderCart[id] = (_orderCart[id] ?? 0) + 1;
      _orderPrices[id] = price;
    });

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
                '$_totalCartCount ${_totalCartCount == 1 ? "Product" : "Products"}',
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
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        duration: const Duration(seconds: 2),
        elevation: 4,
      ),
    );
  }

  void _onCategoryTap(String docId, String rawId, String name) {
    final current = _categoryFilter.value;
    final isSelected = current.id != null &&
        (current.id == docId ||
            (current.name != null &&
                current.name!.isNotEmpty &&
                current.name == name));

    if (isSelected) {
      _categoryFilter.value = const _CategoryFilterData();
    } else {
      _categoryFilter.value = _CategoryFilterData(
        id: docId,
        name: name,
        ids: {
          docId,
          if (rawId.isNotEmpty && !_restaurantIds.contains(rawId)) rawId,
        },
      );
    }
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Left: Logout
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
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF18191E),
                                Color(0xFF201620),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFA4468).withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFFF5277),
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

                  // Right: Orders & Search
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF18191E),
                                    Color(0xFF201620),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFA4468).withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFFFF5277),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isSearchVisible = !_isSearchVisible;
                                if (!_isSearchVisible) {
                                  _searchController.clear();
                                  _searchQuery.value = '';
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
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _isSearchVisible
                                      ? [
                                          const Color(0xFFFA4468),
                                          const Color(0xFFFF6283),
                                        ]
                                      : [
                                          const Color(0xFF18191E),
                                          const Color(0xFF201620),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFA4468).withValues(alpha: 0.4),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFA4468).withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isSearchVisible ? Icons.close : Icons.search_rounded,
                                color: Colors.white,
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF18191E),
                        Color(0xFF201620),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFA4468).withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (val) {
                      _searchQuery.value = val;
                    },
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: const Color(0xFFFA4468),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFFFF5277),
                        size: 20,
                      ),
                      suffixIcon: ValueListenableBuilder<String>(
                        valueListenable: _searchQuery,
                        builder: (context, query, _) {
                          if (query.isEmpty) return const SizedBox.shrink();
                          return IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Colors.white.withValues(alpha: 0.6),
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery.value = '';
                            },
                          );
                        },
                      ),
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
                    // 1. Categories Header
                    _CategoriesHeader(
                      categoryFilter: _categoryFilter,
                      onClear: () {
                        _categoryFilter.value = const _CategoryFilterData();
                      },
                    ),

                    // Categories Horizontal List
                    _CategoriesSection(
                      categoriesStream: _categoriesStream,
                      categoryFilter: _categoryFilter,
                      onCategoryTap: _onCategoryTap,
                    ),

                    const SizedBox(height: 18),

                    // 2. Items Header
                    _ItemsHeader(
                      categoryFilter: _categoryFilter,
                      onClearCategory: () {
                        _categoryFilter.value = const _CategoryFilterData();
                      },
                    ),

                    // Items Vertical List
                    _ItemsSection(
                      itemsStream: _itemsStream,
                      categoryFilter: _categoryFilter,
                      searchQuery: _searchQuery,
                      onAddToCart: _addToCart,
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

// =======================================================
// ISOLATED WIDGET: Categories Header (Listens to filter)
// =======================================================
class _CategoriesHeader extends StatelessWidget {
  final ValueNotifier<_CategoryFilterData> categoryFilter;
  final VoidCallback onClear;

  const _CategoriesHeader({
    required this.categoryFilter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          ValueListenableBuilder<_CategoryFilterData>(
            valueListenable: categoryFilter,
            builder: (context, filter, _) {
              if (!filter.isFiltering) return const SizedBox.shrink();
              return GestureDetector(
                onTap: onClear,
                child: const Text(
                  'Show All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryPink,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =======================================================
// ISOLATED WIDGET: Categories Section
// =======================================================
class _CategoriesSection extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>>? categoriesStream;
  final ValueNotifier<_CategoryFilterData> categoryFilter;
  final void Function(String docId, String rawId, String name) onCategoryTap;

  const _CategoriesSection({
    required this.categoriesStream,
    required this.categoryFilter,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categoriesStream == null) {
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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: categoriesStream,
      builder: (context, catSnapshot) {
        if (catSnapshot.connectionState == ConnectionState.waiting &&
            !catSnapshot.hasData) {
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
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final String docId = (cat['doc_id'] ?? '').toString();
              final String rawId = (cat['cat_id'] ?? '').toString();
              final String name = (cat['cat_name'] ?? '').toString();
              final String pic = (cat['cat_pic'] ?? '').toString();

              return _CategoryItemCard(
                key: ValueKey('cat_$docId'),
                docId: docId,
                rawId: rawId,
                name: name,
                pic: pic,
                categoryFilter: categoryFilter,
                onTap: () => onCategoryTap(docId, rawId, name),
              );
            },
          ),
        );
      },
    );
  }
}

// =======================================================
// ISOLATED WIDGET: Single Category Card (Only updates itself)
// =======================================================
class _CategoryItemCard extends StatelessWidget {
  final String docId;
  final String rawId;
  final String name;
  final String pic;
  final ValueNotifier<_CategoryFilterData> categoryFilter;
  final VoidCallback onTap;

  const _CategoryItemCard({
    super.key,
    required this.docId,
    required this.rawId,
    required this.name,
    required this.pic,
    required this.categoryFilter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_CategoryFilterData>(
      valueListenable: categoryFilter,
      builder: (context, filter, _) {
        final bool isSelected = filter.id != null &&
            (filter.id == docId ||
                (filter.name != null &&
                    filter.name!.isNotEmpty &&
                    filter.name == name));

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 104,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF18191E),
                  Color(0xFF201620),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFA4468)
                    : const Color(0xFFFA4468).withValues(alpha: 0.28),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFFFA4468).withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: isSelected ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: AppNetworkImage(
                    key: ValueKey('img_cat_$docId'),
                    imageUrl: pic,
                    width: 92,
                    height: 82,
                    borderRadius: 12,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.fastfood_rounded,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFFF5277)
                          : Colors.white,
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
    );
  }
}

// =======================================================
// ISOLATED WIDGET: Items Header (Listens to filter badge)
// =======================================================
class _ItemsHeader extends StatelessWidget {
  final ValueNotifier<_CategoryFilterData> categoryFilter;
  final VoidCallback onClearCategory;

  const _ItemsHeader({
    required this.categoryFilter,
    required this.onClearCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          ValueListenableBuilder<_CategoryFilterData>(
            valueListenable: categoryFilter,
            builder: (context, filter, _) {
              if (filter.name == null || filter.name!.isEmpty) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPink.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          filter.name!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryPink,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onClearCategory,
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
              );
            },
          ),
        ],
      ),
    );
  }
}

// =======================================================
// ISOLATED WIDGET: Items Section (Filters in memory without stream restarts)
// =======================================================
class _ItemsSection extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>>? itemsStream;
  final ValueNotifier<_CategoryFilterData> categoryFilter;
  final ValueNotifier<String> searchQuery;
  final void Function(Map<String, dynamic> item) onAddToCart;

  const _ItemsSection({
    required this.itemsStream,
    required this.categoryFilter,
    required this.searchQuery,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    if (itemsStream == null) {
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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: itemsStream,
      builder: (context, itemSnapshot) {
        if (itemSnapshot.connectionState == ConnectionState.waiting &&
            !itemSnapshot.hasData) {
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: Text(
                'Error loading items: ${itemSnapshot.error}',
                style: const TextStyle(color: AppColors.primaryPink),
              ),
            ),
          );
        }

        final allItems = itemSnapshot.data ?? [];

        return AnimatedBuilder(
          animation: Listenable.merge([categoryFilter, searchQuery]),
          builder: (context, _) {
            final filter = categoryFilter.value;
            final query = searchQuery.value.toLowerCase().trim();

            final filteredItems = allItems.where((item) {
              final name =
                  (item['item_name'] ?? '').toString().toLowerCase();
              final catId = (item['cat_id'] ?? '').toString().trim();
              final catName =
                  (item['cat_name'] ?? '').toString().trim().toLowerCase();

              final matchesSearch = query.isEmpty || name.contains(query);

              final matchesCategory = !filter.isFiltering ||
                  filter.ids.contains(catId) ||
                  catId == filter.id ||
                  (filter.name != null &&
                      filter.name!.isNotEmpty &&
                      catName.isNotEmpty &&
                      catName == filter.name!.toLowerCase());

              return matchesSearch && matchesCategory;
            }).toList();

            if (filteredItems.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF18191E),
                      Color(0xFF201620),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFA4468).withValues(alpha: 0.35),
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
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        query.isNotEmpty
                            ? 'No items found matching "$query"'
                            : filter.name != null
                                ? 'No items in category "${filter.name}"'
                                : 'No items found',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.6),
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
                final String itemId =
                    (item['item_id'] ?? item['prod_id'] ?? index.toString())
                        .toString();

                return _MenuItemCard(
                  key: ValueKey('item_$itemId'),
                  item: item,
                  onAddToCart: () => onAddToCart(item),
                );
              },
            );
          },
        );
      },
    );
  }
}

// =======================================================
// ISOLATED WIDGET: Single Menu Item Card
// =======================================================
class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onAddToCart;

  const _MenuItemCard({
    super.key,
    required this.item,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final name = (item['item_name'] ?? '').toString();
    final price = (item['item_price'] as num?)?.toDouble() ?? 0.0;
    final pic = (item['item_pic'] ?? '').toString();
    final String itemId =
        (item['item_id'] ?? item['prod_id'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF18191E),
            Color(0xFF201620),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFA4468).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFA4468).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
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
                  itemId: itemId,
                  itemName: name,
                  itemPrice: price,
                  itemImageUrl: pic,
                  itemDescription:
                      (item['item_description'] ?? '').toString(),
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
                AppNetworkImage(
                  key: ValueKey('item_img_$itemId'),
                  imageUrl: pic,
                  width: 76,
                  height: 76,
                  borderRadius: 14,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.fastfood_rounded,
                ),
                const SizedBox(width: 14),

                // Middle: Item Name + Pink Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.5),
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFA4468)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(item['discount_percent'] as num).toDouble().toStringAsFixed(0)}% off',
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
                      Text(
                        'Rs. ${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF5277),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right: Lime Green "+" Button matching screenshot
                _AddToCartButton(
                  onAdd: onAddToCart,
                ),
              ],
            ),
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryPink.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.55),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryPink.withValues(alpha: 0.65),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPink.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              color: Color(0xFFFF6584),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
