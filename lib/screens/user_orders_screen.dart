import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'order_tracking_screen.dart';
import 'profile_screen.dart';
import 'special_list_screen.dart';
import 'user_restaurants_screen.dart';

class UserOrdersScreen extends StatefulWidget {
  const UserOrdersScreen({super.key});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, ACTIVE, DELIVERED, CANCELLED

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteOrder(String orderDocId, String itemName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.primaryPink.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryPink.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.primaryPink,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Cancel & Delete Order',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel and delete your order for "$itemName"? This order will be permanently deleted from your records.',
          style: const TextStyle(
            fontSize: 13.5,
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'No, Keep',
              style: TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(orderDocId)
                    .delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Order for "$itemName" cancelled and deleted.',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1E1F24),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.primaryPink.withValues(alpha: 0.3),
                        ),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete order: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Yes, Cancel & Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'preparing':
      case 'in progress':
        return const Color(0xFF2979FF);
      case 'ready':
      case 'on the way':
        return const Color(0xFFFF9100);
      case 'completed':
      case 'delivered':
        return const Color(0xFF00E676);
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFFF5252);
      case 'ordered':
      case 'pending':
      default:
        return const Color(0xFFFF6D00);
    }
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF26272E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: AppColors.primaryPink.withValues(alpha: 0.7),
          size: 30,
        ),
      ),
    );
  }

  bool _isUsableImage(String str) {
    final clean = str.trim();
    if (clean.isEmpty) return false;
    if (clean.startsWith('http://') || clean.startsWith('https://')) return true;
    if (clean.startsWith('data:image') || clean.length > 200) return true;
    try {
      final f = File(clean);
      return f.existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveExactOrderItemImage(Map<String, dynamic> data) async {
    // 1. Direct picture in order document
    final String directPic = (
      data['item_pic'] ??
      data['prod_pic'] ??
      data['imageUrl'] ??
      data['image_url'] ??
      data['item_image'] ??
      data['image'] ??
      data['pic'] ??
      data['photoUrl'] ??
      data['product_pic'] ??
      data['img'] ??
      ''
    ).toString().trim();

    if (_isUsableImage(directPic)) {
      return directPic;
    }

    final String itemId = (data['item_id'] ?? data['prod_id'] ?? data['id'] ?? '').toString().trim();
    final String itemName = (data['item_name'] ?? data['name'] ?? data['prod_name'] ?? '').toString().trim();

    // 2. Fetch by Item ID in 'items' collection
    if (itemId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('items').doc(itemId).get();
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      // Try 'products' collection
      try {
        final doc = await FirebaseFirestore.instance.collection('products').doc(itemId).get();
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      // Query where item_id == itemId
      try {
        final q = await FirebaseFirestore.instance.collection('items').where('item_id', isEqualTo: itemId).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      // Query where prod_id == itemId
      try {
        final q = await FirebaseFirestore.instance.collection('products').where('prod_id', isEqualTo: itemId).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}
    }

    // 3. Fetch by Item Name in 'items' or 'products'
    if (itemName.isNotEmpty) {
      try {
        final q = await FirebaseFirestore.instance.collection('items').where('item_name', isEqualTo: itemName).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      try {
        final q = await FirebaseFirestore.instance.collection('products').where('prod_name', isEqualTo: itemName).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      // Scan items collection for case-insensitive match
      try {
        final snap = await FirebaseFirestore.instance.collection('items').get();
        final lowerName = itemName.toLowerCase().trim();
        for (final doc in snap.docs) {
          final d = doc.data();
          final dName = (d['item_name'] ?? d['prod_name'] ?? d['name'] ?? '').toString().toLowerCase().trim();
          if (dName == lowerName || (dName.isNotEmpty && (dName.contains(lowerName) || lowerName.contains(dName)))) {
            final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
            if (_isUsableImage(p)) return p;
          }
        }
      } catch (_) {}
    }

    // 4. Try Category if available
    final String catId = (data['category_id'] ?? data['cat_id'] ?? '').toString().trim();
    final String catName = (data['category_name'] ?? data['cat_name'] ?? '').toString().trim();
    if (catId.isNotEmpty) {
      try {
        final cDoc = await FirebaseFirestore.instance.collection('categories').doc(catId).get();
        if (cDoc.exists && cDoc.data() != null) {
          final d = cDoc.data()!;
          final p = (d['cat_pic'] ?? d['category_pic'] ?? d['imageUrl'] ?? d['image'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}
    }

    if (catName.isNotEmpty) {
      try {
        final cSnap = await FirebaseFirestore.instance.collection('categories').where('category_name', isEqualTo: catName).limit(1).get();
        if (cSnap.docs.isNotEmpty) {
          final d = cSnap.docs.first.data();
          final p = (d['cat_pic'] ?? d['category_pic'] ?? d['imageUrl'] ?? d['image'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}
    }

    if (directPic.isNotEmpty) return directPic;
    return null;
  }

  Widget _buildOrderItemImage(Map<String, dynamic> data) {
    return FutureBuilder<String?>(
      future: _resolveExactOrderItemImage(data),
      builder: (context, snapshot) {
        final String imgUrl = snapshot.data ?? '';
        if (imgUrl.isNotEmpty) {
          return Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryPink.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: AppNetworkImage(
              imageUrl: imgUrl,
              width: 72,
              height: 72,
              borderRadius: 14,
              fit: BoxFit.cover,
              fallbackIcon: Icons.fastfood_rounded,
            ),
          );
        }
        return _buildFallbackImage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = AuthService().currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1F24),
          elevation: 0,
          title: const Text('My Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryPink),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('Please sign in to view your orders.', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          color: const Color(0xFF1E1F24),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF2E313C),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: AppColors.primaryPink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'My Orders & Tracking',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 46,
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
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 13.5, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search dishes, restaurant or status...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8E92A0)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryPink),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white60),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 3. Live Stream of User Orders
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('user_id', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryPink),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading orders: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final allDocs = snapshot.data?.docs ?? [];

                  // Sort client-side by date descending
                  final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(allDocs);
                  sortedDocs.sort((a, b) {
                    final aTime = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    final bTime = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    return bTime.compareTo(aTime);
                  });

                  // Calculate stats
                  int activeCount = 0;
                  int deliveredCount = 0;

                  for (final doc in sortedDocs) {
                    final data = doc.data();
                    final st = (data['status'] ?? 'ordered').toString().toLowerCase();

                    if (st == 'delivered' || st == 'completed') {
                      deliveredCount++;
                    } else if (st != 'cancelled' && st != 'rejected') {
                      activeCount++;
                    }
                  }

                  // Apply Filter
                  final filteredDocs = sortedDocs.where((doc) {
                    final data = doc.data();
                    final st = (data['status'] ?? 'ordered').toString().toLowerCase();
                    final itemName = (data['item_name'] ?? data['name'] ?? '').toString().toLowerCase();
                    final restName = (data['restaurant_name'] ?? '').toString().toLowerCase();

                    // Search query match
                    if (_searchQuery.isNotEmpty) {
                      final matchSearch = itemName.contains(_searchQuery) ||
                          restName.contains(_searchQuery) ||
                          st.contains(_searchQuery);
                      if (!matchSearch) return false;
                    }

                    // Tab filter match
                    if (_selectedFilter == 'ACTIVE') {
                      return st == 'ordered' || st == 'pending' || st == 'preparing' || st == 'ready' || st == 'in progress' || st == 'on the way';
                    } else if (_selectedFilter == 'DELIVERED') {
                      return st == 'delivered' || st == 'completed';
                    } else if (_selectedFilter == 'CANCELLED') {
                      return st == 'cancelled' || st == 'rejected';
                    }
                    return true;
                  }).toList();

                  return Column(
                    children: [
                      // Filter Chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterChip('ALL', 'All (${sortedDocs.length})'),
                              const SizedBox(width: 8),
                              _buildFilterChip('ACTIVE', 'Active ($activeCount)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('DELIVERED', 'Delivered ($deliveredCount)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('CANCELLED', 'Cancelled'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (filteredDocs.isEmpty)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1A1B20),
                                      Color(0xFF261822),
                                      Color(0xFF381420),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
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
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryPink.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.primaryPink.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        size: 32,
                                        color: AppColors.primaryPink,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No matching orders found'
                                          : _selectedFilter == 'ACTIVE'
                                              ? 'No Active Orders'
                                              : 'No orders placed yet',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'When you order food from our restaurants, you can track it live here in real-time.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      height: 42,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).pushAndRemoveUntil(
                                            MaterialPageRoute(builder: (_) => const UserRestaurantsScreen()),
                                            (route) => false,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryPink,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                                        label: const Text('Browse Food Menu', style: TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data();
                              final orderDocId = doc.id;

                              final itemName = (data['item_name'] ?? data['name'] ?? 'Dish').toString();
                              final restaurantName = (data['restaurant_name'] ?? 'Restaurant').toString();

                              final qtyRaw = data['quantity'] ?? 1;
                              final int quantity = qtyRaw is num ? qtyRaw.toInt() : (int.tryParse(qtyRaw.toString()) ?? 1);

                              final priceRaw = data['item_price'] ?? data['price'] ?? 0.0;
                              final double itemPrice = priceRaw is num ? priceRaw.toDouble() : (double.tryParse(priceRaw.toString()) ?? 0.0);

                              final totalRaw = data['total_price'] ?? (itemPrice * quantity);
                              final double totalPrice = totalRaw is num ? totalRaw.toDouble() : (double.tryParse(totalRaw.toString()) ?? (itemPrice * quantity));

                              final status = (data['status'] ?? 'ordered').toString();
                              final statusColor = _getStatusColor(status);

                              String orderTime = '';
                              if (data['createdAt'] is Timestamp) {
                                final dt = (data['createdAt'] as Timestamp).toDate();
                                orderTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} • ${dt.day}/${dt.month}/${dt.year}';
                              } else if (data['updatedAt'] is Timestamp) {
                                final dt = (data['updatedAt'] as Timestamp).toDate();
                                orderTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} • ${dt.day}/${dt.month}/${dt.year}';
                              }

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
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => OrderTrackingScreen(
                                            orderId: orderDocId,
                                            initialOrderData: data,
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(18),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Status Header & Time
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: statusColor.withValues(alpha: 0.35),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 7,
                                                      height: 7,
                                                      decoration: BoxDecoration(
                                                        color: statusColor,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: statusColor.withValues(alpha: 0.6),
                                                            blurRadius: 4,
                                                            spreadRadius: 1,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      status.toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: statusColor,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (orderTime.isNotEmpty)
                                                    Text(
                                                      orderTime,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white60,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  const SizedBox(width: 8),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () => _confirmDeleteOrder(
                                                          orderDocId, itemName),
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF2C1920),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: AppColors.deleteIcon.withValues(alpha: 0.35),
                                                            width: 0.8,
                                                          ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.delete_outline_rounded,
                                                          size: 17,
                                                          color: AppColors.deleteIcon,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),
                                          Divider(height: 1, color: const Color(0xFF2E313C).withValues(alpha: 0.7)),
                                          const SizedBox(height: 12),

                                          // Dish Info Row
                                          Row(
                                            children: [
                                              _buildOrderItemImage(data),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      itemName,
                                                      style: const TextStyle(
                                                        fontSize: 15.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.white,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (restaurantName.isNotEmpty) ...[
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        restaurantName,
                                                        style: const TextStyle(
                                                          fontSize: 12.5,
                                                          color: Color(0xFFFF6584),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Rs. ${itemPrice.toStringAsFixed(2)} × $quantity',
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  const Text(
                                                    'Total Bill',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white60,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Rs. ${totalPrice.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFFFF5277),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // Bottom Track Live Button Row
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF141518),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFF2A2B33),
                                                width: 0.9,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.location_on_rounded, size: 15, color: statusColor),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    status.toLowerCase() == 'delivered'
                                                        ? 'Delivered'
                                                        : 'Live GPS Map',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () => _confirmDeleteOrder(
                                                        orderDocId, itemName),
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 4.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF2E1922),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: AppColors.deleteIcon.withValues(alpha: 0.35),
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.cancel_outlined,
                                                            size: 13,
                                                            color: AppColors.deleteIcon,
                                                          ),
                                                          SizedBox(width: 3),
                                                          Text(
                                                            'Cancel',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w700,
                                                              color: AppColors.deleteIcon,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 9, vertical: 4.5),
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [Color(0xFFFA4468), Color(0xFFFF6584)],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 1),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Track',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      SizedBox(width: 3),
                                                      Icon(
                                                        Icons.arrow_forward_ios_rounded,
                                                        size: 9,
                                                        color: Colors.white,
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
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 2,
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
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SpecialListScreen()),
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

  Widget _buildFilterChip(String filterKey, String label) {
    final bool isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? null : const Color(0xFF1E1F24),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFA4468), Color(0xFFFF6584)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFA4468) : const Color(0xFF2E313C),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}
