import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';

class EditItemScreen extends StatefulWidget {
  final String itemId;
  final String currentName;
  final String currentCategoryId;
  final String currentCategoryName;
  final double currentPrice;
  final double? currentOriginalPrice;
  final double? currentDiscountPercent;
  final String currentDescription;
  final bool currentHasGroup;
  final String currentImageUrl;

  const EditItemScreen({
    super.key,
    required this.itemId,
    required this.currentName,
    required this.currentCategoryId,
    required this.currentCategoryName,
    required this.currentPrice,
    this.currentOriginalPrice,
    this.currentDiscountPercent,
    required this.currentDescription,
    required this.currentHasGroup,
    required this.currentImageUrl,
  });

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _discountController;
  final ImagePicker _picker = ImagePicker();

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  File? _pickedImage;
  bool _isLoading = false;

  List<Map<String, dynamic>> _categories = [];
  bool _isCategoriesLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);

    final double initialBasePrice = (widget.currentOriginalPrice != null && widget.currentOriginalPrice! > 0)
        ? widget.currentOriginalPrice!
        : widget.currentPrice;

    _priceController = TextEditingController(
      text: initialBasePrice > 0
          ? (initialBasePrice % 1 == 0
              ? initialBasePrice.toInt().toString()
              : initialBasePrice.toString())
          : '',
    );

    final double initialDiscount = widget.currentDiscountPercent ?? 0.0;
    _discountController = TextEditingController(
      text: initialDiscount > 0
          ? (initialDiscount % 1 == 0
              ? initialDiscount.toInt().toString()
              : initialDiscount.toString())
          : '0',
    );

    _priceController.addListener(_onPriceOrDiscountChanged);
    _discountController.addListener(_onPriceOrDiscountChanged);

    _selectedCategoryId = widget.currentCategoryId.isNotEmpty
        ? widget.currentCategoryId
        : null;
    _selectedCategoryName = widget.currentCategoryName;
    fetchCategories();
  }

  void _onPriceOrDiscountChanged() {
    setState(() {});
  }

  Future<void> fetchCategories() async {
    setState(() {
      _isCategoriesLoading = true;
    });
    try {
      final userIds = await AuthService().getCurrentRestaurantIds();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final snapshot =
          await FirebaseFirestore.instance.collection('categories').get();
      final List<Map<String, dynamic>> list = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final restId = (data['restaurant_id'] ?? '').toString();
            final userId = (data['user_id'] ?? '').toString();
            if (userIds.isEmpty && currentUid == null) return false;
            return userIds.contains(restId) ||
                userIds.contains(userId) ||
                (currentUid != null && restId == currentUid);
          })
          .map((doc) {
            final data = doc.data();
            final String rawCatId = (data['category_id'] ??
                    data['cat_id'] ??
                    '')
                .toString()
                .trim();
            final String catId = rawCatId.isNotEmpty ? rawCatId : doc.id;
            return <String, dynamic>{
              'doc_id': doc.id,
              'cat_id': catId,
              'cat_name': (data['category_name'] ??
                      data['cat_name'] ??
                      data['name'] ??
                      'Unnamed Category')
                  .toString(),
              'cat_pic':
                  (data['cat_pic'] ?? data['imageUrl'] ?? '').toString(),
            };
          }).toList();

      setState(() {
        _categories = list;
        _isCategoriesLoading = false;
        if (_selectedCategoryId != null && (_selectedCategoryName == null || _selectedCategoryName!.isEmpty)) {
          final matched = _categories.where((c) => c['cat_id'] == _selectedCategoryId || c['doc_id'] == _selectedCategoryId).firstOrNull;
          if (matched != null) {
            _selectedCategoryName = matched['cat_name'];
          }
        }
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      setState(() {
        _isCategoriesLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_onPriceOrDiscountChanged);
    _discountController.removeListener(_onPriceOrDiscountChanged);
    _nameController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<String> _uploadImage(String timestamp) async {
    if (_pickedImage == null) return widget.currentImageUrl;

    final metadata = SettableMetadata(contentType: 'image/jpeg');

    // 1. Try default Firebase Storage bucket
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('items')
          .child('$timestamp.jpg');
      final snapshot = await storageRef.putFile(_pickedImage!, metadata);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isNotEmpty) return downloadUrl;
    } catch (e) {
      debugPrint('Default storage bucket upload error: $e');
    }

    // 2. Try explicit legacy appspot bucket
    try {
      final storageRef = FirebaseStorage.instanceFor(
              bucket: 'fooddeliveryapp-fb8c1.appspot.com')
          .ref()
          .child('items')
          .child('$timestamp.jpg');
      final snapshot = await storageRef.putFile(_pickedImage!, metadata);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isNotEmpty) return downloadUrl;
    } catch (e) {
      debugPrint('Appspot storage bucket upload error: $e');
    }

    // 3. Fallback to local path
    return _pickedImage!.path;
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Item Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No categories found.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final cat = _categories[idx];
                      final name = (cat['cat_name'] ?? '').toString();
                      final docId = (cat['doc_id'] ?? '').toString();
                      final id = (cat['cat_id'] ?? '').toString();
                      final isSelected = _selectedCategoryId != null &&
                          _selectedCategoryId!.isNotEmpty &&
                          (_selectedCategoryId == id ||
                              _selectedCategoryId == docId);

                      return ListTile(
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primaryPink : AppColors.textDark,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryPink)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedCategoryId = docId.isNotEmpty ? docId : id;
                            _selectedCategoryName = name;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateItem() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter item name'),
          backgroundColor: AppColors.primaryPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String finalImageUrl = widget.currentImageUrl;
      if (_pickedImage != null) {
        finalImageUrl = await _uploadImage(timestamp);
      }

      // 1. Update in 'items' collection with strictly clean fields
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final restaurantId = await AuthService().getCurrentRestaurantId() ?? currentUid;
      final double originalPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final double discountPercent = double.tryParse(_discountController.text.trim()) ?? 0.0;
      final double finalSellingPrice = discountPercent > 0
          ? (originalPrice * (1.0 - (discountPercent / 100.0)))
          : originalPrice;

      final Map<String, dynamic> updateData = {
        'item_id': widget.itemId,
        'item_name': name,
        'item_price': double.parse(finalSellingPrice.toStringAsFixed(2)),
        'original_price': originalPrice,
        'discount_percent': discountPercent,
        'has_discount': discountPercent > 0,
        'discounted_price': double.parse(finalSellingPrice.toStringAsFixed(2)),
        'category_id': _selectedCategoryId ?? '',
        'category_name': _selectedCategoryName ?? '',
        'cat_id': FieldValue.delete(),
        'cat_name': FieldValue.delete(),
        'item_description': FieldValue.delete(),
      };
      if (restaurantId != null && restaurantId.isNotEmpty) {
        updateData['restaurant_id'] = restaurantId;
      }
      if (currentUid != null && currentUid.isNotEmpty) {
        updateData['user_id'] = currentUid;
      }
      if (finalImageUrl.isNotEmpty) {
        updateData['item_pic'] = finalImageUrl;
      }

      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.itemId)
          .set(updateData, SetOptions(merge: true));

      AuthService().cleanAllItemsCollection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item "$name" updated successfully!'),
            backgroundColor: AppColors.editGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Update Item Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating item: $e'),
            backgroundColor: AppColors.primaryPink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCurrentImageWidget() {
    if (_pickedImage != null) {
      return Image.file(
        _pickedImage!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }

    if (widget.currentImageUrl.isNotEmpty) {
      if (!widget.currentImageUrl.startsWith('http')) {
        final file = File(widget.currentImageUrl);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        }
      }

      return Image.network(
        widget.currentImageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 64,
          color: AppColors.editGreen,
        ),
        SizedBox(height: 10),
        Text(
          'Upload Image',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.editGreen,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Tap to select from gallery',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage =
        _pickedImage != null || widget.currentImageUrl.isNotEmpty;
    final double rawPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final double discountVal = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final double computedSellingPrice = discountVal > 0
        ? (rawPrice * (1.0 - (discountVal / 100.0)))
        : rawPrice;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textDark,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Edit Item',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Choose Category Picker
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showCategoryPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedCategoryName != null && _selectedCategoryName!.isNotEmpty
                                    ? _selectedCategoryName!
                                    : 'Choose Item Category',
                                style: TextStyle(
                                  color: _selectedCategoryName != null && _selectedCategoryName!.isNotEmpty
                                      ? AppColors.textDark
                                      : AppColors.textMuted.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: _selectedCategoryName != null && _selectedCategoryName!.isNotEmpty
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            _isCategoriesLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.editGreen,
                                    ),
                                  )
                                : const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.editGreen,
                                    size: 24,
                                  ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. Item Name
                    const Text(
                      'Item Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter Item Name',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 3. Item Price
                    const Text(
                      'Original Item Price (Rs.)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter Item Price (e.g. 247)',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            child: Text(
                              'Rs.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryPink,
                              ),
                            ),
                          ),
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 4. Special Discount (% Off) Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.discount_rounded, color: AppColors.primaryPink, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Discount % (Special Offer)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        if (discountVal > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPink.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${discountVal.toStringAsFixed(0)}% OFF ACTIVE',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryPink,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Discount Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [0, 5, 10, 15, 20, 25, 30, 50].map((percent) {
                          final isSelected = discountVal.toInt() == percent;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(
                                percent == 0 ? 'No Off (0%)' : '$percent% Off',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.white : AppColors.textDark,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primaryPink,
                              backgroundColor: Colors.white,
                              checkmarkColor: Colors.white,
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primaryPink
                                      : const Color(0xFFE2E4E8),
                                ),
                              ),
                              onSelected: (_) {
                                _discountController.text = percent.toString();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Custom Discount Input Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _discountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter discount percentage (e.g. 15)',
                          prefixIcon: const Icon(
                            Icons.percent_rounded,
                            color: AppColors.primaryPink,
                            size: 18,
                          ),
                          suffixText: '% OFF',
                          suffixStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryPink,
                            fontSize: 13,
                          ),
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    // Live Price Calculation Preview Card
                    if (rawPrice > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: discountVal > 0
                              ? const Color(0xFFFFF0F3)
                              : const Color(0xFFF8FAF9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: discountVal > 0
                                ? AppColors.primaryPink.withValues(alpha: 0.4)
                                : const Color(0xFFE2E4E8),
                            width: discountVal > 0 ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (discountVal > 0) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Original: Rs. ${rawPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                          decoration: TextDecoration.lineThrough,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryPink,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${discountVal.toStringAsFixed(0)}% off',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.editGreen,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Save Rs. ${(rawPrice - computedSellingPrice).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Customer Pays (Final Price):',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  'Rs. ${computedSellingPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryPink,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 5. Image Box
                    const Text(
                      'Item Image',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.editGreen.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.editGreen.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildCurrentImageWidget(),
                            ),
                            if (hasImage)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Change',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // 4. Pink Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPink,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Update Item',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
  }
}
