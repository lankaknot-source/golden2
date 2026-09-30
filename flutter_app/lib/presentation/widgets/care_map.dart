import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CareMapController {
  final Future<void> Function(LatLng) _move;
  CareMapController(this._move);
  Future<void> moveTo(LatLng target) => _move(target);
}

/// Uses MapKit on iOS so the basemap does not depend on Google API credentials.
/// The same coordinate model is retained for the Android Google Maps renderer.
class CareMap extends StatefulWidget {
  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<CareMapController>? onMapCreated;

  const CareMap({
    super.key,
    required this.initialCameraPosition,
    this.markers = const {},
    this.polylines = const {},
    this.onTap,
    this.onMapCreated,
  });

  Map<String, Object?> get nativeData => {
    'center': [
      initialCameraPosition.target.latitude,
      initialCameraPosition.target.longitude,
    ],
    'zoom': initialCameraPosition.zoom,
    'selectable': onTap != null,
    'markers':
        markers
            .map(
              (m) => {
                'id': m.markerId.value,
                'lat': m.position.latitude,
                'lng': m.position.longitude,
                'title': m.infoWindow.title ?? '',
                'subtitle': m.infoWindow.snippet ?? '',
              },
            )
            .toList(),
    'lines':
        polylines
            .map((p) => p.points.map((c) => [c.latitude, c.longitude]).toList())
            .toList(),
  };

  @override
  State<CareMap> createState() => _CareMapState();
}

class _CareMapState extends State<CareMap> {
  MethodChannel? _channel;
  GoogleMapController? _google;
  String? _error;
  int _generation = 0;

  @override
  void didUpdateWidget(CareMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_channel != null) unawaited(_send('update', widget.nativeData));
  }

  Future<void> _send(String method, Object? data) async {
    try {
      await _channel?.invokeMethod<void>(method, data);
    } on PlatformException {
      if (mounted) {
        setState(() => _error = 'Unable to load the map. Please retry.');
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => _error = 'Unable to load the map. Please retry.');
      }
    }
  }

  void _created(int id) {
    if (!mounted) return;
    _channel = MethodChannel('golden_hand/apple_map/$id');
    _channel!.setMethodCallHandler((call) async {
      if (!mounted) return;
      if (call.method == 'tap') {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        widget.onTap?.call(
          LatLng(
            (args['lat'] as num).toDouble(),
            (args['lng'] as num).toDouble(),
          ),
        );
      } else if (call.method == 'mapError') {
        setState(
          () => _error = 'Map could not load. Check your connection and retry.',
        );
      } else if (call.method == 'mapLoaded') {
        setState(() => _error = null);
      }
    });
    unawaited(_send('update', widget.nativeData));
    widget.onMapCreated?.call(
      CareMapController(
        (target) => _send('recenter', {
          'lat': target.latitude,
          'lng': target.longitude,
        }),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _google?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return GoogleMap(
        initialCameraPosition: widget.initialCameraPosition,
        markers: widget.markers,
        polylines: widget.polylines,
        onTap: widget.onTap,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        onMapCreated: (controller) {
          _google = controller;
          widget.onMapCreated?.call(
            CareMapController(
              (target) => controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: target, zoom: 15),
                ),
              ),
            ),
          );
        },
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: UiKitView(
            key: ValueKey(_generation),
            viewType: 'golden_hand/apple_map',
            creationParams: widget.nativeData,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _created,
          ),
        ),
        if (_error != null)
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () {
                        _channel?.setMethodCallHandler(null);
                        _channel = null;
                        setState(() {
                          _error = null;
                          _generation++;
                        });
                      },
                      child: const Text('Retry map'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
