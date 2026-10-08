import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';

class AddItemScreen extends StatefulWidget {
  final String? initialCategoryId;
  final String? initialCategoryName;

  const AddItemScreen({
    super.key,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
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
    _selectedCategoryId = widget.initialCategoryId;
    _selectedCategoryName = widget.initialCategoryName;
    _priceController.addListener(_onPriceOrDiscountChanged);
    _discountController.addListener(_onPriceOrDiscountChanged);
    fetchCategories();
    AuthService().cleanAllItemsCollection();
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
        if (_selectedCategoryId != null && _selectedCategoryName == null) {
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
    if (_pickedImage == null) return '';
    return await ImageService().uploadOrEncodeImage(
      imageFile: _pickedImage!,
      folder: 'items',
      fileName: timestamp,
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18191E),
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
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              if (_categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No categories found. Please add a category first.',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
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
                            color: isSelected ? const Color(0xFFFF5277) : Colors.white,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF5277))
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

  Future<void> _saveItem() async {
    final name = _nameController.text.trim();

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please choose a category'),
          backgroundColor: AppColors.primaryPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

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
      final String imageUrl = await _uploadImage(timestamp);
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUid = currentUser?.uid;
      final restaurantId = await AuthService().getCurrentRestaurantId() ?? currentUid ?? '';
      
      String restName = '';
      if (currentUid != null) {
        try {
          final rDoc = await FirebaseFirestore.instance
              .collection('restaurants')
              .doc(currentUid)
              .get();
          if (rDoc.exists && rDoc.data() != null) {
            restName = (rDoc.data()!['restaurant_name'] ??
                    rDoc.data()!['name'] ??
                    '')
                .toString();
          }
        } catch (_) {}
      }

      final double originalPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final double discountPercent = double.tryParse(_discountController.text.trim()) ?? 0.0;
      final double finalPrice = discountPercent > 0
          ? (originalPrice * (1.0 - (discountPercent / 100.0)))
          : originalPrice;

      final Map<String, dynamic> itemData = {
        'category_id': _selectedCategoryId ?? '',
        'category_name': _selectedCategoryName ?? '',
        'item_id': timestamp,
        'item_name': name,
        'item_price': double.parse(finalPrice.toStringAsFixed(2)),
        'original_price': originalPrice,
        'discount_percent': discountPercent,
        'has_discount': discountPercent > 0,
        'discounted_price': double.parse(finalPrice.toStringAsFixed(2)),
        'item_pic': imageUrl,
        'restaurant_id': restaurantId,
        'restaurant_name': restName,
        'user_id': currentUid ?? restaurantId,
        'email': currentUser?.email?.trim().toLowerCase() ?? '',
        'owner_email': currentUser?.email?.trim().toLowerCase() ?? '',
      };

      await FirebaseFirestore.instance
          .collection('items')
          .doc(timestamp)
          .set(itemData);

      // Auto clean all items collection
      AuthService().cleanAllItemsCollection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item "$name" saved successfully!'),
            backgroundColor: AppColors.editGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Save Item Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving item: $e'),
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

  @override
  Widget build(BuildContext context) {
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
            // Top Bar: Back Button "<" + Centered Title "Add New Items"
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
                      'Add New Items',
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

            // Form Content: Category + Name + Price + Discount + Image Box + Save Button
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
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFA4468).withValues(alpha: 0.08),
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
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.4),
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
                                      color: Color(0xFFFF5277),
                                    ),
                                  )
                                : const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Color(0xFFFF5277),
                                    size: 24,
                                  ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. Enter Item Name
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
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA4468).withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: const Color(0xFFFA4468),
                        decoration: InputDecoration(
                          hintText: 'Enter Item Name',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
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

                    // 3. Enter Original Item Price
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
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA4468).withValues(alpha: 0.08),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: const Color(0xFFFA4468),
                        decoration: InputDecoration(
                          hintText: 'Enter Item Price (e.g. 247)',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            child: Text(
                              'Rs.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF5277),
                              ),
                            ),
                          ),
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
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
                            Icon(Icons.discount_rounded, color: Color(0xFFFF5277), size: 18),
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
                              color: const Color(0xFFFA4468).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${discountVal.toStringAsFixed(0)}% OFF ACTIVE',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF5277),
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
                                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primaryPink,
                              backgroundColor: const Color(0xFF1B1C22),
                              checkmarkColor: Colors.white,
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primaryPink
                                      : const Color(0xFFFA4468).withValues(alpha: 0.3),
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
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA4468).withValues(alpha: 0.08),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: const Color(0xFFFA4468),
                        decoration: InputDecoration(
                          hintText: 'Enter discount percentage (e.g. 15)',
                          prefixIcon: const Icon(
                            Icons.percent_rounded,
                            color: Color(0xFFFF5277),
                            size: 18,
                          ),
                          suffixText: '% OFF',
                          suffixStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF5277),
                            fontSize: 13,
                          ),
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.5),
                                          decoration: TextDecoration.lineThrough,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFA4468)
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${discountVal.toStringAsFixed(0)}% off',
                                          style: const TextStyle(
                                            color: Color(0xFFFF5277),
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
                                      color: const Color(0xFF80BC24)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Save Rs. ${(rawPrice - computedSellingPrice).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Color(0xFF96D42A),
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
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Rs. ${computedSellingPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFF5277),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 5. Upload Image Box
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
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF18191E),
                              Color(0xFF201620),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFFA4468).withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFA4468).withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _pickedImage != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      _pickedImage!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.65),
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
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 56,
                                    color: Color(0xFFFF5277),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Upload Image',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFF5277),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to select from gallery',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // 4. Full-width Pink Save Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFA4468),
                            Color(0xFFFF6283),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA4468).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
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
                                'Save Item',
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
