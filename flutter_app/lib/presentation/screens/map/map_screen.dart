import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/services/notification_service.dart';
import '../../providers/booking_provider.dart';

// Geofence radius in metres
const _kGeofenceRadius = 50.0;

class MapScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const MapScreen({super.key, required this.bookingId});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  StreamSubscription<DatabaseEvent>? _locationSub;
  StreamSubscription<DocumentSnapshot>? _firestoreLocationSub;
  bool _rtdbHasData = false;
  LatLng? _caregiverLatLng;
  bool _geofenceAlerted = false;

  @override
  void dispose() {
    _locationSub?.cancel();
    _firestoreLocationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _updateCaregiverPosition(LatLng cgLatLng, LatLng jobLatLng) {
    setState(() {
      _caregiverLatLng = cgLatLng;
      _markers.removeWhere((m) => m.markerId.value == 'caregiver');
      _markers.add(Marker(
        markerId: const MarkerId('caregiver'),
        position: cgLatLng,
        infoWindow: const InfoWindow(title: 'Caregiver'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [cgLatLng, jobLatLng],
        color: AppColors.primary,
        width: 3,
        patterns: [PatternItem.dash(16), PatternItem.gap(8)],
      ));
    });

    final dist = _distanceMetres(cgLatLng, jobLatLng);
    if (dist <= _kGeofenceRadius && !_geofenceAlerted) {
      _geofenceAlerted = true;
      NotificationService().showGeofenceAlert('Caregiver has arrived at the care location!');
      _showGeofenceSnackbar();
    }
  }

  void _subscribeToLocation(String caregiverId, LatLng jobLatLng) {
    _locationSub?.cancel();
    _firestoreLocationSub?.cancel();
    _rtdbHasData = false;

    // Primary: Firebase Realtime Database (Flutter caregiver app updates here)
    final ref = FirebaseDatabase.instance.ref('locations/$caregiverId');
    _locationSub = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;
      final map = Map<String, dynamic>.from(data as Map);
      final lat = (map['lat'] as num?)?.toDouble();
      final lng = (map['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      _rtdbHasData = true;
      _updateCaregiverPosition(LatLng(lat, lng), jobLatLng);
    });

    // Fallback: Firestore users collection (Kotlin app updates locationLat/locationLng here)
    _firestoreLocationSub = FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(caregiverId)
        .snapshots()
        .listen((doc) {
      if (_rtdbHasData || !doc.exists) return;
      final data = doc.data()!;
      final lat = (data['locationLat'] as num?)?.toDouble();
      final lng = (data['locationLng'] as num?)?.toDouble();
      if (lat == null || lng == null || (lat == 0 && lng == 0)) return;
      _updateCaregiverPosition(LatLng(lat, lng), jobLatLng);
    });
  }

  void _showGeofenceSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(
        children: [
          Icon(Icons.location_on_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text('Caregiver has arrived!', style: TextStyle(fontFamily: 'Poppins')),
        ],
      ),
      backgroundColor: AppColors.accent,
      duration: Duration(seconds: 5),
    ));
  }

  double _distanceMetres(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(a.latitude)) * cos(_deg2rad(b.latitude)) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(x), sqrt(1 - x));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  Future<void> _launchGoogleMaps(double lat, double lng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open Google Maps',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: bookingAsync.when(
        data: (booking) {
          final jobLat = booking.locationLat;
          final jobLng = booking.locationLng;
          final hasLocation = jobLat != 0 || jobLng != 0;

          if (!hasLocation) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded, size: 56, color: AppColors.textHint),
                  SizedBox(height: 16),
                  Text('Location not available',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  SizedBox(height: 8),
                  Text('Location will appear when the session begins',
                      style: TextStyle(fontSize: 13, color: AppColors.textHint, fontFamily: 'Poppins')),
                ],
              ),
            );
          }

          final jobLatLng = LatLng(jobLat, jobLng);

          // Add/keep job location marker
          if (!_markers.any((m) => m.markerId.value == 'job_location')) {
            _markers.add(Marker(
              markerId: const MarkerId('job_location'),
              position: jobLatLng,
              infoWindow: InfoWindow(title: booking.elderId, snippet: booking.address),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ));
          }

          // Subscribe to caregiver RTDB location
          if (booking.caregiverId != null && _locationSub == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _subscribeToLocation(booking.caregiverId!, jobLatLng);
            });
          }

          return Stack(
            children: [
              GoogleMap(
                onMapCreated: (ctrl) => _mapController = ctrl,
                initialCameraPosition: CameraPosition(target: jobLatLng, zoom: 15),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),

              // Distance info banner
              if (_caregiverLatLng != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 60,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_run_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _formatDistance(_distanceMetres(_caregiverLatLng!, jobLatLng)),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary, fontFamily: 'Poppins'),
                        ),
                        const SizedBox(width: 6),
                        const Text('away',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                      ],
                    ),
                  ),
                ),

              // Recenter button
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: () {
                    final target = _caregiverLatLng ?? jobLatLng;
                    _mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 15)),
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                ),
              ),

              // Info card
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: _LocationCard(
                  elderName: booking.elderId,
                  address: booking.address,
                  status: booking.status.name,
                  hasCaregiverLocation: _caregiverLatLng != null,
                ),
              ),

              // Open in Google Maps button
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: ElevatedButton.icon(
                  onPressed: () => _launchGoogleMaps(jobLat, jobLng),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 20),
                  label: const Text('Open in Google Maps'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDistance(double metres) {
    if (metres < 1000) return '${metres.toStringAsFixed(0)} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }
}

class _LocationCard extends StatelessWidget {
  final String elderName;
  final String address;
  final String status;
  final bool hasCaregiverLocation;

  const _LocationCard({
    required this.elderName,
    required this.address,
    required this.status,
    required this.hasCaregiverLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(elderName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary, fontFamily: 'Poppins')),
                    const SizedBox(height: 2),
                    Text(address,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.accent, fontFamily: 'Poppins')),
              ),
            ],
          ),
          if (!hasCaregiverLocation) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Waiting for caregiver location…',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint, fontFamily: 'Poppins')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
