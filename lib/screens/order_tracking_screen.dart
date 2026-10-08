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
import 'nearby_restaurants_map_screen.dart';
import 'restaurant_detail_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> initialOrderData;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.initialOrderData,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final MapController _mapController = MapController();

  LatLng? _userLocation;
  LatLng _restaurantLocation = const LatLng(31.5204, 74.3587); // Default Lahore / Central
  bool _isLoadingLocation = true;
  String _locationStatusMessage = 'Locating your live delivery address...';
  StreamSubscription<Position>? _positionStreamSub;
  List<Map<String, dynamic>> _otherNearbyRestaurants = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _restaurantsSub;

  // Real Road Directions State
  List<LatLng> _routePoints = [];
  double _routeDistanceKm = 0.0;
  int _routeDurationMins = 0;
  bool _isLoadingRoute = false;
  bool _isRealRoad = false;

  @override
  void initState() {
    super.initState();
    _initLiveLocation();
    _listenToNearbyRestaurants();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _restaurantsSub?.cancel();
    super.dispose();
  }

  void _confirmCancelAndDeleteOrder(String itemName) {
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
                Icons.delete_outline_rounded,
                color: AppColors.primaryPink,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Cancel & Delete Order',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel and delete your order for "$itemName"? This order will be permanently deleted from Firestore.',
          style: const TextStyle(
            fontSize: 13.5,
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'No, Keep',
              style: TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(widget.orderId)
                    .delete();
                if (mounted) {
                  Navigator.of(context).pop(); // Go back to orders list
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Order "$itemName" cancelled and deleted.',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1E1F24),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.primaryPink.withValues(alpha: 0.3),
                        ),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel order: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Yes, Cancel & Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchRoadRoute() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRoute = true;
    });

    final userPt = _userLocation ?? const LatLng(31.5204, 74.3587);
    final restPt = _restaurantLocation;

    try {
      final routeInfo = await RouteService.fetchRoadRoute(
        start: restPt,
        destination: userPt,
      );

      if (mounted) {
        setState(() {
          _routePoints = routeInfo.points;
          _routeDistanceKm = routeInfo.distanceKm;
          _routeDurationMins = routeInfo.durationMinutes;
          _isRealRoad = routeInfo.isRealRoad;
          _isLoadingRoute = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching live road route: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  void _listenToNearbyRestaurants() {
    _restaurantsSub = FirebaseFirestore.instance
        .collection('restaurants')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final userCenter = _userLocation ?? const LatLng(31.5204, 74.3587);
      final List<Map<String, dynamic>> list = [];
      LatLng? matchedOrderRestLatLng;

      final targetRestName = (widget.initialOrderData['restaurant_name'] ?? '').toString().toLowerCase().trim();
      final targetRestId = (widget.initialOrderData['restaurant_id'] ?? '').toString().trim();

      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();

        final rId = (data['restaurant_id'] ?? data['unique_id'] ?? doc.id).toString();
        final rName = (data['restaurant_name'] ?? data['name'] ?? 'Restaurant').toString();
        final rRating = (data['rating'] as num?)?.toDouble() ??
            (data['avg_rating'] as num?)?.toDouble() ??
            4.8;

        double? lat = (data['latitude'] as num?)?.toDouble();
        double? lng = (data['longitude'] as num?)?.toDouble();

        if (lat == null || lng == null || (lat == 0 && lng == 0)) {
          final hash = doc.id.hashCode.abs();
          final angle = (hash % 360) * (math.pi / 180.0) + (i * 0.85);
          final radiusKm = 0.5 + ((hash % 25) / 10.0);
          final deltaLat = (radiusKm / 111.0) * math.cos(angle);
          final deltaLng = (radiusKm / (111.0 * math.cos(userCenter.latitude * (math.pi / 180.0)))) *
              math.sin(angle);

          lat = userCenter.latitude + deltaLat;
          lng = userCenter.longitude + deltaLng;
        }

        final currentLatLng = LatLng(lat, lng);
        list.add({
          'id': rId,
          'name': rName,
          'rating': rRating,
          'latLng': currentLatLng,
          'data': data,
        });

        if (targetRestId.isNotEmpty && rId == targetRestId) {
          matchedOrderRestLatLng = currentLatLng;
        } else if (targetRestName.isNotEmpty && rName.toLowerCase().trim() == targetRestName) {
          matchedOrderRestLatLng = currentLatLng;
        }
      }

      setState(() {
        _otherNearbyRestaurants = list;
        if (matchedOrderRestLatLng != null) {
          _restaurantLocation = matchedOrderRestLatLng;
        }
      });

      _fetchRoadRoute();
    });
  }

  Future<void> _initLiveLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatusMessage = 'Requesting GPS permission...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatusMessage = 'GPS Service disabled. Using estimated map location.';
          _userLocation = const LatLng(31.5204, 74.3587);
          _restaurantLocation = const LatLng(31.5304, 74.3687);
          _isLoadingLocation = false;
        });
        _fetchRoadRoute();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatusMessage = 'Location permission denied. Showing default route.';
            _userLocation = const LatLng(31.5204, 74.3587);
            _restaurantLocation = const LatLng(31.5304, 74.3687);
            _isLoadingLocation = false;
          });
          _fetchRoadRoute();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatusMessage = 'Location permission denied permanently.';
          _userLocation = const LatLng(31.5204, 74.3587);
          _restaurantLocation = const LatLng(31.5304, 74.3687);
          _isLoadingLocation = false;
        });
        _fetchRoadRoute();
        return;
      }

      // Fetch accurate GPS position
      final Position currentPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final userLatLong = LatLng(currentPos.latitude, currentPos.longitude);
      // Create an offset for restaurant (~1.2 km away)
      final restLatLong = LatLng(
        currentPos.latitude + 0.0095,
        currentPos.longitude + 0.0085,
      );

      if (mounted) {
        setState(() {
          _userLocation = userLatLong;
          _restaurantLocation = restLatLong;
          _isLoadingLocation = false;
          _locationStatusMessage = 'Live GPS Connected';
        });

        // Center map nicely
        _mapController.move(userLatLong, 14.5);
        _fetchRoadRoute();
      }

      // Start listening to live location stream
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position pos) {
        if (mounted) {
          setState(() {
            _userLocation = LatLng(pos.latitude, pos.longitude);
          });
          _fetchRoadRoute();
        }
      });
    } catch (e) {
      debugPrint('Error getting GPS location: $e');
      if (mounted) {
        setState(() {
          _userLocation = const LatLng(31.5204, 74.3587);
          _restaurantLocation = const LatLng(31.5304, 74.3687);
          _isLoadingLocation = false;
          _locationStatusMessage = 'Live map active';
        });
        _fetchRoadRoute();
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'preparing':
      case 'in progress':
        return const Color(0xFF2979FF);
      case 'ready':
      case 'on the way':
        return const Color(0xFFFF9100);
      case 'completed':
      case 'delivered':
        return const Color(0xFF00E676);
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFFF5252);
      case 'ordered':
      case 'pending':
      default:
        return const Color(0xFFFF6D00);
    }
  }

  int _getStatusStepIndex(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
      case 'pending':
        return 1;
      case 'preparing':
      case 'in progress':
        return 2;
      case 'ready':
      case 'on the way':
        return 3;
      case 'delivered':
      case 'completed':
        return 4;
      case 'cancelled':
      case 'rejected':
        return -1;
      default:
        return 1;
    }
  }

  String _getStatusHeading(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
      case 'pending':
        return 'Order Placed! 🍽️';
      case 'preparing':
      case 'in progress':
        return 'In The Kitchen! 👨‍🍳';
      case 'ready':
      case 'on the way':
        return 'Out For Delivery! 🛵';
      case 'delivered':
      case 'completed':
        return 'Delivered! 🎉';
      case 'cancelled':
      case 'rejected':
        return 'Order Cancelled ❌';
      default:
        return 'Order Processing';
    }
  }

  String _getStatusSubtitle(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
      case 'pending':
        return 'Restaurant has received your order & will prepare it shortly.';
      case 'preparing':
      case 'in progress':
        return 'The chef is currently preparing your delicious fresh meal.';
      case 'ready':
      case 'on the way':
        return 'Your meal is ready and rider is on the way to your live address.';
      case 'delivered':
      case 'completed':
        return 'Your order has been delivered successfully. Enjoy your meal!';
      case 'cancelled':
      case 'rejected':
        return 'This order has been cancelled by the restaurant or user.';
      default:
        return 'We are keeping you updated in real-time.';
    }
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF26272E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: AppColors.primaryPink.withValues(alpha: 0.7),
          size: 30,
        ),
      ),
    );
  }

  bool _isUsableImage(String str) {
    final clean = str.trim();
    if (clean.isEmpty) return false;
    if (clean.startsWith('http://') || clean.startsWith('https://')) return true;
    if (clean.startsWith('data:image') || clean.length > 200) return true;
    try {
      final f = File(clean);
      return f.existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveExactOrderItemImage(Map<String, dynamic> data) async {
    // 1. Direct picture in order document
    final String directPic = (
      data['item_pic'] ??
      data['prod_pic'] ??
      data['imageUrl'] ??
      data['image_url'] ??
      data['item_image'] ??
      data['image'] ??
      data['pic'] ??
      data['photoUrl'] ??
      data['product_pic'] ??
      data['img'] ??
      ''
    ).toString().trim();

    if (_isUsableImage(directPic)) {
      return directPic;
    }

    final String itemId = (data['item_id'] ?? data['prod_id'] ?? data['id'] ?? '').toString().trim();
    final String itemName = (data['item_name'] ?? data['name'] ?? data['prod_name'] ?? '').toString().trim();

    // 2. Fetch by Item ID in 'items' collection
    if (itemId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('items').doc(itemId).get();
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      // Try 'products' collection
      try {
        final doc = await FirebaseFirestore.instance.collection('products').doc(itemId).get();
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      // Query where item_id == itemId
      try {
        final q = await FirebaseFirestore.instance.collection('items').where('item_id', isEqualTo: itemId).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      // Query where prod_id == itemId
      try {
        final q = await FirebaseFirestore.instance.collection('products').where('prod_id', isEqualTo: itemId).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}
    }

    // 3. Fetch by Item Name in 'items' or 'products'
    if (itemName.isNotEmpty) {
      try {
        final q = await FirebaseFirestore.instance.collection('items').where('item_name', isEqualTo: itemName).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      try {
        final q = await FirebaseFirestore.instance.collection('products').where('prod_name', isEqualTo: itemName).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}

      // Scan items collection for case-insensitive match
      try {
        final snap = await FirebaseFirestore.instance.collection('items').get();
        final lowerName = itemName.toLowerCase().trim();
        for (final doc in snap.docs) {
          final d = doc.data();
          final dName = (d['item_name'] ?? d['prod_name'] ?? d['name'] ?? '').toString().toLowerCase().trim();
          if (dName == lowerName || (dName.isNotEmpty && (dName.contains(lowerName) || lowerName.contains(dName)))) {
            final p = (d['item_pic'] ?? d['prod_pic'] ?? d['imageUrl'] ?? d['image_url'] ?? d['image'] ?? d['pic'] ?? '').toString().trim();
            if (_isUsableImage(p)) return p;
          }
        }
      } catch (_) {}
    }

    // 4. Try Category if available
    final String catId = (data['category_id'] ?? data['cat_id'] ?? '').toString().trim();
    final String catName = (data['category_name'] ?? data['cat_name'] ?? '').toString().trim();
    if (catId.isNotEmpty) {
      try {
        final cDoc = await FirebaseFirestore.instance.collection('categories').doc(catId).get();
        if (cDoc.exists && cDoc.data() != null) {
          final d = cDoc.data()!;
          final p = (d['cat_pic'] ?? d['category_pic'] ?? d['imageUrl'] ?? d['image'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}
    }

    if (catName.isNotEmpty) {
      try {
        final cSnap = await FirebaseFirestore.instance.collection('categories').where('category_name', isEqualTo: catName).limit(1).get();
        if (cSnap.docs.isNotEmpty) {
          final d = cSnap.docs.first.data();
          final p = (d['cat_pic'] ?? d['category_pic'] ?? d['imageUrl'] ?? d['image'] ?? '').toString().trim();
          if (_isUsableImage(p)) return p;
        }
      } catch (_) {}
    }

    if (directPic.isNotEmpty) return directPic;
    return null;
  }

  Widget _buildOrderItemImage(Map<String, dynamic> data) {
    return FutureBuilder<String?>(
      future: _resolveExactOrderItemImage(data),
      builder: (context, snapshot) {
        final String imgUrl = snapshot.data ?? '';
        if (imgUrl.isNotEmpty) {
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryPink.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: AppNetworkImage(
              imageUrl: imgUrl,
              width: 70,
              height: 70,
              borderRadius: 14,
              fit: BoxFit.cover,
              fallbackIcon: Icons.fastfood_rounded,
            ),
          );
        }
        return _buildFallbackImage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> data = widget.initialOrderData;
        if (snapshot.hasData && snapshot.data?.data() != null) {
          data = snapshot.data!.data()!;
        }

        final itemName = (data['item_name'] ?? data['name'] ?? 'Dish').toString();
        final restaurantName = (data['restaurant_name'] ?? 'Restaurant').toString();

        final qtyRaw = data['quantity'] ?? 1;
        final int quantity = qtyRaw is num ? qtyRaw.toInt() : (int.tryParse(qtyRaw.toString()) ?? 1);

        final priceRaw = data['item_price'] ?? data['price'] ?? 0.0;
        final double itemPrice = priceRaw is num ? priceRaw.toDouble() : (double.tryParse(priceRaw.toString()) ?? 0.0);

        final totalRaw = data['total_price'] ?? (itemPrice * quantity);
        final double totalPrice = totalRaw is num ? totalRaw.toDouble() : (double.tryParse(totalRaw.toString()) ?? (itemPrice * quantity));

        final status = (data['status'] ?? 'ordered').toString();
        final statusColor = _getStatusColor(status);
        final currentStep = _getStatusStepIndex(status);

        String orderTime = '';
        if (data['createdAt'] is Timestamp) {
          final dt = (data['createdAt'] as Timestamp).toDate();
          orderTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} • ${dt.day}/${dt.month}/${dt.year}';
        } else if (data['updatedAt'] is Timestamp) {
          final dt = (data['updatedAt'] as Timestamp).toDate();
          orderTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} • ${dt.day}/${dt.month}/${dt.year}';
        }

        final userPt = _userLocation ?? const LatLng(31.5204, 74.3587);
        final restPt = _restaurantLocation;

        // Calculate rider position along road route based on order status step
        LatLng riderPt = restPt;
        if (_routePoints.isNotEmpty) {
          if (currentStep <= 1) {
            riderPt = _routePoints.first;
          } else if (currentStep == 2) {
            final idx = (_routePoints.length * 0.25).floor().clamp(0, _routePoints.length - 1);
            riderPt = _routePoints[idx];
          } else if (currentStep == 3) {
            final idx = (_routePoints.length * 0.65).floor().clamp(0, _routePoints.length - 1);
            riderPt = _routePoints[idx];
          } else if (currentStep >= 4) {
            riderPt = _routePoints.last;
          }
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1F24),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF2E313C),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: AppColors.primaryPink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Order Tracking',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _confirmCancelAndDeleteOrder(
                              itemName),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C1920),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.deleteIcon.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.deleteIcon,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Interactive Real-Time Map with Live GPS & Real Road Delivery Route
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.primaryPink.withValues(alpha: 0.28),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: userPt,
                                    initialZoom: 14.5,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.example.restaurant_management_system',
                                    ),
                                    // Real Turn-by-Turn Road Route Navigation Polylines
                                    PolylineLayer(
                                      polylines: [
                                        // Base shadow outline
                                        Polyline(
                                          points: _routePoints.isNotEmpty ? _routePoints : [restPt, userPt],
                                          color: const Color(0xFF1E242B).withValues(alpha: 0.35),
                                          strokeWidth: 7.5,
                                        ),
                                        // White road casing
                                        Polyline(
                                          points: _routePoints.isNotEmpty ? _routePoints : [restPt, userPt],
                                          color: Colors.white,
                                          strokeWidth: 5.5,
                                        ),
                                        // Main active turn-by-turn road route
                                        Polyline(
                                          points: _routePoints.isNotEmpty ? _routePoints : [restPt, userPt],
                                          color: AppColors.primaryPink,
                                          strokeWidth: 3.5,
                                        ),
                                      ],
                                    ),
                                    // Markers: User GPS Location, Current Restaurant, Rider & Nearby Restaurants
                                    MarkerLayer(
                                      markers: [
                                        // Other Nearby Restaurants Markers with Name Badges
                                        ..._otherNearbyRestaurants.map((rest) {
                                          final name = (rest['name'] ?? 'Restaurant').toString();
                                          final rating = (rest['rating'] as num?)?.toDouble() ?? 4.8;
                                          final latLng = rest['latLng'] as LatLng;
                                          final dataMap = rest['data'] as Map<String, dynamic>;

                                          return Marker(
                                            point: latLng,
                                            width: 120,
                                            height: 58,
                                            alignment: Alignment.bottomCenter,
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => RestaurantDetailScreen(
                                                      restaurantId: (dataMap['restaurant_id'] ?? dataMap['unique_id'] ?? rest['id']).toString(),
                                                      restaurantName: name,
                                                      logoImage: (dataMap['logo_image'] ?? dataMap['logo'] ?? '').toString(),
                                                      location: (dataMap['location'] ?? dataMap['address'] ?? 'Nearby').toString(),
                                                      description: (dataMap['user_description'] ?? dataMap['description'] ?? '').toString(),
                                                      phone: (dataMap['phone'] ?? '').toString(),
                                                      rating: rating,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF1E1F24),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFF2E313C), width: 1),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.2),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 1),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            name,
                                                            style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w800,
                                                              color: Colors.white,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 2),
                                                        const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 10),
                                                        Text(
                                                          rating.toStringAsFixed(1),
                                                          style: const TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w700,
                                                            color: Colors.white70,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF1E1F24),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: AppColors.primaryPink, width: 2),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.25),
                                                          blurRadius: 4,
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.restaurant_rounded,
                                                        color: AppColors.primaryPink,
                                                        size: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),

                                        // User Marker (Destination)
                                        Marker(
                                          point: userPt,
                                          width: 120,
                                          height: 64,
                                          alignment: Alignment.bottomCenter,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1976D2),
                                                  borderRadius: BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.2),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                child: const Text(
                                                  'Your Location',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1976D2),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2.5),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.3),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.person_pin_circle_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Current Order Restaurant Marker (Origin)
                                        Marker(
                                          point: restPt,
                                          width: 130,
                                          height: 64,
                                          alignment: Alignment.bottomCenter,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryPink,
                                                  borderRadius: BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.2),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  restaurantName,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryPink,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2.5),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.3),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.restaurant_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Delivery Rider Marker (Moving on the actual road route)
                                        if (currentStep >= 2 && currentStep <= 3)
                                          Marker(
                                            point: riderPt,
                                            width: 110,
                                            height: 60,
                                            alignment: Alignment.bottomCenter,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE65100),
                                                    borderRadius: BorderRadius.circular(8),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.2),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 11),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        'Rider On Road',
                                                        style: TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w800,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF57C00),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2.2),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFFF57C00).withValues(alpha: 0.45),
                                                        blurRadius: 7,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.two_wheeler_rounded,
                                                      color: Colors.white,
                                                      size: 17,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Live GPS Status Badge overlay
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1F24).withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF2E313C)),
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
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _isLoadingLocation ? Colors.orange : AppColors.editGreen,
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
                                          _locationStatusMessage,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Expand to Full Map / Explore Nearby Restaurants button (Top Right)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Material(
                                    color: const Color(0xFF1E1F24).withValues(alpha: 0.94),
                                    borderRadius: BorderRadius.circular(12),
                                    elevation: 4,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => NearbyRestaurantsMapScreen(
                                              initialUserLocation: _userLocation,
                                              selectedRestaurantId: (data['restaurant_id'] ?? '').toString(),
                                              orderId: widget.orderId,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF2E313C)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.fullscreen_rounded,
                                              color: AppColors.primaryPink,
                                              size: 20,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Full Map',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primaryPink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Live Street Route Stats Pill (Bottom Left)
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1F24).withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF2E313C)),
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
                                          _isLoadingRoute
                                              ? 'Routing streets...'
                                              : '${_routeDistanceKm > 0 ? '$_routeDistanceKm km' : '~1.2 km'} • ${_routeDurationMins > 0 ? '$_routeDurationMins min' : '5 min'} ${_isRealRoad ? 'street navigation' : 'road route'}',
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

                                // Re-center GPS Button overlay (Bottom Right)
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: Material(
                                    color: const Color(0xFF1E1F24).withValues(alpha: 0.94),
                                    borderRadius: BorderRadius.circular(12),
                                    elevation: 4,
                                    child: InkWell(
                                      onTap: () {
                                        if (_userLocation != null) {
                                          _mapController.move(_userLocation!, 15.0);
                                        } else {
                                          _initLiveLocation();
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF2E313C)),
                                        ),
                                        child: const Icon(
                                          Icons.my_location_rounded,
                                          color: AppColors.primaryPink,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Dedicated Explore Nearby Restaurants Card
                        Container(
                          margin: const EdgeInsets.fromLTRB(20, 8, 20, 14),
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
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.primaryPink.withValues(alpha: 0.28),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: AppColors.primaryPink.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => NearbyRestaurantsMapScreen(
                                      initialUserLocation: _userLocation,
                                      selectedRestaurantId: (data['restaurant_id'] ?? '').toString(),
                                      orderId: widget.orderId,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryPink.withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.primaryPink.withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.map_rounded,
                                        color: AppColors.primaryPink,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Explore Nearby Restaurants',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'View all open restaurants around your live location',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: AppColors.primaryPink,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // 2. Real-Time Status Heading Banner
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(16),
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
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.2),
                                ),
                                child: Icon(
                                  currentStep == 4
                                      ? Icons.check_circle_rounded
                                      : currentStep == 3
                                          ? Icons.delivery_dining_rounded
                                          : currentStep == 2
                                              ? Icons.soup_kitchen_rounded
                                              : currentStep == -1
                                                  ? Icons.cancel_rounded
                                                  : Icons.restaurant_menu_rounded,
                                  color: statusColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getStatusHeading(status),
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _getStatusSubtitle(status),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white70,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 3. Step-by-Step Live Tracking Stepper
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(18),
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
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryPink.withValues(alpha: 0.28),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: AppColors.primaryPink.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Progress Timeline',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 18),

                              _buildTimelineStep(
                                title: 'Order Placed',
                                description: 'Restaurant confirmed your order',
                                time: orderTime,
                                stepNumber: 1,
                                currentStep: currentStep,
                                isLast: false,
                              ),
                              _buildTimelineStep(
                                title: 'Preparing Food',
                                description: 'Chef is cooking your fresh meal',
                                stepNumber: 2,
                                currentStep: currentStep,
                                isLast: false,
                              ),
                              _buildTimelineStep(
                                title: 'Ready / On The Way',
                                description: 'Delivery rider is heading to you',
                                stepNumber: 3,
                                currentStep: currentStep,
                                isLast: false,
                              ),
                              _buildTimelineStep(
                                title: 'Delivered',
                                description: 'Order completed & delivered',
                                stepNumber: 4,
                                currentStep: currentStep,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 4. Order Summary & Price Breakdown Card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(18),
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
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryPink.withValues(alpha: 0.28),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: AppColors.primaryPink.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ordered Items',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  _buildOrderItemImage(data),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (restaurantName.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            restaurantName,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFFFF6584),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rs. ${itemPrice.toStringAsFixed(2)} × $quantity',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF5277),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),
                              Divider(height: 1, color: const Color(0xFF2E313C).withValues(alpha: 0.7)),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Bill Paid / Due:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF5277),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String description,
    String? time,
    required int stepNumber,
    required int currentStep,
    required bool isLast,
  }) {
    final bool isCompleted = currentStep >= stepNumber;
    final bool isCurrent = currentStep == stepNumber;
    final Color activeColor = isCompleted ? AppColors.editGreen : const Color(0xFF4A4E5C);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stepper Indicator Column
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.editGreen : const Color(0xFF1E1F24),
                shape: BoxShape.circle,
                border: Border.all(
                  color: activeColor,
                  width: isCompleted ? 0 : 2,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.editGreen.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : Text(
                        '$stepNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2.5,
                height: 42,
                color: isCompleted && currentStep > stepNumber
                    ? AppColors.editGreen
                    : const Color(0xFF2E313C),
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Step Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: isCompleted ? FontWeight.w800 : FontWeight.w600,
                          color: isCompleted ? Colors.white : Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted ? Colors.white70 : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                if (time != null && time.isNotEmpty)
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
