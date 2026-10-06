import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/image_service.dart';

class EditCategoryScreen extends StatefulWidget {
  final String categoryId;
  final String currentName;
  final String currentImageUrl;
  final String currentType;

  const EditCategoryScreen({
    super.key,
    required this.categoryId,
    required this.currentName,
    required this.currentImageUrl,
    this.currentType = '',
  });

  @override
  State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  final TextEditingController _specialTagController = TextEditingController();
  final TextEditingController _specialDiscountController = TextEditingController();
  bool _isSpecial = false;

  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  final List<String> _suggestedTypes = [
    'Special Deals',
    'Chef Special',
    'Fast Food',
    'Beverages',
    'Dessert',
    'Main Course',
    'Snacks',
    'Bakery',
    'Breakfast',
    'Pizza',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _typeController = TextEditingController(text: widget.currentType);
    _loadCategorySpecialData();
  }

  Future<void> _loadCategorySpecialData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.categoryId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _isSpecial = data['is_special'] == true;
            _specialTagController.text = (data['special_tag'] ?? '').toString();
            _specialDiscountController.text =
                (data['special_discount'] ?? '').toString();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading special data for category: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _specialTagController.dispose();
    _specialDiscountController.dispose();
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
    return await ImageService().uploadOrEncodeImage(
      imageFile: _pickedImage!,
      folder: 'categories',
      fileName: timestamp,
    );
  }

  Future<void> updateCategory() async {
    final name = _nameController.text.trim();
    final type = _typeController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter category name'),
          backgroundColor: AppColors.primaryPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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

      // If new image was chosen, upload it; otherwise keep current image
      String finalImageUrl = widget.currentImageUrl;
      if (_pickedImage != null) {
        finalImageUrl = await _uploadImage(timestamp);
      }

      // Update in Firebase Firestore with single clean keys
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.categoryId)
          .set({
        'category_name': name,
        'category_type': type.isNotEmpty ? type : (_isSpecial ? 'Special Deals' : 'General'),
        'cat_pic': finalImageUrl,
        'is_special': _isSpecial,
        'special_tag': _specialTagController.text.trim(),
        'special_discount': _specialDiscountController.text.trim(),
        'cat_id': FieldValue.delete(),
        'cat_name': FieldValue.delete(),
        'cat_type': FieldValue.delete(),
        'imageUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$name" updated successfully!'),
            backgroundColor: AppColors.editGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Update Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update Error: $e'),
            backgroundColor: AppColors.primaryPink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF1F5F2),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryPink,
                ),
              ),
            ),
          );
        },
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back Button "<" + Centered Title "Edit Category"
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
                      'Edit Category',
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

            // Form Content: Input Fields + Image Box + Update Button
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Name Field
                    const Text(
                      'Category Name',
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
                        decoration: InputDecoration(
                          hintText: 'Enter Category Name',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Category Type Field
                    const Text(
                      'Category Type',
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
                        controller: _typeController,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter or select category type',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Quick Selection Chips for Category Type
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedTypes.map((type) {
                        final isSelected = _typeController.text.trim() == type;
                        return ChoiceChip(
                          label: Text(
                            type,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textDark,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primaryPink,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primaryPink
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _typeController.text = selected ? type : '';
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ==========================================
                    // SPECIAL DEAL / SPECIAL LIST OPTION
                    // ==========================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isSpecial
                            ? AppColors.primaryPink.withValues(alpha: 0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isSpecial
                              ? AppColors.primaryPink
                              : Colors.black.withValues(alpha: 0.07),
                          width: _isSpecial ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isSpecial
                                ? AppColors.primaryPink.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _isSpecial
                                      ? AppColors.primaryPink
                                      : const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.local_fire_department_rounded,
                                  color: _isSpecial
                                      ? Colors.white
                                      : const Color(0xFFFFA000),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mark as Special Deal 🔥',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    Text(
                                      'Will appear in user Special Deals page',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _isSpecial,
                                activeTrackColor: AppColors.primaryPink,
                                onChanged: (val) {
                                  setState(() {
                                    _isSpecial = val;
                                    if (val && _typeController.text.isEmpty) {
                                      _typeController.text = 'Special Deals';
                                    }
                                  });
                                },
                              ),
                            ],
                          ),

                          if (_isSpecial) ...[
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),

                            // Special Tag Input (e.g. "20% OFF", "Chef Special")
                            const Text(
                              'Special Offer Tag (Optional)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.inputBorder,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _specialTagController,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 20% OFF, Chef Special, Hot Deal',
                                  hintStyle: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.discount_outlined,
                                    size: 18,
                                    color: AppColors.primaryPink,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Special Discount / Description
                            const Text(
                              'Special Details / Offer Description (Optional)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.inputBorder,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _specialDiscountController,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Free drink on order above Rs. 1000',
                                  hintStyle: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.stars_rounded,
                                    size: 18,
                                    color: AppColors.primaryPink,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Category Image Label
                    const Text(
                      'Category Image',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Gallery Image Box (Displays existing image or picked image)
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
                              color:
                                  AppColors.editGreen.withValues(alpha: 0.06),
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
                                    color: Colors.black
                                        .withValues(alpha: 0.65),
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

                    const SizedBox(height: 24),

                    // Full-width Pink Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : updateCategory,
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
                                'Update Category',
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
