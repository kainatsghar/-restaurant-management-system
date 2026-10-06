import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/search_bar_widget.dart';
import 'add_subcategory_screen.dart';
import 'edit_subcategory_screen.dart';

class ProductSubcategoriesScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String? productImageUrl;

  const ProductSubcategoriesScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.productImageUrl,
  });

  @override
  State<ProductSubcategoriesScreen> createState() =>
      _ProductSubcategoriesScreenState();
}

class _ProductSubcategoriesScreenState
    extends State<ProductSubcategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (_isSearchFocused != _searchFocusNode.hasFocus) {
        setState(() {
          _isSearchFocused = _searchFocusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openAddSubcategory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddSubcategoryScreen(
          productId: widget.productId,
          productName: widget.productName,
        ),
      ),
    );
  }

  void _editSubcategory({
    required String id,
    required String currentName,
    required String currentPic,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditSubcategoryScreen(
          productId: widget.productId,
          subcategoryId: id,
          currentName: currentName,
          currentImageUrl: currentPic,
        ),
      ),
    );
  }

  void _deleteSubcategory(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Subcategory'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FirebaseFirestore.instance
                  .collection('items')
                  .doc(widget.productId)
                  .collection('subcategories')
                  .doc(id)
                  .delete();
              try {
                await FirebaseFirestore.instance
                    .collection('products')
                    .doc(widget.productId)
                    .collection('subcategories')
                    .doc(id)
                    .delete();
              } catch (_) {}
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Subcategory "$name" deleted'),
                    backgroundColor: AppColors.textDark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardImage(String url) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFFEBF2EE),
        child: const Center(
          child: Icon(
            Icons.icecream_rounded,
            color: AppColors.textMuted,
            size: 34,
          ),
        ),
      );
    }

    if (!url.startsWith('http')) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackCardImage(),
        );
      }
    }

    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackCardImage(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFF1F5F2),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryPink,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackCardImage() {
    return Container(
      color: const Color(0xFFEBF2EE),
      child: const Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: AppColors.textMuted,
          size: 34,
        ),
      ),
    );
  }

  Widget _buildSearchThumbnail(String url) {
    if (url.isEmpty) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.icecream_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ),
      );
    }

    if (!url.startsWith('http')) {
      final file = File(url);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackSearchThumbnail(),
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackSearchThumbnail(),
      ),
    );
  }

  Widget _fallbackSearchThumbnail() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back Button "<" + Product Title + Pink "+" Button
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
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.productName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Subcategories',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryPink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openAddSubcategory,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primaryPink,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPink
                                    .withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar Widget
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SearchBarWidget(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: 'Search ${widget.productName} Subcategory',
                onTap: () {
                  setState(() {
                    _isSearchFocused = true;
                  });
                },
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    if (!_isSearchFocused) _isSearchFocused = true;
                  });
                },
                onClear: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _isSearchFocused = false;
                  });
                  _searchFocusNode.unfocus();
                },
              ),
            ),

            const SizedBox(height: 8),

            // Main Content: GridView of Subcategories from Firebase
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('items')
                    .doc(widget.productId)
                    .collection('subcategories')
                    .snapshots()
                    .map((snapshot) => snapshot.docs.map((doc) {
                          final data = doc.data();
                          return {
                            'subcat_id': doc.id,
                            'subcat_name':
                                (data['subcat_name'] ?? data['name'] ?? '').toString(),
                            'subcat_pic':
                                (data['subcat_pic'] ?? data['imageUrl'] ?? '').toString(),
                            'prod_id': widget.productId,
                          };
                        }).toList()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryPink,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.primaryPink),
                      ),
                    );
                  }

                  final subcategories = snapshot.data ?? [];
                  final filtered = subcategories.where((sub) {
                    final name =
                        (sub['subcat_name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase().trim());
                  }).toList();

                  final searchList = _searchQuery.trim().isEmpty
                      ? subcategories
                      : filtered;

                  return Stack(
                    children: [
                      // 1. GridView of Subcategories matching CategoryCard design
                      filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryPink
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.icecream_rounded,
                                        size: 38,
                                        color: AppColors.primaryPink,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'No subcategories yet for "${widget.productName}"',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AppColors.textDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Tap the + button above to add categories/subcategories (e.g., Cones, Cups, Flavors)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMuted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.73,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final id =
                                    (item['subcat_id'] ?? '').toString();
                                final name =
                                    (item['subcat_name'] ?? '').toString();
                                final pic =
                                    (item['subcat_pic'] ?? '').toString();

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(9),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Subcategory Image
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: _buildCardImage(pic),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Subcategory Name
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Actions: Edit (Green) & Delete (Pink)
                                        Row(
                                          children: [
                                            // Edit button
                                            Expanded(
                                              child: InkWell(
                                                onTap: () => _editSubcategory(
                                                  id: id,
                                                  currentName: name,
                                                  currentPic: pic,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Container(
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.editGreen,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.edit_rounded,
                                                        size: 13,
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Edit',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Delete button
                                            InkWell(
                                              onTap: () =>
                                                  _deleteSubcategory(id, name),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                width: 32,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: AppColors.deleteBg,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 16,
                                                    color: AppColors.deleteIcon,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                      // 2. Search Floating Overlay Container
                      if (_isSearchFocused) ...[
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              _searchFocusNode.unfocus();
                              setState(() {
                                _isSearchFocused = false;
                              });
                            },
                            behavior: HitTestBehavior.translucent,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.04),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 20,
                          right: 20,
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 320),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(
                                color: AppColors.inputBorder
                                    .withValues(alpha: 0.9),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 12, 12, 10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.saved_search_rounded,
                                            size: 20,
                                            color: AppColors.primaryPink,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _searchQuery.isEmpty
                                                ? 'Firebase Subcategories'
                                                : 'Matching Subcategories',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryPink
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${searchList.length}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryPink,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          _searchFocusNode.unfocus();
                                          setState(() {
                                            _isSearchFocused = false;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey
                                                .withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(
                                    height: 1, color: Color(0xFFEEEEEE)),
                                Flexible(
                                  child: searchList.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 24,
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.info_outline_rounded,
                                                size: 16,
                                                color: AppColors.textMuted,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _searchQuery.isEmpty
                                                    ? 'No subcategories yet'
                                                    : 'No match for "$_searchQuery"',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          shrinkWrap: true,
                                          itemCount: searchList.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(
                                            height: 1,
                                            indent: 64,
                                            endIndent: 16,
                                            color: Color(0xFFF7F7F7),
                                          ),
                                          itemBuilder: (context, idx) {
                                            final item = searchList[idx];
                                            final name =
                                                (item['subcat_name'] ?? '')
                                                    .toString();
                                            final pic =
                                                (item['subcat_pic'] ?? '')
                                                    .toString();

                                            return InkWell(
                                              onTap: () {
                                                _searchController.text = name;
                                                setState(() {
                                                  _searchQuery = name;
                                                  _isSearchFocused = false;
                                                });
                                                _searchFocusNode.unfocus();
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                                child: Row(
                                                  children: [
                                                    _buildSearchThumbnail(pic),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: AppColors
                                                              .textDark,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons.north_west_rounded,
                                                      size: 16,
                                                      color:
                                                          AppColors.primaryPink,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}
