import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_network_image.dart';
import 'item_detail_screen.dart';
import 'user_orders_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String logoImage;
  final String location;
  final String description;
  final String? phone;
  final double rating;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.logoImage,
    required this.location,
    required this.description,
    this.phone,
    this.rating = 0.0,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _CategorySelectionData {
  final String? id;
  final String? name;
  final Set<String> ids;
  const _CategorySelectionData({this.id, this.name, this.ids = const {}});
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  bool _isSearchVisible = false;

  final ValueNotifier<_CategorySelectionData> _selectedCategory =
      ValueNotifier(const _CategorySelectionData());

  // Real-time Cart state using ValueNotifier for instant zero-flicker UI updates
  final ValueNotifier<Map<String, int>> _cartQuantities =
      ValueNotifier<Map<String, int>>({});
  final ValueNotifier<Map<String, double>> _cartPrices =
      ValueNotifier<Map<String, double>>({});
  final ValueNotifier<Map<String, Map<String, dynamic>>> _cartItemsData =
      ValueNotifier<Map<String, Map<String, dynamic>>>({});

  final Set<String> _restaurantMatchingKeys = {};
  final Set<String> _restaurantCategoryIds = {};
  final Set<String> _restaurantCategoryNames = {};

  @override
  void initState() {
    super.initState();
    AuthService().deletePizzaCategoryAndItems();
    _loadRestaurantMatchingKeys();
  }

  Future<void> _loadRestaurantMatchingKeys() async {
    final targetId = widget.restaurantId.trim();
    final targetName = widget.restaurantName.trim().toLowerCase();

    final Set<String> keys = {};
    if (targetId.isNotEmpty) keys.add(targetId);
    if (targetName.isNotEmpty) keys.add(targetName);

    final Set<String> catIds = {};
    final Set<String> catNames = {};

    try {
      final snap =
          await FirebaseFirestore.instance.collection('restaurants').get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final docId = doc.id.trim();
        final restId = (d['restaurant_id'] ?? '').toString().trim();
        final uniqId = (d['unique_id'] ?? '').toString().trim();
        final uId = (d['user_id'] ?? '').toString().trim();
        final email = (d['email'] ?? d['login_id'] ?? '').toString().trim().toLowerCase();
        final name = (d['restaurant_name'] ?? d['name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final matchesThisRest = (docId.isNotEmpty && docId == targetId) ||
            (restId.isNotEmpty && restId == targetId) ||
            (uniqId.isNotEmpty && uniqId == targetId) ||
            (uId.isNotEmpty && uId == targetId) ||
            (name.isNotEmpty && name == targetName);

        if (matchesThisRest) {
          if (docId.isNotEmpty) keys.add(docId);
          if (restId.isNotEmpty) keys.add(restId);
          if (uniqId.isNotEmpty) keys.add(uniqId);
          if (uId.isNotEmpty) keys.add(uId);
          if (name.isNotEmpty) keys.add(name);
          if (email.isNotEmpty) keys.add(email);
        }
      }

      // Check categories collection to find matching categories for THIS restaurant
      final catSnap =
          await FirebaseFirestore.instance.collection('categories').get();
      for (final doc in catSnap.docs) {
        final d = doc.data();
        final cRestId = (d['restaurant_id'] ?? '').toString().trim();
        final cUserId = (d['user_id'] ?? '').toString().trim();
        final cEmail = (d['email'] ?? d['owner_email'] ?? '').toString().trim().toLowerCase();
        final cRestName = (d['restaurant_name'] ?? '').toString().trim().toLowerCase();
        final cName = (d['category_name'] ?? d['cat_name'] ?? d['name'] ?? '').toString().trim().toLowerCase();
        final cId = (d['category_id'] ?? d['cat_id'] ?? doc.id).toString().trim();

        final matchesCat = (cRestId.isNotEmpty && keys.contains(cRestId)) ||
            (cUserId.isNotEmpty && keys.contains(cUserId)) ||
            (cEmail.isNotEmpty && keys.contains(cEmail)) ||
            (cRestName.isNotEmpty && (cRestName == targetName || keys.contains(cRestName)));

        if (matchesCat) {
          catIds.add(doc.id);
          if (cId.isNotEmpty) catIds.add(cId);
          if (cName.isNotEmpty) catNames.add(cName);
          if (cRestId.isNotEmpty) keys.add(cRestId);
          if (cUserId.isNotEmpty) keys.add(cUserId);
          if (cEmail.isNotEmpty) keys.add(cEmail);
        }
      }
    } catch (e) {
      debugPrint('Error loading restaurant keys: $e');
    }

    if (mounted) {
      setState(() {
        _restaurantMatchingKeys.addAll(keys);
        _restaurantCategoryIds.addAll(catIds);
        _restaurantCategoryNames.addAll(catNames);
      });
    }
  }

  bool _isCategoryForThisRestaurant(Map<String, dynamic> data) {
    final catRestId = (data['restaurant_id'] ?? '').toString().trim();
    final catUserId = (data['user_id'] ?? '').toString().trim();
    final catEmail = (data['email'] ?? data['owner_email'] ?? '').toString().trim().toLowerCase();
    final catRestName = (data['restaurant_name'] ?? '').toString().trim().toLowerCase();
    final catId = (data['category_id'] ?? data['cat_id'] ?? '').toString().trim();
    final targetName = widget.restaurantName.trim().toLowerCase();

    // If it has NO association at all, do NOT show it in any restaurant!
    if (catRestId.isEmpty && catUserId.isEmpty && catEmail.isEmpty && catRestName.isEmpty) {
      return false;
    }

    if ((catRestId.isNotEmpty && _restaurantMatchingKeys.contains(catRestId)) ||
        (catUserId.isNotEmpty && _restaurantMatchingKeys.contains(catUserId)) ||
        (catEmail.isNotEmpty && _restaurantMatchingKeys.contains(catEmail)) ||
        (catRestName.isNotEmpty && (catRestName == targetName || _restaurantMatchingKeys.contains(catRestName))) ||
        (catId.isNotEmpty && _restaurantCategoryIds.contains(catId))) {
      return true;
    }

    return false;
  }

  bool _isItemForThisRestaurant(Map<String, dynamic> data) {
    final itemRestId = (data['restaurant_id'] ?? '').toString().trim();
    final itemUserId = (data['user_id'] ?? '').toString().trim();
    final itemEmail = (data['email'] ?? data['owner_email'] ?? '').toString().trim().toLowerCase();
    final itemRestName = (data['restaurant_name'] ?? '').toString().trim().toLowerCase();
    final catId = (data['category_id'] ?? data['cat_id'] ?? '').toString().trim();
    final targetName = widget.restaurantName.trim().toLowerCase();

    // If it has NO association at all and its category is not associated, do NOT show it!
    if (itemRestId.isEmpty &&
        itemUserId.isEmpty &&
        itemEmail.isEmpty &&
        itemRestName.isEmpty &&
        (catId.isEmpty || !_restaurantCategoryIds.contains(catId))) {
      return false;
    }

    if ((itemRestId.isNotEmpty && _restaurantMatchingKeys.contains(itemRestId)) ||
        (itemUserId.isNotEmpty && _restaurantMatchingKeys.contains(itemUserId)) ||
        (itemEmail.isNotEmpty && _restaurantMatchingKeys.contains(itemEmail)) ||
        (itemRestName.isNotEmpty &&
            (itemRestName == targetName ||
                _restaurantMatchingKeys.contains(itemRestName))) ||
        (catId.isNotEmpty && _restaurantCategoryIds.contains(catId))) {
      return true;
    }

    return false;
  }

  void _incrementCart(Map<String, dynamic> item) {
    final String id = (item['item_id'] ?? item['prod_id'] ?? '').toString();
    final double price = (item['item_price'] as num?)?.toDouble() ?? 0.0;

    final newQtys = Map<String, int>.from(_cartQuantities.value);
    final newPrices = Map<String, double>.from(_cartPrices.value);
    final newItems =
        Map<String, Map<String, dynamic>>.from(_cartItemsData.value);

    newQtys[id] = (newQtys[id] ?? 0) + 1;
    newPrices[id] = price;
    newItems[id] = item;

    _cartQuantities.value = newQtys;
    _cartPrices.value = newPrices;
    _cartItemsData.value = newItems;
  }

  void _decrementCart(Map<String, dynamic> item) {
    final String id = (item['item_id'] ?? item['prod_id'] ?? '').toString();

    final newQtys = Map<String, int>.from(_cartQuantities.value);
    final newPrices = Map<String, double>.from(_cartPrices.value);
    final newItems =
        Map<String, Map<String, dynamic>>.from(_cartItemsData.value);

    final currentQty = newQtys[id] ?? 0;
    if (currentQty <= 1) {
      newQtys.remove(id);
      newPrices.remove(id);
      newItems.remove(id);
    } else {
      newQtys[id] = currentQty - 1;
    }

    _cartQuantities.value = newQtys;
    _cartPrices.value = newPrices;
    _cartItemsData.value = newItems;
  }

  void _setCartItemQuantity(Map<String, dynamic> item, int qty,
      [double? customPrice]) {
    final String id = (item['item_id'] ?? item['prod_id'] ?? '').toString();
    final double price =
        customPrice ?? ((item['item_price'] as num?)?.toDouble() ?? 0.0);

    final newQtys = Map<String, int>.from(_cartQuantities.value);
    final newPrices = Map<String, double>.from(_cartPrices.value);
    final newItems =
        Map<String, Map<String, dynamic>>.from(_cartItemsData.value);

    if (qty <= 0) {
      newQtys.remove(id);
      newPrices.remove(id);
      newItems.remove(id);
    } else {
      newQtys[id] = qty;
      newPrices[id] = price;
      newItems[id] = item;
    }

    _cartQuantities.value = newQtys;
    _cartPrices.value = newPrices;
    _cartItemsData.value = newItems;
  }

  Future<void> _openItemDetail(Map<String, dynamic> item) async {
    final String id = (item['item_id'] ?? item['prod_id'] ?? '').toString();
    final int currentQty = _cartQuantities.value[id] ?? 1;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          itemId: id,
          itemName: (item['item_name'] ?? item['prod_name'] ?? '').toString(),
          itemPrice: (item['item_price'] as num?)?.toDouble() ?? 0.0,
          itemImageUrl:
              (item['item_pic'] ?? item['prod_pic'] ?? '').toString(),
          itemDescription: (item['item_description'] ??
                  item['prod_desc'] ??
                  'Serves 1-2. Available in half & full. Fragrant basmati rice layered with tender marinated chicken cooked with aromatic spices.')
              .toString(),
          categoryId: (item['cat_id'] ?? '').toString(),
          categoryName: (item['cat_name'] ?? '').toString(),
          restaurantId: widget.restaurantId,
          restaurantName: widget.restaurantName,
          initialData: item,
          initialQuantity: currentQty,
        ),
      ),
    );

    if (result != null && result['added'] == true) {
      final int addedQty = (result['quantity'] as num?)?.toInt() ?? 1;
      final double finalPrice = (result['price'] as num?)?.toDouble() ??
          ((item['item_price'] as num?)?.toDouble() ?? 0.0);
      _setCartItemQuantity(item, addedQty, finalPrice);
    }
  }

  void _openCartCheckout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ValueListenableBuilder<Map<String, int>>(
          valueListenable: _cartQuantities,
          builder: (context, qtys, _) {
            final totalCount =
                qtys.values.fold(0, (total, qty) => total + qty);
            final double totalPrice = qtys.entries.fold(
              0.0,
              (total, entry) =>
                  total + (entry.value * (_cartPrices.value[entry.key] ?? 0.0)),
            );

            if (totalCount == 0) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('Your cart is empty',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(height: 20),
                  ],
                ),
              );
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Cart',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E2022),
                            ),
                          ),
                          Text(
                            widget.restaurantName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: qtys.entries.map((entry) {
                        final itemData = _cartItemsData.value[entry.key] ?? {};
                        final name = (itemData['item_name'] ??
                                itemData['prod_name'] ??
                                'Delicious Item')
                            .toString();
                        final price = _cartPrices.value[entry.key] ?? 0.0;
                        final qty = entry.value;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E2022),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Rs. ${price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.primaryPink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Capsule Button [ 🗑 or - | qty | + ]
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFE2E4E8),
                                    width: 1.2,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _decrementCart(itemData),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          qty == 1
                                              ? Icons.delete_outline_rounded
                                              : Icons.remove,
                                          size: 16,
                                          color: const Color(0xFF1E2022),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: Text(
                                        '$qty',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E2022),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _incrementCart(itemData),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.add,
                                          size: 16,
                                          color: Color(0xFF1E2022),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E2022),
                        ),
                      ),
                      Text(
                        'Rs. ${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryPink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please log in to place an order'),
                              backgroundColor: AppColors.primaryPink,
                            ),
                          );
                          return;
                        }

                        // Batch save orders to Firestore
                        for (final entry in qtys.entries) {
                          final item = _cartItemsData.value[entry.key] ?? {};
                          final name = (item['item_name'] ??
                                  item['prod_name'] ??
                                  'Food Item')
                              .toString();
                          final price = _cartPrices.value[entry.key] ?? 0.0;
                          final qty = entry.value;

                          final orderDocId =
                              '${user.uid}_${entry.key}_${DateTime.now().millisecondsSinceEpoch}';

                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(orderDocId)
                              .set({
                            'order_id': orderDocId,
                            'user_id': user.uid,
                            'user_email': user.email ?? '',
                            'user_name': user.displayName ?? 'Customer',
                            'item_id': entry.key,
                            'item_name': name,
                            'item_price': price,
                            'item_pic': (item['item_pic'] ??
                                    item['prod_pic'] ??
                                    item['imageUrl'] ??
                                    item['image_url'] ??
                                    item['item_image'] ??
                                    item['image'] ??
                                    item['pic'] ??
                                    item['photoUrl'] ??
                                    '')
                                .toString(),
                            'category_name': (item['cat_name'] ??
                                    item['category_name'] ??
                                    '')
                                .toString(),
                            'category_id': (item['cat_id'] ??
                                    item['category_id'] ??
                                    '')
                                .toString(),
                            'restaurant_id': widget.restaurantId,
                            'restaurant_name': widget.restaurantName,
                            'quantity': qty,
                            'total_price': price * qty,
                            'status': 'ordered',
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        }

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }

                        // Clear cart
                        _cartQuantities.value = {};
                        _cartPrices.value = {};
                        _cartItemsData.value = {};

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.editGreen,
                              content: const Text(
                                'Order placed successfully! Tracking live.',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                              action: SnackBarAction(
                                label: 'MY ORDERS',
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const UserOrdersScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Confirm & Place Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImage(
    String url, {
    required double width,
    required double height,
    required double borderRadius,
    String? fallbackName,
    String docId = '',
  }) {
    String finalUrl = url.trim();
    bool needsFallback = finalUrl.isEmpty;
    if (!needsFallback && !finalUrl.startsWith('http') && !finalUrl.startsWith('data:image') && finalUrl.length < 200) {
      try {
        if (!File(finalUrl).existsSync()) {
          needsFallback = true;
        }
      } catch (_) {
        needsFallback = true;
      }
    }

    if (needsFallback && fallbackName != null && fallbackName.isNotEmpty) {
      final nameLower = fallbackName.toLowerCase().trim();
      if (nameLower.contains('coffee') || nameLower.contains('cafe') || nameLower.contains('tea')) {
        finalUrl = 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=80';
      } else if (nameLower.contains('burger') || nameLower.contains('fast') || nameLower.contains('kfc') || nameLower.contains('crispy') || nameLower.contains('zinger')) {
        finalUrl = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop&q=80';
      } else if (nameLower.contains('pizza') || nameLower.contains('piza') || nameLower.contains('italian')) {
        finalUrl = 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=80';
      } else if (nameLower.contains('bbq') || nameLower.contains('meat') || nameLower.contains('grill') || nameLower.contains('steak') || nameLower.contains('tikka') || nameLower.contains('kabab')) {
        finalUrl = 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500&auto=format&fit=crop&q=80';
      } else if (nameLower.contains('biryani') || nameLower.contains('rice') || nameLower.contains('karahi') || nameLower.contains('desi') || nameLower.contains('spice') || nameLower.contains('curry') || nameLower.contains('handi')) {
        finalUrl = 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=500&auto=format&fit=crop&q=80';
      } else if (nameLower.contains('cake') || nameLower.contains('sweet') || nameLower.contains('baker') || nameLower.contains('dessert') || nameLower.contains('ice cream') || nameLower.contains('pastry')) {
        finalUrl = 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500&auto=format&fit=crop&q=80';
      } else if (nameLower.contains('drink') || nameLower.contains('shake') || nameLower.contains('juice') || nameLower.contains('beverage') || nameLower.contains('mojito')) {
        finalUrl = 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=500&auto=format&fit=crop&q=80';
      } else {
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
        final hash = (fallbackName + docId).hashCode.abs();
        finalUrl = curated[hash % curated.length];
      }
    }

    return AppNetworkImage(
      imageUrl: finalUrl,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fit: BoxFit.cover,
      fallbackIcon: Icons.restaurant_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final restId = widget.restaurantId.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.restaurantName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: AppColors.primaryPink,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                widget.location.isNotEmpty
                                    ? widget.location
                                    : 'Restaurant Menu',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Search Toggle Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isSearchVisible = !_isSearchVisible;
                          if (!_isSearchVisible) {
                            _searchController.clear();
                            _searchQuery = '';
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _isSearchVisible
                              ? AppColors.primaryPink
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isSearchVisible
                                ? AppColors.primaryPink
                                : AppColors.inputBorder,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isSearchVisible
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          color: _isSearchVisible
                              ? Colors.white
                              : AppColors.textDark,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // My Orders Button
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
                        width: 40,
                        height: 40,
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
                ],
              ),
            ),

            // Search Bar Input (Shown when search icon is active)
            if (_isSearchVisible)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryPink.withValues(alpha: 0.5),
                      width: 1.2,
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
                    autofocus: true,
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
                      hintText: 'Search dishes in ${widget.restaurantName}...',
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

            // Main Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant Hero Banner Card
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2022),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cover Image Banner with gradient & Logo Avatar
                            SizedBox(
                              height: 140,
                              width: double.infinity,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildImage(
                                    widget.logoImage,
                                    width: double.infinity,
                                    height: 140,
                                    borderRadius: 0,
                                    fallbackName: widget.restaurantName,
                                    docId: widget.restaurantId,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.4),
                                          Colors.black.withValues(alpha: 0.85),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                  // Logo Avatar & Rating overlaid at bottom of banner
                                  Positioned(
                                    bottom: 12,
                                    left: 14,
                                    right: 14,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: _buildImage(
                                              widget.logoImage,
                                              width: 52,
                                              height: 52,
                                              borderRadius: 0,
                                              fallbackName: widget.restaurantName,
                                              docId: widget.restaurantId,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            widget.restaurantName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: -0.3,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black,
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Rating Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFA000),
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.star_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                widget.rating > 0
                                                    ? widget.rating.toStringAsFixed(1)
                                                    : '4.9',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Restaurant Info Details under banner
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: AppColors.primaryPink,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          widget.location.isNotEmpty
                                              ? widget.location
                                              : 'Fast Delivery Available',
                                          style: const TextStyle(
                                            color: Color(0xFFB0B8C1),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFF4CAF50),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Text(
                                          'OPEN NOW',
                                          style: TextStyle(
                                            color: Color(0xFF81C784),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      if (widget.phone != null && widget.phone!.isNotEmpty) ...[
                                        const SizedBox(width: 10),
                                        Text(
                                          '📞 ${widget.phone}',
                                          style: const TextStyle(
                                            color: Color(0xFFB0B8C1),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (widget.description.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      widget.description,
                                      style: const TextStyle(
                                        color: Color(0xFFCED4DA),
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Categories Section Header & Horizontal Category Cards
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('categories')
                          .snapshots(),
                      builder: (context, catSnapshot) {
                        final allDocs = catSnapshot.data?.docs ?? [];
                        final matchingCats = allDocs.where((doc) {
                          return _isCategoryForThisRestaurant(doc.data());
                        }).toList();

                        final displayCats = matchingCats;

                        if (displayCats.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryPink,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Categories',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ValueListenableBuilder<_CategorySelectionData>(
                                    valueListenable: _selectedCategory,
                                    builder: (context, catSel, _) {
                                      final isFiltering = catSel.id != null ||
                                          catSel.ids.isNotEmpty;
                                      return TextButton(
                                        onPressed: () {
                                          _selectedCategory.value =
                                              const _CategorySelectionData();
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize
                                              .shrinkWrap,
                                        ),
                                        child: Text(
                                          isFiltering ? 'Clear Filter' : 'Show All',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isFiltering
                                                ? AppColors.primaryPink
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: displayCats.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return ValueListenableBuilder<_CategorySelectionData>(
                                      valueListenable: _selectedCategory,
                                      builder: (context, catSel, _) {
                                        final isAllSelected = catSel.id == null || catSel.id!.isEmpty;
                                        return GestureDetector(
                                          onTap: () {
                                            _selectedCategory.value =
                                                const _CategorySelectionData();
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isAllSelected
                                                  ? const Color(0xFF3D3730)
                                                  : const Color(0xFF222224),
                                              borderRadius: BorderRadius.circular(24),
                                              border: Border.all(
                                                color: isAllSelected
                                                    ? const Color(0xFF8D7B68).withValues(alpha: 0.7)
                                                    : const Color(0xFF333336),
                                                width: 1,
                                              ),
                                              boxShadow: isAllSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.25),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'All',
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: isAllSelected
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: isAllSelected
                                                      ? Colors.white
                                                      : const Color(0xFFB0B0B0),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }

                                  final catDoc = displayCats[index - 1];
                                  final data = catDoc.data();
                                  final docId = catDoc.id;
                                  final rawId = (data['category_id'] ??
                                          data['cat_id'] ??
                                          '')
                                      .toString()
                                      .trim();
                                  final name = (data['category_name'] ??
                                          data['cat_name'] ??
                                          data['name'] ??
                                          '')
                                      .toString();

                                  return ValueListenableBuilder<_CategorySelectionData>(
                                    valueListenable: _selectedCategory,
                                    builder: (context, catSel, _) {
                                      final isSelected = catSel.id != null &&
                                          (catSel.id == docId ||
                                              (catSel.name != null &&
                                                  catSel.name == name));

                                      return GestureDetector(
                                        onTap: () {
                                          if (isSelected) {
                                            _selectedCategory.value =
                                                const _CategorySelectionData();
                                          } else {
                                            _selectedCategory.value =
                                                _CategorySelectionData(
                                              id: docId,
                                              name: name,
                                              ids: {
                                                docId,
                                                if (rawId.isNotEmpty &&
                                                    rawId != restId)
                                                  rawId,
                                              },
                                            );
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF3D3730)
                                                : const Color(0xFF222224),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF8D7B68).withValues(alpha: 0.7)
                                                  : const Color(0xFF333336),
                                              width: 1,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.25),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Center(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFFB0B0B0),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),

                    // Menu Dishes Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPink,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ValueListenableBuilder<_CategorySelectionData>(
                                valueListenable: _selectedCategory,
                                builder: (context, catSel, _) {
                                  final title = (catSel.name != null &&
                                          catSel.name!.isNotEmpty)
                                      ? catSel.name!
                                      : 'Menu Dishes';
                                  return Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                      letterSpacing: -0.3,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Menu Dishes Items List
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('items')
                          .snapshots(),
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

                        final allDocs = itemSnapshot.data?.docs ?? [];
                        final matchingDocs = allDocs
                            .where(
                                (doc) => _isItemForThisRestaurant(doc.data()))
                            .toList();
                        final displayDocs = matchingDocs;

                        final restaurantItems = displayDocs.map((doc) {
                          final data = doc.data();
                          final priceVal = data['item_price'] ??
                              data['prod_price'] ??
                              0.0;
                          return {
                            'item_id': doc.id,
                            'item_name': (data['item_name'] ??
                                    data['prod_name'] ??
                                    '')
                                .toString(),
                            'item_price': priceVal is num
                                ? priceVal.toDouble()
                                : (double.tryParse(priceVal.toString()) ??
                                    0.0),
                            'item_description': (data['item_description'] ??
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
                                (data['original_price'] as num?)?.toDouble(),
                          };
                        }).toList();

                        return ValueListenableBuilder<_CategorySelectionData>(
                          valueListenable: _selectedCategory,
                          builder: (context, catSel, _) {
                            // Filter by Category and Search Query
                            final filteredItems = restaurantItems.where((item) {
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
                              final matchesCategory = catSel.id == null ||
                                  catSel.id!.isEmpty ||
                                  catSel.ids.contains(catId) ||
                                  catId == catSel.id ||
                                  (catSel.name != null &&
                                      catSel.name!.isNotEmpty &&
                                      catName.isNotEmpty &&
                                      catName ==
                                          catSel.name!.toLowerCase());

                              return matchesSearch && matchesCategory;
                            }).toList();

                            if (filteredItems.isEmpty) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 20),
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.inputBorder,
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
                                            ? 'No dishes matching "$_searchQuery"'
                                            : 'No dishes found in this category',
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

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.74,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final id = (item['item_id'] ?? '').toString();
                                final name =
                                    (item['item_name'] ?? '').toString();
                                final rawPrice = (item['item_price'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final discountPercent =
                                    (item['discount_percent'] as num?)
                                            ?.toDouble() ??
                                        0.0;
                                final rawOrigPrice =
                                    (item['original_price'] as num?)
                                            ?.toDouble() ??
                                        rawPrice;

                                final double displayOriginalPrice =
                                    (discountPercent > 0 && rawOrigPrice <= rawPrice)
                                        ? (rawOrigPrice > 0 ? rawOrigPrice : rawPrice)
                                        : rawOrigPrice;
                                final double displayFinalPrice = (discountPercent > 0)
                                    ? (rawOrigPrice > rawPrice && rawPrice > 0
                                        ? rawPrice
                                        : (displayOriginalPrice * (1.0 - (discountPercent / 100.0))))
                                    : rawPrice;
                                final pic = (item['item_pic'] ?? '').toString();
                                final desc =
                                    (item['item_description'] ?? '').toString();

                                return ValueListenableBuilder<Map<String, int>>(
                                  valueListenable: _cartQuantities,
                                  builder: (context, qtys, _) {
                                    final qty = qtys[id] ?? 0;
                                    final bool isInCart = qty > 0;

                                    return GestureDetector(
                                      onTap: () => _openItemDetail(item),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF222224),
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(
                                            color: isInCart
                                                ? const Color(0xFFC8A27A)
                                                : const Color(0xFF333336),
                                            width: isInCart ? 1.8 : 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                  alpha: isInCart ? 0.35 : 0.18),
                                              blurRadius: isInCart ? 12 : 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(21),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              // Atmospheric Background Dish Image
                                              _buildImage(
                                                pic,
                                                width: double.infinity,
                                                height: double.infinity,
                                                borderRadius: 21,
                                                fallbackName: name,
                                                docId: id,
                                              ),

                                              // Mood Gradient Overlay
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.black.withValues(alpha: 0.2),
                                                      Colors.black.withValues(alpha: 0.45),
                                                      Colors.black.withValues(alpha: 0.92),
                                                    ],
                                                    stops: const [0.0, 0.5, 1.0],
                                                  ),
                                                ),
                                              ),

                                              // Top-Left Icon (Sparkle/Star like screenshot)
                                              Positioned(
                                                top: 10,
                                                left: 10,
                                                child: Container(
                                                  padding: const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.45),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    isInCart
                                                        ? Icons.auto_awesome
                                                        : (discountPercent > 0
                                                            ? Icons.local_fire_department_rounded
                                                            : Icons.star_border_rounded),
                                                    color: isInCart
                                                        ? const Color(0xFFFFA000)
                                                        : Colors.white70,
                                                    size: 15,
                                                  ),
                                                ),
                                              ),

                                              // Top-Right Cart Action / Plus Button
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: qty == 0
                                                    ? GestureDetector(
                                                        onTap: () => _openItemDetail(item),
                                                        child: Container(
                                                          width: 32,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withValues(alpha: 0.6),
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                              color: Colors.white24,
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.add,
                                                              color: Colors.white,
                                                              size: 18,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : Container(
                                                        height: 30,
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF1E2022),
                                                          borderRadius: BorderRadius.circular(16),
                                                          border: Border.all(
                                                            color: const Color(0xFFC8A27A),
                                                            width: 1.2,
                                                          ),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            GestureDetector(
                                                              onTap: () => _decrementCart(item),
                                                              child: Padding(
                                                                padding: const EdgeInsets.all(2),
                                                                child: Icon(
                                                                  qty == 1
                                                                      ? Icons.delete_outline_rounded
                                                                      : Icons.remove,
                                                                  size: 14,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                                              child: Text(
                                                                '$qty',
                                                                style: const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w900,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                            GestureDetector(
                                                              onTap: () => _incrementCart(item),
                                                              child: const Padding(
                                                                padding: EdgeInsets.all(2),
                                                                child: Icon(
                                                                  Icons.add,
                                                                  size: 14,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                              ),

                                              // Bottom Text Overlay (Title & Subtitle/Price)
                                              Positioned(
                                                bottom: 12,
                                                left: 12,
                                                right: 12,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontSize: 14.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                        letterSpacing: -0.2,
                                                        shadows: [
                                                          Shadow(
                                                            color: Colors.black87,
                                                            blurRadius: 4,
                                                          ),
                                                        ],
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'Rs. ${displayFinalPrice.toStringAsFixed(0)}',
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w900,
                                                            color: Color(0xFFFFD54F),
                                                          ),
                                                        ),
                                                        if (discountPercent > 0) ...[
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Rs. ${displayOriginalPrice.toStringAsFixed(0)}',
                                                            style: const TextStyle(
                                                              fontSize: 10.5,
                                                              color: Color(0xFF9E9E9E),
                                                              decoration: TextDecoration.lineThrough,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      desc.isNotEmpty
                                                          ? desc
                                                          : 'Freshly prepared & delicious',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFFB0B0B0),
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Foodpanda Cart Bar
            ValueListenableBuilder<Map<String, int>>(
              valueListenable: _cartQuantities,
              builder: (context, qtys, _) {
                final totalCount =
                    qtys.values.fold(0, (total, qty) => total + qty);

                if (totalCount == 0) {
                  return const SizedBox.shrink();
                }

                final double totalPrice = qtys.entries.fold(
                  0.0,
                  (total, entry) =>
                      total +
                      (entry.value * (_cartPrices.value[entry.key] ?? 0.0)),
                );
                final double totalOriginalPrice = totalPrice * 1.11;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Green Promo Header
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF2E7D32),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "You've got 10% off your order!",
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: const LinearProgressIndicator(
                                  value: 1.0,
                                  backgroundColor: Color(0xFFE8F5E9),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2E7D32)),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Main Big Pink "View your cart" Bar
                        GestureDetector(
                          onTap: _openCartCheckout,
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPink,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPink
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Item Count Circle
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.6,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$totalCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title & Restaurant Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'View your cart',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        widget.restaurantName,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Prices
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Rs. ${totalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'Rs. ${totalOriginalPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                        fontSize: 11,
                                        decoration:
                                            TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
