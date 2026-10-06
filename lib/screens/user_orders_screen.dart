import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'preparing':
      case 'in progress':
        return const Color(0xFF1976D2);
      case 'ready':
      case 'on the way':
        return const Color(0xFFF57C00);
      case 'completed':
      case 'delivered':
        return AppColors.editGreen;
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFD32F2F);
      case 'ordered':
      case 'pending':
      default:
        return const Color(0xFFE65100);
    }
  }

  Widget _buildImage(String url) {
    if (url.isEmpty) {
      return _buildFallbackImage();
    }
    if (!url.startsWith('http')) {
      final file = File(url);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            file,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackImage(),
          ),
        );
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackImage(),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: AppColors.textMuted,
          size: 32,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = AuthService().currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('My Orders', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          border: Border.all(color: AppColors.inputBorder),
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
                          size: 18,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'My Orders & Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 38), // Balance spacing
                ],
              ),
            ),

            // 2. Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.inputBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Search dishes, restaurant or status...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
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
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPink.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      size: 36,
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
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'When you order food from our restaurants, you can track it live here in real-time.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
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
                              final itemPic = (data['item_pic'] ?? data['imageUrl'] ?? '').toString();
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
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
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
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
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      status.toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: statusColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (orderTime.isNotEmpty)
                                                Text(
                                                  orderTime,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textMuted,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),
                                          const Divider(height: 1),
                                          const SizedBox(height: 12),

                                          // Dish Info Row
                                          Row(
                                            children: [
                                              _buildImage(itemPic),
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
                                                        color: AppColors.textDark,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (restaurantName.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        restaurantName,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors.primaryPink,
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
                                                        color: AppColors.textMuted,
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
                                                      color: AppColors.textMuted,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Rs. ${totalPrice.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.primaryPink,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // Bottom Track Live Button Row
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFB),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on_rounded, size: 16, color: statusColor),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      status.toLowerCase() == 'delivered'
                                                          ? 'Delivered to your address'
                                                          : 'Live tracking on GPS Map',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.textDark,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Row(
                                                  children: [
                                                    Text(
                                                      'Track',
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.primaryPink,
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    Icon(
                                                      Icons.arrow_forward_ios_rounded,
                                                      size: 12,
                                                      color: AppColors.primaryPink,
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
          color: isSelected ? AppColors.primaryPink : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryPink : AppColors.inputBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryPink.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
