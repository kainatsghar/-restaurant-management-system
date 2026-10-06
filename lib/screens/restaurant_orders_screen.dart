import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'restaurant_order_detail_screen.dart';

class RestaurantOrdersScreen extends StatefulWidget {
  final String? filterItemId;
  final String? filterItemName;
  final String? filterRestaurantId;

  const RestaurantOrdersScreen({
    super.key,
    this.filterItemId,
    this.filterItemName,
    this.filterRestaurantId,
  });

  @override
  State<RestaurantOrdersScreen> createState() => _RestaurantOrdersScreenState();
}

class _RestaurantOrdersScreenState extends State<RestaurantOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  bool _filterByThisItemOnly = false;
  List<String> _restaurantIds = [];

  @override
  void initState() {
    super.initState();
    _filterByThisItemOnly = widget.filterItemId != null && widget.filterItemId!.isNotEmpty;
    _loadRestaurantIds();
  }

  Future<void> _loadRestaurantIds() async {
    final ids = await AuthService().getCurrentRestaurantIds();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (widget.filterRestaurantId != null &&
        widget.filterRestaurantId!.isNotEmpty &&
        !ids.contains(widget.filterRestaurantId!)) {
      ids.add(widget.filterRestaurantId!);
    }
    if (currentUid != null && !ids.contains(currentUid)) {
      ids.add(currentUid);
    }
    if (mounted) {
      setState(() {
        _restaurantIds = ids;
      });
    }
  }

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
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackImage(),
          ),
        );
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackImage(),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: AppColors.textMuted,
          size: 26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Bar
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
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Orders',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (widget.filterItemName != null &&
                            widget.filterItemName!.isNotEmpty &&
                            _filterByThisItemOnly)
                          Text(
                            'Item: ${widget.filterItemName}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.primaryPink,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (widget.filterItemId != null &&
                      widget.filterItemId!.isNotEmpty)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _filterByThisItemOnly = !_filterByThisItemOnly;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _filterByThisItemOnly
                              ? AppColors.primaryPink.withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _filterByThisItemOnly
                                ? AppColors.primaryPink
                                : AppColors.inputBorder,
                          ),
                        ),
                        child: Text(
                          _filterByThisItemOnly ? 'All Dishes' : 'This Item',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _filterByThisItemOnly
                                ? AppColors.primaryPink
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. Search & Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
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
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search customer name, item, or order ID...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
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
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // 3. Status Filter Chips
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _statusFilterChip('All'),
                  _statusFilterChip('Ordered'),
                  _statusFilterChip('Preparing'),
                  _statusFilterChip('Ready'),
                  _statusFilterChip('Delivered'),
                  _statusFilterChip('Cancelled'),
                ],
              ),
            ),

            // 4. Live Orders Stream & List
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryPink,
                      ),
                    );
                  }

                  final allOrders = snapshot.data?.docs ?? [];

                  // Filter orders belonging to this restaurant
                  final matchingOrders = allOrders.where((doc) {
                    final data = doc.data();
                    final restId = (data['restaurant_id'] ?? '').toString();
                    final itemRestId = (data['rest_id'] ?? '').toString();

                    final matchesRest = (currentUid != null && restId == currentUid) ||
                        _restaurantIds.contains(restId) ||
                        _restaurantIds.contains(itemRestId);

                    if (!matchesRest) {
                      return false;
                    }

                    if (_filterByThisItemOnly &&
                        widget.filterItemId != null &&
                        widget.filterItemId!.isNotEmpty) {
                      final docItemId = (data['item_id'] ?? '').toString();
                      if (docItemId != widget.filterItemId) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

                  // Sort by most recent first
                  matchingOrders.sort((a, b) {
                    final aTime = a.data()['createdAt'] ?? a.data()['updatedAt'];
                    final bTime = b.data()['createdAt'] ?? b.data()['updatedAt'];
                    if (aTime is Timestamp && bTime is Timestamp) {
                      return bTime.compareTo(aTime);
                    }
                    return 0;
                  });

                  // Apply search and status filters
                  final filteredOrders = matchingOrders.where((doc) {
                    final data = doc.data();
                    final name = (data['user_name'] ?? data['customer_name'] ?? '').toString().toLowerCase();
                    final itemName = (data['item_name'] ?? '').toString().toLowerCase();
                    final orderId = doc.id.toLowerCase();
                    final status = (data['status'] ?? 'ordered').toString().toLowerCase();

                    final matchesSearch = _searchQuery.isEmpty ||
                        name.contains(_searchQuery.toLowerCase().trim()) ||
                        itemName.contains(_searchQuery.toLowerCase().trim()) ||
                        orderId.contains(_searchQuery.toLowerCase().trim());

                    final matchesStatus = _selectedStatusFilter == 'All' ||
                        status == _selectedStatusFilter.toLowerCase();

                    return matchesSearch && matchesStatus;
                  }).toList();

                  if (filteredOrders.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPink.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 48,
                                color: AppColors.primaryPink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No orders found matching "$_searchQuery"'
                                  : (_selectedStatusFilter != 'All'
                                      ? 'No $_selectedStatusFilter orders'
                                      : 'No orders placed yet'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Customer orders for your restaurant dishes will appear here live.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Summary counts
                  double totalRevenue = 0.0;
                  for (final doc in matchingOrders) {
                    final d = doc.data();
                    final p = d['total_price'] ?? d['item_price'] ?? 0.0;
                    if (p is num) totalRevenue += p.toDouble();
                  }

                  return Column(
                    children: [
                      // Header Stats Counter Banner
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF1F3F5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.primaryPink),
                                const SizedBox(width: 6),
                                Text(
                                  '${filteredOrders.length} ${filteredOrders.length == 1 ? 'Order' : 'Orders'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Total: Rs. ${totalRevenue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryPink,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final doc = filteredOrders[index];
                            final data = doc.data();
                            final orderDocId = doc.id;

                            final customerName = (data['user_name'] ?? data['customer_name'] ?? 'Customer').toString();
                            final itemName = (data['item_name'] ?? 'Dish').toString();
                            final itemPic = (data['item_pic'] ?? data['imageUrl'] ?? '').toString();
                            final categoryName = (data['category_name'] ?? '').toString();

                            final qtyRaw = data['quantity'] ?? 1;
                            final int quantity = qtyRaw is num ? qtyRaw.toInt() : (int.tryParse(qtyRaw.toString()) ?? 1);

                            final priceRaw = data['item_price'] ?? 0.0;
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
                              margin: const EdgeInsets.only(bottom: 12),
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
                                        builder: (_) => RestaurantOrderDetailScreen(
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
                                        // Header Row: Status Badge & Time
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: statusColor,
                                                ),
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
                                        const SizedBox(height: 10),
                                        const Divider(height: 1),
                                        const SizedBox(height: 10),

                                        // Item & Customer Info Row
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
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textDark,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (categoryName.isNotEmpty) ...[
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      categoryName,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors.primaryPink,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.textMuted),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          customerName,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: AppColors.textMuted,
                                                            fontWeight: FontWeight.w600,
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
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F3F5),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Qty: $quantity',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textDark,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Rs. ${totalPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.primaryPink,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusFilterChip(String label) {
    final bool isSelected = _selectedStatusFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatusFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPink : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryPink : AppColors.inputBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryPink.withValues(alpha: 0.3),
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
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
