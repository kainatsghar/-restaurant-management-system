import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/search_bar_widget.dart';
import 'add_item_screen.dart';
import 'categories_screen.dart';
import 'edit_item_screen.dart';
import 'home_menu_screen.dart';
import 'product_subcategories_screen.dart';
import 'profile_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  int _currentTabIndex = 2; // Menu book active matching Screenshot 1
  List<String> _restaurantIds = [];
  Set<String> _myCategoryIds = {};

  @override
  void initState() {
    super.initState();
    _loadRestaurantContext();
    AuthService().cleanAllItemsCollection();
  }

  Future<void> _loadRestaurantContext() async {
    final ids = await AuthService().getCurrentRestaurantIds();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      try {
        final catQuery = await FirebaseFirestore.instance.collection('categories').get();
        final myCats = catQuery.docs
            .where((doc) {
              final d = doc.data();
              final restId = (d['restaurant_id'] ?? '').toString();
              final userId = (d['user_id'] ?? '').toString();
              return ids.contains(restId) ||
                  ids.contains(userId) ||
                  restId == currentUid ||
                  userId == currentUid;
            })
            .map((doc) => [
                  doc.id,
                  (doc.data()['category_id'] ?? '').toString(),
                  (doc.data()['cat_id'] ?? '').toString(),
                ])
            .expand((e) => e)
            .where((id) => id.isNotEmpty)
            .toSet();

        if (mounted) {
          setState(() {
            _restaurantIds = ids;
            _myCategoryIds = myCats;
          });
        }
      } catch (e) {
        debugPrint('Error loading restaurant categories in menu: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openAddItem() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddItemScreen(),
      ),
    );
  }

  void _openSubcategories(Map<String, dynamic> item) {
    final id = (item['item_id'] ?? item['prod_id'] ?? '').toString();
    final name = (item['item_name'] ?? item['prod_name'] ?? '').toString();
    final pic = (item['item_pic'] ?? item['prod_pic'] ?? '').toString();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductSubcategoriesScreen(
          productId: id,
          productName: name,
          productImageUrl: pic,
        ),
      ),
    );
  }

  void _editItem(Map<String, dynamic> item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditItemScreen(
          itemId: (item['item_id'] ?? '').toString(),
          currentName: (item['item_name'] ?? '').toString(),
          currentCategoryId: (item['category_id'] ?? item['cat_id'] ?? '').toString(),
          currentCategoryName: (item['category_name'] ?? item['cat_name'] ?? '').toString(),
          currentPrice: (item['original_price'] as num?)?.toDouble() ??
              (item['item_price'] as num?)?.toDouble() ??
              0.0,
          currentDiscountPercent: (item['discount_percent'] as num?)?.toDouble() ?? 0.0,
          currentOriginalPrice: (item['original_price'] as num?)?.toDouble(),
          currentDescription: (item['item_description'] ?? '').toString(),
          currentHasGroup: item['has_group'] == true,
          currentImageUrl: (item['item_pic'] ?? '').toString(),
        ),
      ),
    );
  }

  void _deleteItem(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FirebaseFirestore.instance
                  .collection('items')
                  .doc(id)
                  .delete();
              try {
                await FirebaseFirestore.instance
                    .collection('products')
                    .doc(id)
                    .delete();
              } catch (_) {}
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Item "$name" deleted'),
                    backgroundColor: AppColors.textDark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
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
            // Top Bar: "Menu" Title + Pink "+ Add" Button matching Screenshot 1
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
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
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openAddItem,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPink,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPink
                                    .withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar matching Screenshot 1
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SearchBarWidget(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: 'Search Product',
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                onClear: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                  _searchFocusNode.unfocus();
                },
              ),
            ),

            const SizedBox(height: 8),

            // Products List from Firebase Firestore
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
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
                    final priceVal =
                        data['item_price'] ?? data['prod_price'] ?? 0.0;
                    return {
                      'item_id': doc.id,
                      'prod_id': doc.id,
                      'item_name':
                          (data['item_name'] ?? data['prod_name'] ?? '').toString(),
                      'prod_name':
                          (data['item_name'] ?? data['prod_name'] ?? '').toString(),
                      'item_price': priceVal is num
                          ? priceVal.toDouble()
                          : (double.tryParse(priceVal.toString()) ?? 0.0),
                      'item_description':
                          (data['item_description'] ?? data['prod_desc'] ?? '')
                              .toString(),
                      'item_pic':
                          (data['item_pic'] ?? data['prod_pic'] ?? '').toString(),
                      'cat_id':
                          (data['category_id'] ?? data['cat_id'] ?? '').toString(),
                      'cat_name':
                          (data['category_name'] ?? data['cat_name'] ?? '').toString(),
                      'has_group': data['has_group'] == true,
                      'discount_percent': (data['discount_percent'] as num?)?.toDouble() ?? 0.0,
                      'original_price': (data['original_price'] as num?)?.toDouble(),
                    };
                  }).toList();
                }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryPink,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.primaryPink),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];
                  final filtered = items.where((item) {
                    final name =
                        (item['item_name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase().trim());
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.trim().isNotEmpty
                            ? 'No products found matching "$_searchQuery"'
                            : 'No products found\nTap + Add to add a new product',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final id = (item['item_id'] ?? '').toString();
                      final name = (item['item_name'] ?? '').toString();
                      final price =
                          (item['item_price'] as num?)?.toDouble() ?? 0.0;
                      final pic = (item['item_pic'] ?? '').toString();
                      final discountPercent =
                          (item['discount_percent'] as num?)?.toDouble();
                      final originalPrice =
                          (item['original_price'] as num?)?.toDouble();

                      return ProductCard(
                        name: name,
                        price: price,
                        originalPrice: originalPrice,
                        discountPercent: discountPercent,
                        imageUrl: pic,
                        onTap: () => _openSubcategories(item),
                        onEdit: () => _editItem(item),
                        onDelete: () => _deleteItem(id, name),
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
        currentIndex: _currentTabIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeMenuScreen(),
              ),
            );
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const CategoriesScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ),
            );
          } else {
            setState(() {
              _currentTabIndex = index;
            });
          }
        },
      ),
    );
  }
}
