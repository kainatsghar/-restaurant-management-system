import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'categories_screen.dart';
import 'home_menu_screen.dart';
import 'login_screen.dart';
import 'menu_screen.dart';
import 'restaurant_orders_screen.dart';
import 'special_list_screen.dart';
import 'user_orders_screen.dart';
import 'user_restaurants_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  File? _localProfileImage;

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _localProfileImage = File(pickedFile.path);
        });

        // Save local path to Firestore
        final user = _authService.currentUser;
        if (user != null) {
          await _authService.updateUserProfile(
            uid: user.uid,
            photoUrl: pickedFile.path,
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _handleLogout() {
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
                Icons.logout_rounded,
                color: AppColors.primaryPink,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Log Out',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildNotLoggedInView(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _authService.userProfileStream(user.uid),
        builder: (context, snapshot) {
          // Read profile data from Firestore
          Map<String, dynamic> profileData = {};
          if (snapshot.hasData && snapshot.data?.data() != null) {
            profileData = snapshot.data!.data()!;
          }

          final String role = (profileData['role'] ?? profileData['user_type'] ?? '').toString().toLowerCase();
          final bool isOwner = role == 'restaurant' ||
              role == 'restaurant_owner' ||
              role == 'owner' ||
              (profileData['restaurant_name'] != null &&
                  profileData['restaurant_name'].toString().isNotEmpty);

          final String fullName = (profileData['fullName'] ??
                  profileData['restaurant_name'] ??
                  profileData['name'] ??
                  user.displayName ??
                  'User')
              .toString();

          final String email = (profileData['email'] ??
                  user.email ??
                  'No email provided')
              .toString();

          final String phone = (profileData['phone'] ??
                  profileData['phone_number'] ??
                  profileData['contact'] ??
                  user.phoneNumber ??
                  'No phone provided')
              .toString();

          final String restaurantName = (profileData['restaurant_name'] ?? '').toString();

          final String? savedPhotoUrl = (profileData['photoUrl'] ??
                  profileData['logo_image'] ??
                  profileData['logo'] ??
                  user.photoURL) as String?;

          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // Top Pink Banner & Overlapping Avatar
                        _buildHeaderWithAvatar(
                          fullName: fullName,
                          savedPhotoUrl: savedPhotoUrl,
                        ),
                        const SizedBox(height: 14),

                        // User Name in Bold High-Contrast Dark
                        Text(
                          fullName.isNotEmpty ? fullName : 'Profile',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Account Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1F24),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryPink.withValues(alpha: 0.45),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPink.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOwner ? Icons.storefront_rounded : Icons.person_rounded,
                                size: 14,
                                color: AppColors.primaryPink,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOwner ? 'Restaurant Owner' : 'Customer Account',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryPink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Details Card with Name, Email, Phone, Role, and Order Action
                        _buildDetailsCard(
                          fullName: fullName,
                          email: email,
                          phone: phone,
                          isOwner: isOwner,
                          restaurantName: restaurantName,
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _authService.userProfileStream(user.uid),
        builder: (context, snapshot) {
          final profileData = snapshot.data?.data() ?? {};
          final String role = (profileData['role'] ?? profileData['user_type'] ?? '').toString().toLowerCase();
          final bool isOwner = role == 'restaurant' ||
              role == 'restaurant_owner' ||
              role == 'owner' ||
              (profileData['restaurant_name'] != null &&
                  profileData['restaurant_name'].toString().isNotEmpty);

          return CustomBottomNavBar(
            currentIndex: 3,
            icons: isOwner
                ? const [
                    Icons.home_rounded,
                    Icons.restaurant_rounded,
                    Icons.menu_book_outlined,
                    Icons.person_outline_rounded,
                  ]
                : const [
                    Icons.storefront_rounded,
                    Icons.local_offer_outlined,
                    Icons.receipt_long_rounded,
                    Icons.person_outline_rounded,
                  ],
            onTap: (index) {
              if (isOwner) {
                if (index == 0) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const HomeMenuScreen(),
                    ),
                  );
                } else if (index == 1) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const CategoriesScreen(),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const MenuScreen(),
                    ),
                  );
                }
              } else {
                if (index == 0) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const UserRestaurantsScreen(),
                    ),
                  );
                } else if (index == 1) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const SpecialListScreen(),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const UserOrdersScreen(),
                    ),
                  );
                }
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildNotLoggedInView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primaryPink.withValues(alpha: 0.28),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryPink.withValues(alpha: 0.35)),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 52,
                  color: AppColors.primaryPink,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No user currently signed in',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign in to view your profile and manage your restaurant account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderWithAvatar({
    required String fullName,
    String? savedPhotoUrl,
  }) {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // Pink Header Background Gradient
        Container(
          width: double.infinity,
          height: 160,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFA4468),
                Color(0xFFFF6584),
                Color(0xFF261822),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Centered Avatar overlapping the header
        Container(
          margin: const EdgeInsets.only(top: 85),
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1F24),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.primaryPink,
              width: 2.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.primaryPink.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: _buildAvatarImage(savedPhotoUrl),
                ),
              ),

              // Camera icon badge for photo update
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFA4468), Color(0xFFFF6584)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E1F24), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage(String? savedPhotoUrl) {
    if (_localProfileImage != null && _localProfileImage!.existsSync()) {
      return Image.file(
        _localProfileImage!,
        fit: BoxFit.cover,
      );
    }

    if (savedPhotoUrl != null && savedPhotoUrl.isNotEmpty) {
      return AppNetworkImage(
        imageUrl: savedPhotoUrl,
        width: double.infinity,
        height: double.infinity,
        borderRadius: 24,
        fit: BoxFit.cover,
        fallbackIcon: Icons.person_rounded,
      );
    }

    // Default stylish placeholder avatar matching luxury theme
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFF1E1F24),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 68,
          color: AppColors.primaryPink.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildDetailsCard({
    required String fullName,
    required String email,
    required String phone,
    required bool isOwner,
    required String restaurantName,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.28),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.primaryPink.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Account Type Row
          _buildInfoRow(
            label: 'Account Type',
            value: isOwner ? 'Restaurant Owner' : 'Customer',
          ),
          const SizedBox(height: 14),

          // Name Row
          _buildInfoRow(
            label: 'Name',
            value: fullName.isNotEmpty ? fullName : 'User Name',
          ),
          const SizedBox(height: 14),

          // If Restaurant Owner: Show Restaurant Name
          if (isOwner && restaurantName.isNotEmpty) ...[
            _buildInfoRow(
              label: 'Restaurant',
              value: restaurantName,
            ),
            const SizedBox(height: 14),
          ],

          // Email Row (Gmail)
          _buildInfoRow(
            label: 'Email',
            value: email.isNotEmpty ? email : 'No email provided',
          ),
          const SizedBox(height: 14),

          // Phone Number Row (Num)
          _buildInfoRow(
            label: 'Phone Number',
            value: phone.isNotEmpty ? phone : 'No phone provided',
          ),
          const SizedBox(height: 24),

          // Role-specific Orders Button
          Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFA4468), Color(0xFFFF6584)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (isOwner) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RestaurantOrdersScreen(),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UserOrdersScreen(),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isOwner ? 'Manage Restaurant Orders' : 'My Orders & Live Tracking',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Logout Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleLogout,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 130,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C1920),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.deleteIcon.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: AppColors.deleteIcon,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deleteIcon,
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
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF6584),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF141518),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF2A2B33),
                width: 0.9,
              ),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
