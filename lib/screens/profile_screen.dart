import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
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

        // Optionally save local path to Firestore
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textDark,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(color: AppColors.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F5),
      body: user == null
          ? _buildNotLoggedInView()
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

                              // User Name in Fresh Green
                              Text(
                                fullName.isNotEmpty ? fullName : 'Profile',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF80BC24),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Account Role Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOwner
                                      ? AppColors.primaryPink.withValues(alpha: 0.12)
                                      : const Color(0xFF80BC24).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isOwner
                                        ? AppColors.primaryPink.withValues(alpha: 0.4)
                                        : const Color(0xFF80BC24).withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOwner ? Icons.storefront_rounded : Icons.person_rounded,
                                      size: 14,
                                      color: isOwner ? AppColors.primaryPink : const Color(0xFF6E9F20),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isOwner ? 'Restaurant Owner' : 'Customer Account',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isOwner ? AppColors.primaryPink : const Color(0xFF6E9F20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

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
      bottomNavigationBar: user == null
          ? null
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primaryPink.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 64,
                color: AppColors.primaryPink,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No user currently signed in',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please sign in to view your profile and manage your restaurant account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 150,
              height: 44,
              child: ElevatedButton(
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 15,
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
        // Pink Header Background
        Container(
          width: double.infinity,
          height: 160,
          decoration: const BoxDecoration(
            color: Color(0xFFFA4468),
          ),
        ),

        // Centered Avatar overlapping the header
        Container(
          margin: const EdgeInsets.only(top: 85),
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(5),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
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
      if (savedPhotoUrl.startsWith('http')) {
        return Image.network(
          savedPhotoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
        );
      } else {
        final file = File(savedPhotoUrl);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
          );
        }
      }
    }

    // Default stylish placeholder avatar matching mockup
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFFE8EEF3),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 72,
          color: Colors.grey[400],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
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
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
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
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryPink, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryPink, size: 18),
              label: Text(
                isOwner ? 'Manage Restaurant Orders' : 'My Orders & Live Tracking',
                style: const TextStyle(
                  color: AppColors.primaryPink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Logout Button
          SizedBox(
            width: 125,
            height: 38,
            child: ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA4468),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFA4468),
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
              color: const Color(0xFFF1F6F4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
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
