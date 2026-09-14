import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_view_model.dart';
import '../auth/login_screen.dart'; // For colors

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MapViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.uiState;
        
        // Use client location as center if available, else caregiver location
        final centerLat = state.clientLat != 0.0 ? state.clientLat : (state.caregiverLat != 0.0 ? state.caregiverLat : 6.9271);
        final centerLng = state.clientLng != 0.0 ? state.clientLng : (state.caregiverLng != 0.0 ? state.caregiverLng : 79.8612);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('Live Tracking', style: TextStyle(color: Colors.white, fontSize: 18)),
            backgroundColor: darkBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
              : Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(centerLat, centerLng),
                        initialZoom: 14.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.kina.care.flutter',
                        ),
                        MarkerLayer(
                          markers: [
                            if (state.clientLat != 0.0 && state.clientLng != 0.0)
                              Marker(
                                point: LatLng(state.clientLat, state.clientLng),
                                width: 50,
                                height: 50,
                                child: const Icon(Icons.home, color: Colors.blue, size: 40),
                              ),
                            if (state.caregiverLat != 0.0 && state.caregiverLng != 0.0)
                              Marker(
                                point: LatLng(state.caregiverLat, state.caregiverLng),
                                width: 50,
                                height: 50,
                                child: const Icon(Icons.directions_walk, color: Colors.green, size: 40),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (state.activeBooking != null)
                      Positioned(
                        bottom: 24,
                        left: 24,
                        right: 24,
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Active Job: ${state.activeBooking!.careCategory}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                Text(
                                  "Distance: ${(state.distanceInMeters / 1000).toStringAsFixed(2)} km",
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                if (state.role == "CAREGIVER" && state.distanceInMeters > 50)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text("Warning: You are too far from the patient location!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  )
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
