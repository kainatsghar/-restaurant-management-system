import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;
  final String itemName;
  final double itemPrice;
  final String itemImageUrl;
  final String itemDescription;
  final String? categoryId;
  final String? categoryName;
  final String? restaurantId;
  final String? restaurantName;
  final Map<String, dynamic>? initialData;
  final int initialQuantity;

  const ItemDetailScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.itemImageUrl,
    required this.itemDescription,
    this.categoryId,
    this.categoryName,
    this.restaurantId,
    this.restaurantName,
    this.initialData,
    this.initialQuantity = 1,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late int _quantity;
  String _selectedVariation = 'Full';

  // Order state
  bool _isProcessingOrder = false;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity > 0 ? widget.initialQuantity : 1;
  }

  // Add or update order in Firestore
  Future<void> _handleAddOrder({
    required String name,
    required double price,
    required String imageUrl,
    required String restId,
    required String catName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to add items to cart'),
            backgroundColor: AppColors.primaryPink,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    try {
      final orderDocId = _currentOrderId ??
          '${user.uid}_${widget.itemId}_${DateTime.now().millisecondsSinceEpoch}';

      final orderData = {
        'order_id': orderDocId,
        'user_id': user.uid,
        'user_email': user.email ?? '',
        'user_name': user.displayName ?? 'Customer',
        'item_id': widget.itemId,
        'item_name': name,
        'item_price': price,
        'item_pic': imageUrl,
        'restaurant_id': restId,
        'restaurant_name': widget.restaurantName ?? '',
        'category_name': catName,
        'variation': _selectedVariation,
        'quantity': _quantity,
        'total_price': price * _quantity,
        'status': 'ordered',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderDocId)
          .set(orderData, SetOptions(merge: true));

      _currentOrderId = orderDocId;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.editGreen,
            content: Text(
              'Added $_quantity x $name ($_selectedVariation) to cart!',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Pop back returning added status & quantity to update the restaurant screen immediately
        Navigator.of(context).pop({
          'added': true,
          'quantity': _quantity,
          'variation': _selectedVariation,
          'price': price,
        });
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: AppColors.primaryPink,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
  }

  Widget _buildImage(String url, {required double width, required double height}) {
    if (url.trim().isEmpty) {
      return _buildFallbackImage(width, height);
    }

    if (!url.startsWith('http')) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackImage(width, height),
        );
      }
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F2),
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryPink,
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildFallbackImage(width, height),
    );
  }

  Widget _buildFallbackImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFFFF0F3),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: AppColors.primaryPink.withValues(alpha: 0.7),
          size: 64,
        ),
      ),
    );
  }

  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .doc(widget.itemId)
          .snapshots(),
      builder: (context, snapshot) {
        final Map<String, dynamic> firestoreData = {
          if (widget.initialData != null) ...widget.initialData!,
          if (snapshot.hasData && snapshot.data?.data() != null)
            ...snapshot.data!.data()!,
        };

        final String name = (firestoreData['item_name'] ??
                firestoreData['prod_name'] ??
                widget.itemName)
            .toString();

        final priceVal = firestoreData['item_price'] ??
            firestoreData['prod_price'] ??
            widget.itemPrice;
        final double basePrice = priceVal is num
            ? priceVal.toDouble()
            : (double.tryParse(priceVal.toString()) ?? widget.itemPrice);

        final double discountPercent =
            (firestoreData['discount_percent'] as num?)?.toDouble() ?? 0.0;
        final double rawOriginalPrice =
            (firestoreData['original_price'] as num?)?.toDouble() ?? basePrice;

        double calculatedOriginalPrice;
        double calculatedFinalPrice;

        if (discountPercent > 0) {
          if (rawOriginalPrice > basePrice && basePrice > 0) {
            calculatedOriginalPrice = rawOriginalPrice;
            calculatedFinalPrice = basePrice;
          } else {
            calculatedOriginalPrice = rawOriginalPrice > 0 ? rawOriginalPrice : basePrice;
            calculatedFinalPrice = calculatedOriginalPrice * (1.0 - (discountPercent / 100.0));
          }
        } else {
          calculatedOriginalPrice = rawOriginalPrice > 0 ? rawOriginalPrice : basePrice;
          calculatedFinalPrice = basePrice;
        }

        final double fullPrice = calculatedFinalPrice;
        final double halfPrice = (calculatedFinalPrice * 0.6);
        final double currentSelectedPrice =
            _selectedVariation == 'Half' ? halfPrice : fullPrice;

        final double fullOriginalPrice = calculatedOriginalPrice;
        final double halfOriginalPrice = calculatedOriginalPrice * 0.6;
        final double selectedOriginalPrice =
            _selectedVariation == 'Half' ? halfOriginalPrice : fullOriginalPrice;

        final String imageUrl = (firestoreData['item_pic'] ??
                firestoreData['prod_pic'] ??
                widget.itemImageUrl)
            .toString();

        final String description = (firestoreData['item_description'] ??
                firestoreData['prod_desc'] ??
                widget.itemDescription)
            .toString();

        final String categoryName = (firestoreData['category_name'] ??
                firestoreData['cat_name'] ??
                widget.categoryName ??
                'Delicious Food')
            .toString();

        final String restaurantId = (firestoreData['restaurant_id'] ??
                widget.restaurantId ??
                '')
            .toString();

        final screenHeight = MediaQuery.of(context).size.height;
        final imageHeight = screenHeight * 0.44;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // 1. Food Image in the background (bottom layer)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: imageHeight + 30,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(
                      imageUrl,
                      width: double.infinity,
                      height: imageHeight + 30,
                    ),
                    // Subtle dark gradient from top and bottom for contrast
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Scrollable Body with Details Card overlapping on top of image
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Transparent space to reveal image
                      SizedBox(height: imageHeight - 24),

                      // Overlapping Details Card (Top Card)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card handle bar
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 12, bottom: 8),
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 10, 22, 100),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Category Tag & Info Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryPink
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.local_fire_department_rounded,
                                              color: AppColors.primaryPink,
                                              size: 15,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              categoryName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryPink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.grid_view_rounded,
                                          color: AppColors.textMuted,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // Item Name
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark,
                                      letterSpacing: -0.5,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Rating & Price Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFFFB800),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            '4.8',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '(120+ reviews)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (discountPercent > 0) ...[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Rs. ${selectedOriginalPrice.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: Color(0xFF888888),
                                                    decoration:
                                                        TextDecoration.lineThrough,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryPink
                                                        .withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${discountPercent.toStringAsFixed(0)}% off',
                                                    style: const TextStyle(
                                                      color: AppColors.primaryPink,
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                          ],
                                          Text(
                                            'Rs. ${currentSelectedPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primaryPink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),
                                  const Divider(color: Color(0xFFF1F3F5), height: 1),
                                  const SizedBox(height: 16),

                                  // Description
                                  const Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    description.isNotEmpty
                                        ? description
                                        : 'Freshly prepared with premium quality ingredients, special herbs, and rich savory flavors. Perfect meal to satisfy your hunger.',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF666666),
                                      height: 1.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),

                                  const SizedBox(height: 22),

                                  // Variation Section
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Portion Size',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE9ECEF),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Required',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF495057),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Full Option Card
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedVariation = 'Full';
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedVariation == 'Full'
                                            ? AppColors.primaryPink
                                                .withValues(alpha: 0.05)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _selectedVariation == 'Full'
                                              ? AppColors.primaryPink
                                              : AppColors.inputBorder,
                                          width: _selectedVariation == 'Full'
                                              ? 1.8
                                              : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Full Portion',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textDark,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Standard full serving',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (discountPercent > 0) ...[
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Rs. ${fullOriginalPrice.toStringAsFixed(0)}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFF888888),
                                                        decoration: TextDecoration
                                                            .lineThrough,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primaryPink
                                                            .withValues(alpha: 0.12),
                                                        borderRadius:
                                                            BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        '${discountPercent.toStringAsFixed(0)}% off',
                                                        style: const TextStyle(
                                                          fontSize: 9,
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
                                                'Rs. ${fullPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primaryPink,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _selectedVariation ==
                                                        'Full'
                                                    ? AppColors.primaryPink
                                                    : const Color(0xFFADB5BD),
                                                width: 2,
                                              ),
                                            ),
                                            child: _selectedVariation == 'Full'
                                                ? Center(
                                                    child: Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration:
                                                          const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: AppColors
                                                            .primaryPink,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Half Option Card
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedVariation = 'Half';
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedVariation == 'Half'
                                            ? AppColors.primaryPink
                                                .withValues(alpha: 0.05)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _selectedVariation == 'Half'
                                              ? AppColors.primaryPink
                                              : AppColors.inputBorder,
                                          width: _selectedVariation == 'Half'
                                              ? 1.8
                                              : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Half Portion',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textDark,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Individual smaller serving',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (discountPercent > 0) ...[
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Rs. ${halfOriginalPrice.toStringAsFixed(0)}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFF888888),
                                                        decoration: TextDecoration
                                                            .lineThrough,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primaryPink
                                                            .withValues(alpha: 0.12),
                                                        borderRadius:
                                                            BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        '${discountPercent.toStringAsFixed(0)}% off',
                                                        style: const TextStyle(
                                                          fontSize: 9,
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
                                                'Rs. ${halfPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primaryPink,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _selectedVariation ==
                                                        'Half'
                                                    ? AppColors.primaryPink
                                                    : const Color(0xFFADB5BD),
                                                width: 2,
                                              ),
                                            ),
                                            child: _selectedVariation == 'Half'
                                                ? Center(
                                                    child: Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration:
                                                          const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: AppColors
                                                            .primaryPink,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
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
              ),

              // 3. Floating Top Bar with Back & Favorite Buttons
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Favorite Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isFavorite = !_isFavorite;
                              });
                            },
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  _isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: _isFavorite
                                      ? const Color(0xFFFF3366)
                                      : Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Sticky Floating Bottom Bar with Qty Selector and Add to Cart
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        // Counter Box
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFE2E6EA),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: _quantity > 1
                                      ? AppColors.textDark
                                      : Colors.grey.shade400,
                                ),
                                onPressed: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  size: 16,
                                  color: AppColors.textDark,
                                ),
                                onPressed: () => setState(() => _quantity++),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Add to cart Button
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPink,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: _isProcessingOrder
                                  ? null
                                  : () => _handleAddOrder(
                                        name: name,
                                        price: currentSelectedPrice,
                                        imageUrl: imageUrl,
                                        restId: restaurantId,
                                        catName: categoryName,
                                      ),
                              child: _isProcessingOrder
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Add to Cart',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.7),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Rs. ${(currentSelectedPrice * _quantity).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white
                                                  .withValues(alpha: 0.95),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
