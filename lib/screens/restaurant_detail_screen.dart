import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _loadRestaurantMatchingKeys();
  }

  Future<void> _loadRestaurantMatchingKeys() async {
    final Set<String> keys = {
      widget.restaurantId.trim(),
      widget.restaurantName.trim().toLowerCase(),
    };

    try {
      final snap =
          await FirebaseFirestore.instance.collection('restaurants').get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final docId = doc.id.trim();
        final restId = (d['restaurant_id'] ?? '').toString().trim();
        final uniqId = (d['unique_id'] ?? '').toString().trim();
        final uId = (d['user_id'] ?? '').toString().trim();
        final name = (d['restaurant_name'] ?? d['name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final matchesThisRest = docId == widget.restaurantId ||
            restId == widget.restaurantId ||
            uniqId == widget.restaurantId ||
            uId == widget.restaurantId ||
            (name.isNotEmpty &&
                name == widget.restaurantName.trim().toLowerCase());

        if (matchesThisRest) {
          if (docId.isNotEmpty) keys.add(docId);
          if (restId.isNotEmpty) keys.add(restId);
          if (uniqId.isNotEmpty) keys.add(uniqId);
          if (uId.isNotEmpty) keys.add(uId);
          if (name.isNotEmpty) keys.add(name);
        }
      }
    } catch (e) {
      debugPrint('Error loading restaurant keys: $e');
    }

    if (mounted) {
      setState(() {
        _restaurantMatchingKeys.addAll(keys);
      });
    }
  }

  bool _isCategoryForThisRestaurant(Map<String, dynamic> data) {
    final catRestId = (data['restaurant_id'] ?? '').toString().trim();
    final catUserId = (data['user_id'] ?? '').toString().trim();
    final catRestName =
        (data['restaurant_name'] ?? '').toString().trim().toLowerCase();

    if (catRestId.isEmpty && catUserId.isEmpty && catRestName.isEmpty) {
      return true;
    }

    if (_restaurantMatchingKeys.contains(catRestId) ||
        _restaurantMatchingKeys.contains(catUserId) ||
        _restaurantMatchingKeys.contains(catRestName) ||
        catRestId == widget.restaurantId ||
        catUserId == widget.restaurantId ||
        (catRestName.isNotEmpty &&
            catRestName == widget.restaurantName.trim().toLowerCase())) {
      return true;
    }

    return false;
  }

  bool _isItemForThisRestaurant(Map<String, dynamic> data) {
    final itemRestId = (data['restaurant_id'] ?? '').toString().trim();
    final itemUserId = (data['user_id'] ?? '').toString().trim();
    final itemRestName =
        (data['restaurant_name'] ?? '').toString().trim().toLowerCase();

    if (itemRestId.isEmpty && itemUserId.isEmpty && itemRestName.isEmpty) {
      return true;
    }

    if (_restaurantMatchingKeys.contains(itemRestId) ||
        _restaurantMatchingKeys.contains(itemUserId) ||
        _restaurantMatchingKeys.contains(itemRestName) ||
        itemRestId == widget.restaurantId ||
        itemUserId == widget.restaurantId ||
        (itemRestName.isNotEmpty &&
            itemRestName == widget.restaurantName.trim().toLowerCase())) {
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
                            'item_pic':
                                (item['item_pic'] ?? item['prod_pic'] ?? '')
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
          Icons.restaurant_rounded,
          color: AppColors.textMuted.withValues(alpha: 0.6),
          size: width * 0.4,
        ),
      ),
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
                    // Restaurant Hero Card
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E2022), Color(0xFF2C3440)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildImage(
                                widget.logoImage,
                                width: 64,
                                height: 64,
                                borderRadius: 16,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.restaurantName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: -0.3,
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
                                            color: const Color(0xFFFFA000)
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFFFA000),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.star_rounded,
                                                color: Color(0xFFFFA000),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                widget.rating > 0
                                                    ? widget.rating
                                                        .toStringAsFixed(1)
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
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: AppColors.primaryPink,
                                          size: 13,
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
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2E7D32)
                                                .withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                                        if (widget.phone != null &&
                                            widget.phone!.isNotEmpty) ...[
                                          const SizedBox(width: 8),
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (widget.description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              widget.description,
                              style: const TextStyle(
                                color: Color(0xFFCED4DA),
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
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

                        final displayCats = matchingCats.isNotEmpty
                            ? matchingCats
                            : allDocs;

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
                              height: 105,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: displayCats.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final catDoc = displayCats[index];
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
                                  final pic = (data['category_pic'] ??
                                          data['cat_pic'] ??
                                          data['image'] ??
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
                                        child: Container(
                                          width: 88,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primaryPink
                                                    .withValues(alpha: 0.08)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.primaryPink
                                                  : AppColors.inputBorder,
                                              width: isSelected ? 1.8 : 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.03),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _buildImage(
                                                pic,
                                                width: 48,
                                                height: 48,
                                                borderRadius: 12,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: isSelected
                                                      ? AppColors.primaryPink
                                                      : AppColors.textDark,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
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
                        final displayDocs =
                            matchingDocs.isNotEmpty ? matchingDocs : allDocs;

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

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
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

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.inputBorder,
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
                                      onTap: () => _openItemDetail(item),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Dish Info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.textDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  if (discountPercent > 0) ...[
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'Rs. ${displayOriginalPrice.toStringAsFixed(0)}',
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            color: Color(0xFF888888),
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
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors
                                                          .primaryPink,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    desc.isNotEmpty
                                                        ? desc
                                                        : 'Serves 1-2. Special delicious dish freshly prepared with premium ingredients.',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textMuted,
                                                      height: 1.35,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  const Row(
                                                    children: [
                                                      Text(
                                                        '🔥 Popular',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              Color(0xFFE65100),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            // Dish Image with Floating + or Capsule
                                            Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.bottomRight,
                                              children: [
                                                _buildImage(
                                                  pic,
                                                  width: 100,
                                                  height: 94,
                                                  borderRadius: 14,
                                                ),
                                                // Dynamic Capsule / + Button
                                                Positioned(
                                                  bottom: 4,
                                                  right: 4,
                                                  child: ValueListenableBuilder<
                                                      Map<String, int>>(
                                                    valueListenable:
                                                        _cartQuantities,
                                                    builder:
                                                        (context, qtys, _) {
                                                      final qty =
                                                          qtys[id] ?? 0;

                                                      if (qty == 0) {
                                                        // Single Circular + Button
                                                        return GestureDetector(
                                                          onTap: () =>
                                                              _openItemDetail(
                                                                  item),
                                                          child: Container(
                                                            width: 34,
                                                            height: 34,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.white,
                                                              shape: BoxShape
                                                                  .circle,
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                          alpha:
                                                                              0.2),
                                                                  blurRadius: 6,
                                                                  offset:
                                                                      const Offset(
                                                                          0, 2),
                                                                ),
                                                              ],
                                                            ),
                                                            child: const Center(
                                                              child: Icon(
                                                                Icons.add,
                                                                color: Color(
                                                                    0xFF1E2022),
                                                                size: 20,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }

                                                      // Expanded Pill Capsule [ 🗑 or - | qty | + ]
                                                      return Container(
                                                        height: 34,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(18),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                      alpha:
                                                                          0.2),
                                                              blurRadius: 6,
                                                              offset:
                                                                  const Offset(
                                                                      0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 4),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            GestureDetector(
                                                              onTap: () =>
                                                                  _decrementCart(
                                                                      item),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(4),
                                                                child: Icon(
                                                                  qty == 1
                                                                      ? Icons
                                                                          .delete_outline_rounded
                                                                      : Icons
                                                                          .remove,
                                                                  size: 16,
                                                                  color: const Color(
                                                                      0xFF1E2022),
                                                                ),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6),
                                                              child: Text(
                                                                '$qty',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  color: Color(
                                                                      0xFF1E2022),
                                                                ),
                                                              ),
                                                            ),
                                                            GestureDetector(
                                                              onTap: () =>
                                                                  _incrementCart(
                                                                      item),
                                                              child:
                                                                  const Padding(
                                                                padding:
                                                                    EdgeInsets
                                                                        .all(4),
                                                                child: Icon(
                                                                  Icons.add,
                                                                  size: 16,
                                                                  color: Color(
                                                                      0xFF1E2022),
                                                                ),
                                                             ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
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
