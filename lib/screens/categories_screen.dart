import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/category_card.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/search_bar_widget.dart';
import 'add_category_screen.dart';
import 'edit_category_screen.dart';
import 'home_menu_screen.dart';
import 'menu_screen.dart';
import 'profile_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  int _currentTabIndex = 1; // Restaurant icon active matching reference UI
  List<String> _restaurantIds = [];

  @override
  void initState() {
    super.initState();
    _loadRestaurantIds();
    AuthService().cleanCategoriesCollection();
  }

  Future<void> _loadRestaurantIds() async {
    final ids = await AuthService().getCurrentRestaurantIds();
    if (mounted) {
      setState(() {
        _restaurantIds = ids;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openAddCategory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddCategoryScreen(),
      ),
    );
  }

  void _editCategory({
    required String id,
    required String currentName,
    required String currentPic,
    String currentType = '',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditCategoryScreen(
          categoryId: id,
          currentName: currentName,
          currentImageUrl: currentPic,
          currentType: currentType,
        ),
      ),
    );
  }

  void _deleteCategory(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category'),
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
                  .collection('categories')
                  .doc(id)
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category "$name" deleted'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: "Categories" Title + Pink "+" Button matching screenshot
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Center(
                    child: Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openAddCategory,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFA4468),
                                Color(0xFFFF6283),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFA4468).withValues(alpha: 0.4),
                                blurRadius: 10,
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SearchBarWidget(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                onClear: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                  _searchFocusNode.unfocus();
                },
              ),
            ),

            const SizedBox(height: 8),

            // Main Content Area with GridView and Floating Search Container
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('categories')
                    .snapshots()
                    .map((snapshot) {
                      final user = FirebaseAuth.instance.currentUser;
                      final currentUid = user?.uid;
                      final currentEmail = user?.email?.trim().toLowerCase() ?? '';
                      if (currentUid == null) return <Map<String, dynamic>>[];
                      return snapshot.docs
                          .where((doc) {
                            final data = doc.data();
                            final restId = (data['restaurant_id'] ?? '').toString().trim();
                            final userId = (data['user_id'] ?? '').toString().trim();
                            final email = (data['email'] ?? data['owner_email'] ?? '').toString().trim().toLowerCase();
                            final restName = (data['restaurant_name'] ?? '').toString().trim().toLowerCase();
                            return (restId.isNotEmpty && _restaurantIds.contains(restId)) ||
                                (userId.isNotEmpty && _restaurantIds.contains(userId)) ||
                                (email.isNotEmpty && (email == currentEmail || _restaurantIds.contains(email))) ||
                                (restName.isNotEmpty && _restaurantIds.contains(restName)) ||
                                (restId.isNotEmpty && restId == currentUid) ||
                                (userId.isNotEmpty && userId == currentUid);
                          })
                          .map((doc) {
                            final data = doc.data();
                            return {
                              'doc_id': doc.id,
                              'cat_id': (data['cat_id'] ?? data['category_id'] ?? doc.id).toString(),
                              'category_id': (data['category_id'] ?? data['cat_id'] ?? doc.id).toString(),
                              'cat_name': (data['cat_name'] ?? data['category_name'] ?? data['name'] ?? '').toString(),
                              'category_type': (data['category_type'] ?? data['cat_type'] ?? data['type'] ?? '').toString(),
                              'restaurant_id': (data['restaurant_id'] ?? '').toString(),
                              'cat_pic': (data['cat_pic'] ?? data['imageUrl'] ?? '').toString(),
                            };
                          }).toList();
                    }),
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

                  final categories = snapshot.data ?? [];
                  final filtered = categories.where((cat) {
                    final name =
                        (cat['cat_name'] ?? '').toString().toLowerCase();
                    final type =
                        (cat['category_type'] ?? '').toString().toLowerCase();
                    final q = _searchQuery.toLowerCase().trim();
                    return name.contains(q) || type.contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.trim().isNotEmpty
                            ? 'No category found matching "$_searchQuery"'
                            : 'No categories found\nTap + to add a new category',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                      final docId = (item['doc_id'] ?? '').toString();
                      final id = (item['cat_id'] ?? '').toString();
                      final name = (item['cat_name'] ?? '').toString();
                      final type = (item['category_type'] ?? '').toString();
                      final pic = (item['cat_pic'] ?? '').toString();

                      final itemKey = docId.isNotEmpty ? docId : id;

                      return GestureDetector(
                        key: ValueKey(itemKey),
                        onTap: () {
                          _editCategory(
                            id: itemKey,
                            currentName: name,
                            currentType: type,
                            currentPic: pic,
                          );
                        },
                        child: CategoryCard(
                          name: name,
                          type: type,
                          imageUrl: pic,
                          onEdit: () => _editCategory(
                            id: itemKey,
                            currentName: name,
                            currentType: type,
                            currentPic: pic,
                          ),
                          onDelete: () => _deleteCategory(itemKey, name),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeMenuScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MenuScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ),
            );
          } else {
            setState(() {
              _currentTabIndex = index;
            });
          }
        },
      ),
    );
  }
}
