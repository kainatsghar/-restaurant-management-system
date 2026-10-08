import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';
import 'home_menu_screen.dart';
import 'restaurant_login_screen.dart';

class RestaurantRegisterScreen extends StatefulWidget {
  const RestaurantRegisterScreen({super.key});

  @override
  State<RestaurantRegisterScreen> createState() =>
      _RestaurantRegisterScreenState();
}

class _RestaurantRegisterScreenState extends State<RestaurantRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final TextEditingController _restaurantNameController =
      TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _uniqueIdController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  File? _logoImage;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill unique IDs
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _uniqueIdController.text = 'REST_$timestamp';
    _loginIdController.text = 'REST_LOG_${timestamp.toString().substring(timestamp.toString().length - 4)}';

    // If a user is already signed in, pre-fill user ID
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userIdController.text = currentUser.uid;
      _emailController.text = currentUser.email ?? '';
    } else {
      _userIdController.text = 'USER_${timestamp.toString().substring(timestamp.toString().length - 6)}';
    }
  }

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _userIdController.dispose();
    _loginIdController.dispose();
    _uniqueIdController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Pick Logo Image from Gallery
  Future<void> _pickLogoImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _logoImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  // Fetch / Detect Real Live Location & City Name using GPS and Reverse Geocoding
  Future<void> _fetchLiveLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // 1. Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Location services (GPS) are disabled. Please turn on GPS in your device settings.');
        return;
      }

      // 2. Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permission denied. Please allow location access.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permissions are permanently denied. Please enable them in app settings.');
        return;
      }

      // 3. Get exact device GPS position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 4. Reverse Geocode coordinates to City, Area, Street, and Country
      String locationText = '';
      try {
        final List<Placemark> placemarks =
            await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks.first;
          final List<String> addressParts = [];

          // Specific Area / Street / SubLocality
          final street = [place.subThoroughfare, place.thoroughfare]
              .where((s) => s != null && s.trim().isNotEmpty)
              .join(' ')
              .trim();
          if (street.isNotEmpty) addressParts.add(street);

          if (place.subLocality != null &&
              place.subLocality!.trim().isNotEmpty &&
              place.subLocality != street &&
              !addressParts.contains(place.subLocality!.trim())) {
            addressParts.add(place.subLocality!.trim());
          }

          // City Name (locality or subAdministrativeArea)
          final city = place.locality?.trim().isNotEmpty == true
              ? place.locality!.trim()
              : place.subAdministrativeArea?.trim().isNotEmpty == true
                  ? place.subAdministrativeArea!.trim()
                  : '';
          if (city.isNotEmpty && !addressParts.contains(city)) {
            addressParts.add(city);
          }

          // State / Province (administrativeArea)
          if (place.administrativeArea != null &&
              place.administrativeArea!.trim().isNotEmpty &&
              !addressParts.contains(place.administrativeArea!.trim())) {
            addressParts.add(place.administrativeArea!.trim());
          }

          // Country
          if (place.country != null &&
              place.country!.trim().isNotEmpty &&
              !addressParts.contains(place.country!.trim())) {
            addressParts.add(place.country!.trim());
          }

          locationText = addressParts.isNotEmpty
              ? addressParts.join(', ')
              : '${place.name ?? "Current Location"}, ${place.locality ?? place.country ?? ""}';
        }
      } catch (geoError) {
        debugPrint('Geocoding error: $geoError');
      }

      // Fallback if reverse geocoding yielded empty
      if (locationText.isEmpty) {
        locationText = 'Lat: ${position.latitude.toStringAsFixed(4)}, Long: ${position.longitude.toStringAsFixed(4)}';
      }

      setState(() {
        _locationController.text = locationText;
      });

      _showSuccessSnackBar('Live location captured: $locationText');
    } catch (e) {
      _showErrorSnackBar('Could not fetch location: $e');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  // Handle Registration & Firestore Save
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String restaurantName = _restaurantNameController.text.trim();
      final String uniqueId = _uniqueIdController.text.trim().isNotEmpty
          ? _uniqueIdController.text.trim()
          : 'REST_${DateTime.now().millisecondsSinceEpoch}';
      final String userId = _userIdController.text.trim();
      final String loginId = _loginIdController.text.trim();
      final String location = _locationController.text.trim();
      final String description = _descriptionController.text.trim();
      final String email = _emailController.text.trim();
      final String password = _passwordController.text;

      String docId = uniqueId;

      // If email and password provided, create Firebase Auth account
      if (email.isNotEmpty && password.isNotEmpty) {
        try {
          final credential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (credential.user != null) {
            docId = credential.user!.uid;
          }
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'email-already-in-use') {
            // Already exists, sign in instead
            try {
              final cred = await FirebaseAuth.instance
                  .signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              if (cred.user != null) {
                docId = cred.user!.uid;
              }
            } catch (_) {}
          } else {
            throw Exception(authErr.message ?? 'Authentication error');
          }
        }
      }

      String uploadedLogo = '';
      if (_logoImage != null) {
        try {
          uploadedLogo = await ImageService().uploadOrEncodeImage(
            imageFile: _logoImage!,
            folder: 'restaurants',
            fileName: '${docId}_logo',
          );
        } catch (e) {
          debugPrint('Error uploading restaurant logo: $e');
        }
      }

      // Save into 'restaurants' collection with ONLY the user requested fields
      // Strictly NO category_id, category_name, or other clutter
      final Map<String, dynamic> cleanRestaurantData = {
        'restaurant_name': restaurantName,
        'logo_image': uploadedLogo,
        'location': location,
        'unique_id': uniqueId,
        'restaurant_id': uniqueId,
        'user_id': userId,
        'login_id': loginId,
        'user_description': description,
        'role': 'restaurant_owner',
        'user_type': 'restaurant_owner',
      };

      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(docId)
          .set(cleanRestaurantData, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .set({
        'uid': docId,
        'restaurant_name': restaurantName,
        'fullName': restaurantName,
        'role': 'restaurant_owner',
        'user_type': 'restaurant_owner',
        'email': email.trim().toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also clean up any extra fields from other restaurant documents
      await _authService.cleanAllRestaurantsCollection();

      if (!mounted) return;

      _showSuccessSnackBar('Restaurant registered successfully!');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeMenuScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF7A828E), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFFA0AAB5), size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: const Color(0xFF141518),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E313C), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E313C), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFA4468), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F1015),
              Color(0xFF191319),
              Color(0xFF261822),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Back Arrow
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Main Scrollable Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1A1B20),
                            Color(0xFF261822),
                            Color(0xFF381420),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFFFA4468).withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA4468).withValues(alpha: 0.12),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title
                            const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Register your restaurant account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFA0AAB5),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Logo Image Picker
                            Center(
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _pickLogoImage,
                                    child: Container(
                                      width: 86,
                                      height: 86,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF24151E),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFFA4468)
                                              .withValues(alpha: 0.6),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFA4468).withValues(alpha: 0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: _logoImage != null
                                          ? ClipOval(
                                              child: Image.file(
                                                _logoImage!,
                                                width: 86,
                                                height: 86,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.add_a_photo_outlined,
                                                  color: Color(0xFFFA4468),
                                                  size: 26,
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  'Logo',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFFFA4468),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickLogoImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFA4468),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.photo_library_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 1. Restaurant Name
                            TextFormField(
                              controller: _restaurantNameController,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white),
                              decoration: _inputDecoration(
                                hintText: 'Restaurant Name',
                                prefixIcon: Icons.storefront_rounded,
                              ),
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'Please enter restaurant name'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            // 2. Live Location
                            TextFormField(
                              controller: _locationController,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white),
                              decoration: _inputDecoration(
                                hintText: 'City, Area or Live Location',
                                prefixIcon: Icons.location_on_outlined,
                                suffixIcon: InkWell(
                                  onTap: _isGettingLocation
                                      ? null
                                      : _fetchLiveLocation,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    child: _isGettingLocation
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFFA4468),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.my_location_rounded,
                                                color: Color(0xFFFA4468),
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Detect City',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFFA4468),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'Please enter or detect your city / location'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            // 5. User / Restaurant Description
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 2,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white),
                              decoration: _inputDecoration(
                                hintText: 'User Description / Details',
                                prefixIcon: Icons.description_outlined,
                              ),
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'Please enter user description'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            // 6. Email (Optional for Auth login)
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white),
                              decoration: _inputDecoration(
                                hintText: 'Email Address',
                                prefixIcon: Icons.email_outlined,
                              ),
                              validator: (val) {
                                if (val != null &&
                                    val.trim().isNotEmpty &&
                                    !RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                        .hasMatch(val.trim())) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // 7. Password (Optional for Auth login)
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Password',
                                hintStyle: const TextStyle(color: Color(0xFF7A828E), fontSize: 14),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFA0AAB5), size: 20),
                                filled: true,
                                fillColor: const Color(0xFF141518),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF2E313C), width: 1.2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF2E313C), width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFFA4468), width: 1.5),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFFA0AAB5),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                              validator: (val) {
                                if (val != null &&
                                    val.isNotEmpty &&
                                    val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Register Button
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFA4468), Color(0xFFFF6584)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Register',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Already have an account? Log In
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFA0AAB5),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const RestaurantLoginScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFA4468),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
}
