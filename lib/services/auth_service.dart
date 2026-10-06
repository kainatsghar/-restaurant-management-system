import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream of auth state changes (real-time authentication state)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current logged-in user
  User? get currentUser => _auth.currentUser;

  // Sign in with Google (Opens the native phone Google Account Picker)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow (opens Google account picker showing phone accounts)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If user cancelled the picker dialog
      if (googleUser == null) {
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential for Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google User Credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user != null) {
        final displayName = user.displayName ?? googleUser.displayName ?? '';
        final parts = displayName.trim().split(' ');
        final firstName = parts.isNotEmpty ? parts.first : '';
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        // Save / merge user profile in Firestore
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'firstName': firstName,
            'lastName': lastName,
            'fullName': displayName.isNotEmpty ? displayName : 'Google User',
            'email': user.email ?? googleUser.email,
            'photoUrl': user.photoURL ?? googleUser.photoUrl ?? '',
            'phone': user.phoneNumber ?? '',
            'role': 'user',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Could not save Google profile to Firestore: $e');
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  // User role constants
  static const String roleCustomer = 'customer';
  static const String roleRestaurantOwner = 'restaurant_owner';

  // Get current user role ('restaurant_owner' or 'customer')
  Future<String> getCurrentUserRole([String? uid]) async {
    final targetUid = uid ?? _auth.currentUser?.uid;
    if (targetUid == null) return roleCustomer;
    try {
      // 1. Check users collection
      final userDoc = await _firestore.collection('users').doc(targetUid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final role = (data['role'] ?? data['user_type'] ?? '').toString().toLowerCase();
        if (role == 'restaurant' || role == 'restaurant_owner' || role == 'owner') {
          return roleRestaurantOwner;
        }
        if (role == 'customer' || role == 'user') {
          return roleCustomer;
        }
      }

      // 2. Check restaurants collection
      final restDoc = await _firestore.collection('restaurants').doc(targetUid).get();
      if (restDoc.exists) return roleRestaurantOwner;

      // Check if user has a document in 'restaurants' by unique_id or user_id
      final queryUser = await _firestore
          .collection('restaurants')
          .where('user_id', isEqualTo: targetUid)
          .limit(1)
          .get();
      if (queryUser.docs.isNotEmpty) return roleRestaurantOwner;

      final email = _auth.currentUser?.email;
      if (email != null && email.isNotEmpty) {
        final queryEmail = await _firestore
            .collection('restaurants')
            .where('email', isEqualTo: email.toLowerCase())
            .limit(1)
            .get();
        if (queryEmail.docs.isNotEmpty) return roleRestaurantOwner;
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
    }
    return roleCustomer;
  }

  // Check if current user or given UID is a restaurant owner
  Future<bool> isCurrentUserRestaurantOwner([String? uid]) async {
    final role = await getCurrentUserRole(uid);
    return role == roleRestaurantOwner;
  }

  // Check if current user or given UID is a customer
  Future<bool> isCurrentUserCustomer([String? uid]) async {
    final role = await getCurrentUserRole(uid);
    return role == roleCustomer;
  }

  // Sign up with Email and Password & save user profile to Firestore
  Future<UserCredential> signUpWithEmailPassword({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? userId,
    String? loginId,
    String? dob,
    String? phone,
  }) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;
      if (user != null) {
        final fullName = '$firstName $lastName'.trim();
        // Update user display name in FirebaseAuth
        try {
          await user.updateDisplayName(fullName);
        } catch (e) {
          debugPrint('Could not update display name: $e');
        }

        final String finalUserId = (userId != null && userId.trim().isNotEmpty)
            ? userId.trim()
            : 'USER_${user.uid.substring(0, user.uid.length >= 8 ? 8 : user.uid.length)}';
        final String finalLoginId = (loginId != null && loginId.trim().isNotEmpty)
            ? loginId.trim()
            : email.trim().toLowerCase().split('@').first;

        // Save user details to Firestore 'users' collection including user_id & login_id
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'user_id': finalUserId,
            'login_id': finalLoginId,
            'firstName': firstName.trim(),
            'lastName': lastName.trim(),
            'fullName': fullName,
            'email': email.trim().toLowerCase(),
            'dob': dob ?? '',
            'phone': phone?.trim() ?? '',
            'role': roleCustomer,
            'user_type': roleCustomer,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Could not save user profile to Firestore: $e');
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Sign in with Email and Password
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // Real-time stream of user profile document from Firestore
  Stream<DocumentSnapshot<Map<String, dynamic>>>? userProfileStream(String uid) {
    try {
      return _firestore.collection('users').doc(uid).snapshots();
    } catch (e) {
      debugPrint('Error creating profile stream: $e');
      return null;
    }
  }

  // Update user profile data in Firestore
  Future<void> updateUserProfile({
    required String uid,
    String? fullName,
    String? phone,
    String? photoUrl,
  }) async {
    final Map<String, dynamic> data = {
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fullName != null) data['fullName'] = fullName.trim();
    if (phone != null) data['phone'] = phone.trim();
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // Fetch user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // ===================== RESTAURANT AUTH & FIRESTORE =====================

  // Sign up a new Restaurant & save details into 'restaurants' collection in Firestore
  Future<UserCredential> signUpRestaurant({
    required String restaurantName,
    required String email,
    required String password,
    String? phone,
    String? address,
    String? ownerName,
    String? userId,
    String? loginId,
    String? uniqueId,
  }) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;
      if (user != null) {
        try {
          await user.updateDisplayName(restaurantName.trim());
        } catch (_) {}

        final String finalUserId = (userId != null && userId.trim().isNotEmpty)
            ? userId.trim()
            : 'USER_${user.uid.substring(0, user.uid.length >= 8 ? 8 : user.uid.length)}';
        final String finalLoginId = (loginId != null && loginId.trim().isNotEmpty)
            ? loginId.trim()
            : email.trim().toLowerCase().split('@').first;
        final String finalUniqueId = (uniqueId != null && uniqueId.trim().isNotEmpty)
            ? uniqueId.trim()
            : 'REST_${DateTime.now().millisecondsSinceEpoch}';

        // Save restaurant document in 'restaurants' collection
        try {
          await _firestore.collection('restaurants').doc(user.uid).set({
            'restaurant_id': user.uid,
            'restaurant_name': restaurantName.trim(),
            'owner_name': (ownerName ?? '').trim(),
            'user_id': finalUserId,
            'login_id': finalLoginId,
            'unique_id': finalUniqueId,
            'email': email.trim().toLowerCase(),
            'phone': (phone ?? '').trim(),
            'address': (address ?? '').trim(),
            'role': roleRestaurantOwner,
            'user_type': roleRestaurantOwner,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Also save in 'users' collection so profile and checks are globally unified
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'user_id': finalUserId,
            'login_id': finalLoginId,
            'fullName': (ownerName != null && ownerName.trim().isNotEmpty)
                ? ownerName.trim()
                : restaurantName.trim(),
            'restaurant_name': restaurantName.trim(),
            'email': email.trim().toLowerCase(),
            'phone': (phone ?? '').trim(),
            'address': (address ?? '').trim(),
            'role': roleRestaurantOwner,
            'user_type': roleRestaurantOwner,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Could not save to restaurants/users collection: $e');
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Restaurant registration failed: ${e.toString()}');
    }
  }

  // Sign in an existing Restaurant
  Future<UserCredential> signInRestaurant({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;
      if (user != null) {
        // Record last login in 'restaurants' collection
        try {
          await _firestore.collection('restaurants').doc(user.uid).set({
            'restaurant_id': user.uid,
            'email': email.trim().toLowerCase(),
            'lastLogin': FieldValue.serverTimestamp(),
            'role': 'restaurant',
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Could not update restaurant login timestamp: $e');
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Restaurant sign-in failed: ${e.toString()}');
    }
  }

  // Sign in Restaurant with Google
  Future<UserCredential?> signInRestaurantWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user != null) {
        final displayName =
            user.displayName ?? googleUser.displayName ?? 'Restaurant Partner';

        // Save in 'restaurants' collection
        try {
          await _firestore.collection('restaurants').doc(user.uid).set({
            'restaurant_id': user.uid,
            'restaurant_name': displayName,
            'email': user.email ?? googleUser.email,
            'photoUrl': user.photoURL ?? googleUser.photoUrl ?? '',
            'role': 'restaurant',
            'lastLogin': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Could not save Google restaurant to Firestore: $e');
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Google Restaurant Sign In Error: $e');
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  // Get active Restaurant ID for currently logged-in user
  Future<String?> getCurrentRestaurantId() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _firestore.collection('restaurants').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final restId = (data['unique_id'] ?? data['restaurant_id'] ?? user.uid).toString();
        if (restId.isNotEmpty) return restId;
      }
    } catch (e) {
      debugPrint('Error getting current restaurant ID: $e');
    }
    return user.uid;
  }

  // Get all matching Restaurant ID variations (UID + unique_id) for filtering queries
  Future<List<String>> getCurrentRestaurantIds() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final List<String> ids = [user.uid];
    try {
      final doc = await _firestore.collection('restaurants').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final restId = (data['restaurant_id'] ?? '').toString();
        final uniqueId = (data['unique_id'] ?? '').toString();
        final userId = (data['user_id'] ?? '').toString();
        if (restId.isNotEmpty && !ids.contains(restId)) ids.add(restId);
        if (uniqueId.isNotEmpty && !ids.contains(uniqueId)) ids.add(uniqueId);
        if (userId.isNotEmpty && !ids.contains(userId)) ids.add(userId);
      }
    } catch (e) {
      debugPrint('Error getting restaurant IDs: $e');
    }
    return ids;
  }

  // Real-time stream of restaurant profile document from Firestore
  Stream<DocumentSnapshot<Map<String, dynamic>>>? restaurantProfileStream(
      String uid) {
    try {
      return _firestore.collection('restaurants').doc(uid).snapshots();
    } catch (e) {
      debugPrint('Error creating restaurant stream: $e');
      return null;
    }
  }

  // Link a Category with a Restaurant in Firestore:
  // 1. Adds category ID and category details to the restaurant's document in 'restaurants'
  // 2. Adds the restaurant key ('restaurant_id', 'restaurant_name') to the category document in 'categories'
  Future<bool> linkCategoryWithRestaurant({
    required String categoryId,
    required String categoryName,
  }) async {
    try {
      final user = _auth.currentUser;
      String? restaurantId = user?.uid;
      String restaurantName = user?.displayName ?? 'Restaurant';

      // If user is null, find the existing restaurant from 'restaurants' collection
      if (restaurantId == null) {
        final query = await _firestore.collection('restaurants').limit(1).get();
        if (query.docs.isNotEmpty) {
          restaurantId = query.docs.first.id;
          final data = query.docs.first.data();
          restaurantName = (data['restaurant_name'] ?? data['name'] ?? 'Restaurant').toString();
        }
      }

      if (restaurantId != null) {
        // 1. Ensure restaurant document does NOT keep category_id or category_name
        await _firestore.collection('restaurants').doc(restaurantId).set({
          'category_id': FieldValue.delete(),
          'category_name': FieldValue.delete(),
          'category_ids': FieldValue.delete(),
        }, SetOptions(merge: true));

        // 2. Add restaurant key to the category document
        await _firestore.collection('categories').doc(categoryId).set({
          'restaurant_id': restaurantId,
          'restaurant_name': restaurantName,
          'restaurant_ids': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('Successfully linked Category "$categoryId" ($categoryName) with Restaurant "$restaurantId"');
        return true;
      } else {
        debugPrint('No restaurant found to link with category.');
        return false;
      }
    } catch (e) {
      debugPrint('Error linking category with restaurant: $e');
      return false;
    }
  }

  // Save clean product in 'products' collection to strictly maintain only:
  // - item_name
  // - category_name
  // - category_id
  // - restaurant_name
  // - restaurant_id
  Future<void> saveCleanProduct({
    required String productId,
    required String itemName,
    required String categoryName,
    required String categoryId,
    String? restaurantName,
    String? restaurantId,
  }) async {
    try {
      String rId = (restaurantId ?? '').trim();
      String rName = (restaurantName ?? '').trim();

      if (rId.isEmpty) {
        final user = _auth.currentUser;
        if (user != null) {
          rId = user.uid;
          rName = user.displayName ?? '';
        }
      }

      if (rId.isNotEmpty && rName.isEmpty) {
        try {
          final rDoc = await _firestore.collection('restaurants').doc(rId).get();
          if (rDoc.exists && rDoc.data() != null) {
            rName = (rDoc.data()!['restaurant_name'] ?? rDoc.data()!['name'] ?? '').toString();
          }
        } catch (_) {}
      }

      if (rId.isEmpty && categoryId.isNotEmpty) {
        try {
          final catDoc =
              await _firestore.collection('categories').doc(categoryId).get();
          if (catDoc.exists && catDoc.data() != null) {
            final catData = catDoc.data()!;
            rId = (catData['restaurant_id'] ?? '').toString();
            rName = (catData['restaurant_name'] ?? '').toString();
          }
        } catch (_) {}
      }

      if (rId.isEmpty) {
        try {
          final query =
              await _firestore.collection('restaurants').limit(1).get();
          if (query.docs.isNotEmpty) {
            rId = query.docs.first.id;
            final rData = query.docs.first.data();
            rName = (rData['restaurant_name'] ??
                    rData['name'] ??
                    'Restaurant')
                .toString();
          }
        } catch (_) {}
      }

      final Map<String, dynamic> cleanData = {
        'item_name': itemName,
        'category_name': categoryName,
        'category_id': categoryId,
        'restaurant_name': rName,
        'restaurant_id': rId,
      };

      // Set without merge to completely replace and remove all unwanted fields
      await _firestore.collection('products').doc(productId).set(cleanData);
      debugPrint('Saved clean product $productId with only 5 fields: $cleanData');
    } catch (e) {
      debugPrint('Error saving clean product: $e');
    }
  }

  // Automatically cleans any existing documents in 'products' collection
  Future<void> cleanUpExistingProducts() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('prod_desc') ||
            data.containsKey('has_group') ||
            data.containsKey('prod_pic') ||
            data.containsKey('cat_id') ||
            data.containsKey('item_description') ||
            !data.containsKey('restaurant_id')) {
          final name =
              (data['item_name'] ?? data['prod_name'] ?? '').toString();
          String catName =
              (data['category_name'] ?? data['cat_name'] ?? '').toString();
          String catId =
              (data['category_id'] ?? data['cat_id'] ?? '').toString();

          if (catId.isEmpty || catName.isEmpty) {
            try {
              final itemDoc =
                  await _firestore.collection('items').doc(doc.id).get();
              if (itemDoc.exists && itemDoc.data() != null) {
                final itemData = itemDoc.data()!;
                catId = (itemData['category_id'] ??
                        itemData['cat_id'] ??
                        catId)
                    .toString();
                catName = (itemData['category_name'] ??
                        itemData['cat_name'] ??
                        catName)
                    .toString();
              }
            } catch (_) {}
          }

          await saveCleanProduct(
            productId: doc.id,
            itemName: name,
            categoryName: catName,
            categoryId: catId,
            restaurantName: (data['restaurant_name'] ?? '').toString(),
            restaurantId: (data['restaurant_id'] ?? '').toString(),
          );
        }
      }
    } catch (e) {
      debugPrint('Error cleaning existing products: $e');
    }
  }

  // Clean all existing documents in 'restaurants' collection to keep strictly:
  // - restaurant_name
  // - logo_image
  // - location
  // - unique_id
  // - user_id
  // - user_description
  Future<void> cleanAllRestaurantsCollection() async {
    try {
      final snapshot = await _firestore.collection('restaurants').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        final cleanData = <String, dynamic>{
          'restaurant_name': (data['restaurant_name'] ?? data['name'] ?? 'HeartTale').toString(),
          'logo_image': (data['logo_image'] ?? data['logo'] ?? data['photoUrl'] ?? '').toString(),
          'location': (data['location'] ?? data['address'] ?? 'Live Location').toString(),
          'unique_id': (data['unique_id'] ?? data['restaurant_id'] ?? doc.id).toString(),
          'restaurant_id': (data['restaurant_id'] ?? data['unique_id'] ?? doc.id).toString(),
          'user_id': (data['user_id'] ?? data['owner_id'] ?? doc.id).toString(),
          'login_id': (data['login_id'] ?? data['email'] ?? doc.id).toString(),
          'user_description': (data['user_description'] ?? data['description'] ?? 'Restaurant Partner').toString(),
        };

        // Overwrite without merge to completely erase category_id, category_name, etc.
        await _firestore.collection('restaurants').doc(doc.id).set(cleanData);
      }
      debugPrint('Successfully cleaned restaurants collection.');
    } catch (e) {
      debugPrint('Error cleaning restaurants collection: $e');
    }
  }

  // Clean all existing documents in 'categories' collection to remove duplicates (cat_id, cat_name, cat_type, imageUrl)
  // and maintain single clean fields: category_id, category_name, category_type, cat_pic, restaurant_id, createdAt
  Future<void> cleanCategoriesCollection() async {
    try {
      final snapshot = await _firestore.collection('categories').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('cat_id') ||
            data.containsKey('cat_name') ||
            data.containsKey('cat_type') ||
            data.containsKey('imageUrl')) {
          final String restId = (data['restaurant_id'] ?? '').toString();
          final String rawCatId = (data['category_id'] ?? data['cat_id'] ?? '').toString();
          final String catId = (rawCatId.isNotEmpty && rawCatId != restId) ? rawCatId : doc.id;
          final String catName = (data['category_name'] ?? data['cat_name'] ?? data['name'] ?? '').toString();
          final String catType = (data['category_type'] ?? data['cat_type'] ?? data['type'] ?? 'General').toString();
          final String pic = (data['cat_pic'] ?? data['imageUrl'] ?? '').toString();

          final Map<String, dynamic> cleanCat = {
            'category_id': catId,
            'category_name': catName,
            'category_type': catType,
            'restaurant_id': restId,
            'cat_pic': pic,
          };
          if (data['createdAt'] != null) {
            cleanCat['createdAt'] = data['createdAt'];
          }
          // Overwrite to remove duplicate fields
          await _firestore.collection('categories').doc(doc.id).set(cleanCat);
        }
      }
      debugPrint('Successfully cleaned categories collection from duplicates.');
    } catch (e) {
      debugPrint('Error cleaning categories: $e');
    }
  }

  // Clean all existing documents in 'items' collection to strictly keep:
  // - category_id
  // - category_name
  // - item_id
  // - item_name
  // - item_pic
  // - item_price
  Future<void> cleanAllItemsCollection() async {
    try {
      final snapshot = await _firestore.collection('items').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final String catId = (data['category_id'] ?? data['cat_id'] ?? '').toString();
        final String catName = (data['category_name'] ?? data['cat_name'] ?? '').toString();
        final String itemId = (data['item_id'] ?? doc.id).toString();
        final String name = (data['item_name'] ?? data['prod_name'] ?? data['name'] ?? '').toString();
        final String pic = (data['item_pic'] ?? data['prod_pic'] ?? data['imageUrl'] ?? '').toString();
        final priceVal = data['item_price'] ?? data['prod_price'] ?? data['price'] ?? 0.0;
        final double price = priceVal is num
            ? priceVal.toDouble()
            : (double.tryParse(priceVal.toString()) ?? 0.0);

        final originalPriceVal = data['original_price'] ?? price;
        final double originalPrice = originalPriceVal is num
            ? originalPriceVal.toDouble()
            : (double.tryParse(originalPriceVal.toString()) ?? price);

        final discountVal = data['discount_percent'] ?? 0.0;
        final double discountPercent = discountVal is num
            ? discountVal.toDouble()
            : (double.tryParse(discountVal.toString()) ?? 0.0);

        final desc = (data['item_description'] ?? data['prod_desc'] ?? data['description'] ?? '').toString();
        final String restId = (data['restaurant_id'] ?? '').toString();
        final String userId = (data['user_id'] ?? '').toString();

        final Map<String, dynamic> cleanItem = {
          'category_id': catId,
          'category_name': catName,
          'item_id': itemId,
          'item_name': name,
          'item_pic': pic,
          'item_price': price,
          'original_price': originalPrice,
          'discount_percent': discountPercent,
          'has_discount': discountPercent > 0,
          'discounted_price': price,
        };
        if (desc.isNotEmpty) cleanItem['item_description'] = desc;
        if (restId.isNotEmpty) cleanItem['restaurant_id'] = restId;
        if (userId.isNotEmpty) cleanItem['user_id'] = userId;

        // Preserve all fields and merge
        await _firestore.collection('items').doc(doc.id).set(cleanItem, SetOptions(merge: true));
      }
      debugPrint('Successfully cleaned items collection.');
    } catch (e) {
      debugPrint('Error cleaning items collection: $e');
    }
  }

  // Translate FirebaseAuth errors into friendly Urdu/English readable messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password entered. Please try again.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Console.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'An authentication error occurred (${e.code}).';
    }
  }
}
