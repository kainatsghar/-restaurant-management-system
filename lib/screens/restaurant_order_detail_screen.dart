import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/app_network_image.dart';

class RestaurantOrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> initialOrderData;

  const RestaurantOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.initialOrderData,
  });

  @override
  State<RestaurantOrderDetailScreen> createState() =>
      _RestaurantOrderDetailScreenState();
}

class _RestaurantOrderDetailScreenState
    extends State<RestaurantOrderDetailScreen> {
  bool _isUpdatingStatus = false;

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

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .set({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Status updated: "$newStatus"'),
              ],
            ),
            backgroundColor: AppColors.editGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
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
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AppNetworkImage(
              imageUrl: imgUrl,
              width: double.infinity,
              height: 220,
              borderRadius: 18,
              fit: BoxFit.cover,
              fallbackIcon: Icons.restaurant_menu_rounded,
            ),
          );
        }
        return _buildFallbackImage();
      },
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF26272E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFA4468).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          color: Color(0xFFFF5277),
          size: 64,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> data = widget.initialOrderData;
        if (snapshot.hasData && snapshot.data?.data() != null) {
          data = snapshot.data!.data()!;
        }

        final customerName = (data['user_name'] ?? data['customer_name'] ?? 'Customer').toString();
        final itemName = (data['item_name'] ?? data['name'] ?? 'Item Name').toString();

        final quantityRaw = data['quantity'] ?? 1;
        final int quantity = quantityRaw is num ? quantityRaw.toInt() : (int.tryParse(quantityRaw.toString()) ?? 1);

        final priceRaw = data['item_price'] ?? data['price'] ?? 0.0;
        final double itemPrice = priceRaw is num ? priceRaw.toDouble() : (double.tryParse(priceRaw.toString()) ?? 0.0);

        final totalRaw = data['total_price'] ?? (itemPrice * quantity);
        final double totalPrice = totalRaw is num ? totalRaw.toDouble() : (double.tryParse(totalRaw.toString()) ?? (itemPrice * quantity));

        final status = (data['status'] ?? 'ordered').toString();
        final statusColor = _getStatusColor(status);

        String orderTime = '';
        if (data['createdAt'] is Timestamp) {
          final dt = (data['createdAt'] as Timestamp).toDate();
          orderTime = '${dt.day}/${dt.month}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else if (data['updatedAt'] is Timestamp) {
          final dt = (data['updatedAt'] as Timestamp).toDate();
          orderTime = '${dt.day}/${dt.month}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Top Bar
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
                        'Order Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Item Picture Card
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF18191E),
                                Color(0xFF201620),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
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
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: _buildOrderItemImage(data),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 2. Main Item Details & Order Count Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF18191E),
                                Color(0xFF201620),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
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
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Item Name
                              Text(
                                itemName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              const SizedBox(height: 14),

                              // Item Price
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Item Price:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${itemPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Kitny Order (Quantity)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order Quantity:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFA4468).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFA4468).withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$quantity ${quantity == 1 ? "Item" : "Items"}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFF5277),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Total Price
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Bill:',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF5277),
                                    ),
                                  ),
                                ],
                              ),

                              if (customerName.isNotEmpty || orderTime.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Divider(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: 16,
                                          color: Colors.white.withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          customerName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (orderTime.isNotEmpty)
                                      Text(
                                        orderTime,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.white.withValues(alpha: 0.6),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 3. Status Action Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF18191E),
                                Color(0xFF201620),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
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
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Change Order Status:',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _statusChip('Ordered', const Color(0xFFFFA000), status),
                                  _statusChip('Preparing', const Color(0xFF1976D2), status),
                                  _statusChip('Ready', const Color(0xFF7B1FA2), status),
                                  _statusChip('Delivered', AppColors.editGreen, status),
                                  _statusChip('Cancelled', const Color(0xFFD32F2F), status),
                                ],
                              ),
                            ],
                          ),
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
    );
  }

  Widget _statusChip(String label, Color color, String currentStatus) {
    final bool isSelected = currentStatus.toLowerCase() == label.toLowerCase();
    return InkWell(
      onTap: _isUpdatingStatus ? null : () => _updateOrderStatus(label.toLowerCase()),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFF26272E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF383A42),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
