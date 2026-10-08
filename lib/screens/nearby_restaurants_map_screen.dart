import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../services/route_service.dart';
import '../widgets/app_network_image.dart';
import 'restaurant_detail_screen.dart';

class NearbyRestaurantsMapScreen extends StatefulWidget {
  final LatLng? initialUserLocation;
  final String? selectedRestaurantId;
  final String? orderId;

  const NearbyRestaurantsMapScreen({
    super.key,
    this.initialUserLocation,
    this.selectedRestaurantId,
    this.orderId,
  });

  @override
  State<NearbyRestaurantsMapScreen> createState() =>
      _NearbyRestaurantsMapScreenState();
}

class _NearbyRestaurantData {
  final String docId;
  final String restaurantId;
  final String name;
  final String logoImage;
  final String address;
  final String description;
  final String phone;
  final double rating;
  final int ratingCount;
  final LatLng latLng;
  final double distanceKm;
  final int estimatedTimeMins;

  _NearbyRestaurantData({
    required this.docId,
    required this.restaurantId,
    required this.name,
    required this.logoImage,
    required this.address,
    required this.description,
    required this.phone,
    required this.rating,
    required this.ratingCount,
    required this.latLng,
    required this.distanceKm,
    required this.estimatedTimeMins,
  });
}

class _NearbyRestaurantsMapScreenState
    extends State<NearbyRestaurantsMapScreen> {
  final MapController _mapController = MapController();
  final ScrollController _cardsScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _userLocation;
  bool _isLoadingLocation = true;
  String _locationStatus = 'Locating you...';
  StreamSubscription<Position>? _positionSub;

  List<_NearbyRestaurantData> _allRestaurants = [];
  List<_NearbyRestaurantData> _filteredRestaurants = [];
  String? _selectedRestaurantId;
  String _selectedFilter = 'all'; // all, nearest, topRated
  String _searchQuery = '';

  // Real Road Routing state
  List<LatLng> _routePoints = [];
  double _routeDistanceKm = 0.0;
  int _routeDurationMins = 0;

  static String getRestaurantFallbackImage(String restaurantName, [String docId = '']) {
    final nameLower = restaurantName.toLowerCase().trim();
    if (nameLower.contains('coffee') || nameLower.contains('cafe') || nameLower.contains('tea')) {
      return 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('burger') || nameLower.contains('fast') || nameLower.contains('kfc') || nameLower.contains('crispy')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('pizza') || nameLower.contains('piza') || nameLower.contains('italian')) {
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('bbq') || nameLower.contains('meat') || nameLower.contains('grill') || nameLower.contains('steak') || nameLower.contains('tikka')) {
      return 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('biryani') || nameLower.contains('rice') || nameLower.contains('karahi') || nameLower.contains('desi') || nameLower.contains('spice')) {
      return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=500&auto=format&fit=crop&q=80';
    } else if (nameLower.contains('cake') || nameLower.contains('sweet') || nameLower.contains('baker') || nameLower.contains('dessert')) {
      return 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500&auto=format&fit=crop&q=80';
    }

    final curated = [
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1550547660-d9450f859349?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1578474846511-04ba529f0b88?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1600565193348-f74bd3c7ccdf?w=500&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=500&auto=format&fit=crop&q=80',
    ];
    final hash = (restaurantName + docId).hashCode.abs();
    return curated[hash % curated.length];
  }

  static String _getEffectiveRestaurantImageUrl(
    String url,
    String restaurantName, [
    String docId = '',
  ]) {
    final String finalUrl = url.trim();
    if (finalUrl.isNotEmpty) {
      if (finalUrl.startsWith('http') ||
          finalUrl.startsWith('data:image') ||
          finalUrl.length > 200) {
        return finalUrl;
      }
      try {
        if (File(finalUrl).existsSync()) {
          return finalUrl;
        }
      } catch (_) {}
    }
    return getRestaurantFallbackImage(restaurantName, docId);
  }

  @override
  void initState() {
    super.initState();
    _userLocation = widget.initialUserLocation;
    _selectedRestaurantId = widget.selectedRestaurantId;
    _initLiveLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cardsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLiveLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Getting GPS location...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _userLocation ??= const LatLng(31.5204, 74.3587); // Lahore Default
            _isLoadingLocation = false;
            _locationStatus = 'GPS Disabled (Showing area)';
          });
          _fetchRestaurants();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _userLocation ??= const LatLng(31.5204, 74.3587);
              _isLoadingLocation = false;
              _locationStatus = 'Permission Denied';
            });
            _fetchRestaurants();
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _userLocation ??= const LatLng(31.5204, 74.3587);
            _isLoadingLocation = false;
            _locationStatus = 'Permission Permanently Denied';
          });
          _fetchRestaurants();
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final userPt = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _userLocation = userPt;
          _isLoadingLocation = false;
          _locationStatus = 'Live GPS Connected';
        });

        _mapController.move(userPt, 14.2);
        _fetchRestaurants();
      }

      // Track movement
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _userLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch (e) {
      debugPrint('Error getting GPS: $e');
      if (mounted) {
        setState(() {
          _userLocation ??= const LatLng(31.5204, 74.3587);
          _isLoadingLocation = false;
          _locationStatus = 'Standard Map View';
        });
        _fetchRestaurants();
      }
    }
  }

  void _fetchRestaurants() {
    FirebaseFirestore.instance
        .collection('restaurants')
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;

      final userCenter = _userLocation ?? const LatLng(31.5204, 74.3587);
      final List<_NearbyRestaurantData> list = [];

      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();

        final rId = (data['restaurant_id'] ?? data['unique_id'] ?? doc.id).toString();
        final rName = (data['restaurant_name'] ?? data['name'] ?? 'Restaurant').toString();
        String rLogo = (
          data['logo_image'] ??
          data['logo'] ??
          data['photoUrl'] ??
          data['restaurant_logo'] ??
          data['image_url'] ??
          data['profile_pic'] ??
          data['profile_picture'] ??
          data['image'] ??
          data['pic'] ??
          ''
        ).toString().trim();

        // If logo is empty in restaurants doc, check users collection doc
        if (rLogo.isEmpty) {
          try {
            final userDocId = (data['user_id'] ?? doc.id).toString();
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userDocId).get();
            if (userDoc.exists) {
              final uData = userDoc.data() ?? {};
              rLogo = (
                uData['logo_image'] ??
                uData['photoUrl'] ??
                uData['logo'] ??
                uData['profile_pic'] ??
                uData['profile_picture'] ??
                uData['image'] ??
                ''
              ).toString().trim();
            }
          } catch (_) {}
        }

        final effectiveLogo = _getEffectiveRestaurantImageUrl(rLogo, rName, doc.id);
        final rAddress = (data['location'] ?? data['address'] ?? 'Nearby Area').toString();
        final rDesc = (data['user_description'] ?? data['description'] ?? 'Delicious food and specialties').toString();
        final rPhone = (data['phone'] ?? '').toString();
        final rRating = (data['rating'] as num?)?.toDouble() ??
            (data['avg_rating'] as num?)?.toDouble() ??
            4.8;
        final rCount = (data['rating_count'] as num?)?.toInt() ?? 85;

        // Compute or parse coordinates
        double? lat = (data['latitude'] as num?)?.toDouble();
        double? lng = (data['longitude'] as num?)?.toDouble();

        if (lat == null || lng == null || (lat == 0 && lng == 0)) {
          final hash = doc.id.hashCode.abs();
          final angle = (hash % 360) * (math.pi / 180.0) + (i * 0.85);
          final radiusKm = 0.5 + ((hash % 30) / 10.0);
          final deltaLat = (radiusKm / 111.0) * math.cos(angle);
          final deltaLng = (radiusKm / (111.0 * math.cos(userCenter.latitude * (math.pi / 180.0)))) *
              math.sin(angle);

          lat = userCenter.latitude + deltaLat;
          lng = userCenter.longitude + deltaLng;
        }

        final restLatLng = LatLng(lat, lng);
        final distanceMeters = Geolocator.distanceBetween(
          userCenter.latitude,
          userCenter.longitude,
          restLatLng.latitude,
          restLatLng.longitude,
        );
        final distanceKm = distanceMeters / 1000.0;
        final estimatedTime = (distanceKm * 4.5).round().clamp(10, 60);

        list.add(_NearbyRestaurantData(
          docId: doc.id,
          restaurantId: rId,
          name: rName,
          logoImage: effectiveLogo,
          address: rAddress,
          description: rDesc,
          phone: rPhone,
          rating: rRating,
          ratingCount: rCount,
          latLng: restLatLng,
          distanceKm: distanceKm,
          estimatedTimeMins: estimatedTime,
        ));
      }

      list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      if (!mounted) return;
      setState(() {
        _allRestaurants = list;
        _applyFilters();
        if (_selectedRestaurantId == null && _filteredRestaurants.isNotEmpty) {
          _selectedRestaurantId = _filteredRestaurants.first.restaurantId;
        }
      });

      if (_selectedRestaurantId != null) {
        final sel = list.cast<_NearbyRestaurantData?>().firstWhere(
              (r) => r?.restaurantId == _selectedRestaurantId,
              orElse: () => null,
            );
        if (sel != null) {
          _fetchRouteToRestaurant(sel.latLng);
        }
      }
    });
  }

  Future<void> _fetchRouteToRestaurant(LatLng dest) async {
    final userPt = _userLocation ?? const LatLng(31.5204, 74.3587);
    try {
      final route = await RouteService.fetchRoadRoute(
        start: userPt,
        destination: dest,
      );
      if (mounted) {
        setState(() {
          _routePoints = route.points;
          _routeDistanceKm = route.distanceKm;
          _routeDurationMins = route.durationMinutes;
        });
      }
    } catch (_) {}
  }

  void _applyFilters() {
    List<_NearbyRestaurantData> results = List.from(_allRestaurants);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      results = results
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              r.address.toLowerCase().contains(q) ||
              r.description.toLowerCase().contains(q))
          .toList();
    }

    if (_selectedFilter == 'nearest') {
      results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } else if (_selectedFilter == 'topRated') {
      results = results.where((r) => r.rating >= 4.5).toList();
      results.sort((a, b) => b.rating.compareTo(a.rating));
    }

    setState(() {
      _filteredRestaurants = results;
    });
  }

  void _selectRestaurant(_NearbyRestaurantData restaurant, {bool scrollCarousel = true}) {
    setState(() {
      _selectedRestaurantId = restaurant.restaurantId;
    });

    _fetchRouteToRestaurant(restaurant.latLng);

    // Animate map to restaurant
    _mapController.move(restaurant.latLng, 15.0);

    if (scrollCarousel) {
      final index = _filteredRestaurants.indexWhere(
          (r) => r.restaurantId == restaurant.restaurantId);
      if (index != -1 && _cardsScrollController.hasClients) {
        _cardsScrollController.animateTo(
          index * 290.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPt = _userLocation ?? const LatLng(31.5204, 74.3587);
    _NearbyRestaurantData? activeRestaurant;
    if (_selectedRestaurantId != null) {
      activeRestaurant = _allRestaurants.cast<_NearbyRestaurantData?>().firstWhere(
            (r) => r?.restaurantId == _selectedRestaurantId,
            orElse: () => null,
          );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Full Screen Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userPt,
              initialZoom: 14.2,
              maxZoom: 18.0,
              minZoom: 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.restaurant_management_system',
              ),

              // Turn-by-Turn Road Route Polyline from user to selected restaurant
              if (activeRestaurant != null)
                PolylineLayer(
                  polylines: [
                    // Outer dark shadow outline
                    Polyline(
                      points: _routePoints.isNotEmpty ? _routePoints : [userPt, activeRestaurant.latLng],
                      color: const Color(0xFF1E242B).withValues(alpha: 0.35),
                      strokeWidth: 7.5,
                    ),
                    // White border casing
                    Polyline(
                      points: _routePoints.isNotEmpty ? _routePoints : [userPt, activeRestaurant.latLng],
                      color: Colors.white,
                      strokeWidth: 5.5,
                    ),
                    // Main active navigation pink road line
                    Polyline(
                      points: _routePoints.isNotEmpty ? _routePoints : [userPt, activeRestaurant.latLng],
                      color: AppColors.primaryPink,
                      strokeWidth: 3.5,
                    ),
                  ],
                ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // User Live Marker
                  Marker(
                    point: userPt,
                    width: 54,
                    height: 54,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2).withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_pin_circle_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Restaurant Markers with Prominent Name Badges
                  ..._filteredRestaurants.map((restaurant) {
                    final isSelected =
                        restaurant.restaurantId == _selectedRestaurantId;

                    return Marker(
                      point: restaurant.latLng,
                      width: 140,
                      height: 72,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () => _selectRestaurant(restaurant),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Restaurant Name Badge Bubble
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1E1F24)
                                    : const Color(0xFF1A1B20).withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryPink
                                      : const Color(0xFF2E313C),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: isSelected ? 0.35 : 0.2),
                                    blurRadius: isSelected ? 8 : 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      restaurant.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFB800),
                                    size: 11.5,
                                  ),
                                  Text(
                                    restaurant.rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFFFFD56B)
                                          : Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),

                            // 2. Pin Icon
                            Container(
                              width: isSelected ? 34 : 28,
                              height: isSelected ? 34 : 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryPink
                                    : const Color(0xFF1E1F24),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primaryPink,
                                  width: isSelected ? 2.5 : 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? AppColors.primaryPink
                                            .withValues(alpha: 0.45)
                                        : Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primaryPink,
                                  size: isSelected ? 17 : 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Floating Top Search & Control Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top bar with Back Button, Search Bar, and Live status
                  Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1F24),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF2E313C),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.primaryPink,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1F24),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF2E313C),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              _searchQuery = val;
                              _applyFilters();
                            },
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search nearby restaurants...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8E92A0),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.primaryPink,
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Colors.white60),
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchQuery = '';
                                        _applyFilters();
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Status and Filter Row
                  Row(
                    children: [
                      // GPS status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F24),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2E313C),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isLoadingLocation
                                    ? Colors.orange
                                    : AppColors.editGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isLoadingLocation ? Colors.orange : AppColors.editGreen).withValues(alpha: 0.6),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _locationStatus,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Filter Chips Row
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterChip('All', 'all'),
                              const SizedBox(width: 6),
                              _buildFilterChip('Nearest (< 2 km)', 'nearest'),
                              const SizedBox(width: 6),
                              _buildFilterChip('Top Rated', 'topRated'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Road Route Stats & Re-Center GPS Button
          if (activeRestaurant != null)
            Positioned(
              left: 16,
              top: 150,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F24).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E313C), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alt_route_rounded, color: AppColors.primaryPink, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      _routeDistanceKm > 0
                          ? '$_routeDistanceKm km • $_routeDurationMins min road route'
                          : '${activeRestaurant.distanceKm.toStringAsFixed(1)} km road route',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            right: 16,
            top: 150,
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (_userLocation != null) {
                        _mapController.move(_userLocation!, 15.0);
                      } else {
                        _initLiveLocation();
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F24).withValues(alpha: 0.94),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2E313C)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: AppColors.primaryPink,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (activeRestaurant != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _mapController.move(activeRestaurant!.latLng, 15.5);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F24).withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2E313C)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: AppColors.editGreen,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. Bottom Horizontal Carousel of Nearby Restaurants
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info count badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1B20).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryPink.withValues(alpha: 0.28),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          color: AppColors.primaryPink,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_filteredRestaurants.length} Nearby Restaurants around you',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Cards Carousel
                SizedBox(
                  height: 140,
                  child: _filteredRestaurants.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1F24),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF2E313C)),
                            ),
                            child: const Text(
                              'No restaurants found in this filter',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _cardsScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredRestaurants.length,
                          itemBuilder: (context, index) {
                            final rest = _filteredRestaurants[index];
                            final isSelected =
                                rest.restaurantId == _selectedRestaurantId;

                            return Container(
                              width: 286,
                              margin: const EdgeInsets.only(right: 12),
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
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryPink
                                      : AppColors.primaryPink.withValues(alpha: 0.28),
                                  width: isSelected ? 2.0 : 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                  if (isSelected)
                                    BoxShadow(
                                      color: AppColors.primaryPink.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _selectRestaurant(rest,
                                      scrollCarousel: false),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Restaurant Image
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: AppColors.primaryPink.withValues(alpha: 0.25),
                                              width: 1,
                                            ),
                                          ),
                                          child: AppNetworkImage(
                                            imageUrl: rest.logoImage,
                                            width: 72,
                                            height: 72,
                                            borderRadius: 14,
                                            fit: BoxFit.cover,
                                            fallbackIcon: Icons.restaurant_rounded,
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Restaurant Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                rest.name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on_rounded,
                                                    color: AppColors.primaryPink,
                                                    size: 13,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Expanded(
                                                    child: Text(
                                                      '${rest.distanceKm.toStringAsFixed(1)} km • ~${rest.estimatedTimeMins} mins',
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        color: Colors.white70,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),

                                              // Rating & Action Row
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.star_rounded,
                                                        color:
                                                            Color(0xFFFFB800),
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        rest.rating
                                                            .toStringAsFixed(1),
                                                        style:
                                                            const TextStyle(
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  // View Menu Button
                                                  InkWell(
                                                    onTap: () {
                                                      Navigator.of(context)
                                                          .push(
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              RestaurantDetailScreen(
                                                            restaurantId: rest
                                                                .restaurantId,
                                                            restaurantName:
                                                                rest.name,
                                                            logoImage: rest
                                                                .logoImage,
                                                            location:
                                                                rest.address,
                                                            description: rest
                                                                .description,
                                                            phone: rest.phone,
                                                            rating:
                                                                rest.rating,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4.5,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        gradient: const LinearGradient(
                                                          colors: [
                                                            Color(0xFFFA4468),
                                                            Color(0xFFFF6584),
                                                          ],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 1),
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'Menu',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                          SizedBox(width: 2),
                                                          Icon(
                                                            Icons
                                                                .arrow_forward_ios_rounded,
                                                            color: Colors.white,
                                                            size: 9,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = key;
            _applyFilters();
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? null : const Color(0xFF1E1F24),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFA4468), Color(0xFFFF6584)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFFFA4468) : const Color(0xFF2E313C),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
