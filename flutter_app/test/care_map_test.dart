import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:golden_hand_care/presentation/widgets/care_map.dart';

void main() {
  test('MapKit receives job and caregiver coordinates and connecting line', () {
    const job = LatLng(6.9271, 79.8612);
    const caregiver = LatLng(6.93, 79.86);
    final map = CareMap(
      initialCameraPosition: const CameraPosition(target: job, zoom: 15),
      markers: {
        const Marker(
          markerId: MarkerId('job_location'),
          position: job,
          infoWindow: InfoWindow(title: 'Care location', snippet: 'Colombo'),
        ),
        const Marker(markerId: MarkerId('caregiver'), position: caregiver),
      },
      polylines: {
        const Polyline(
          polylineId: PolylineId('route'),
          points: [caregiver, job],
        ),
      },
    );
    expect(map.nativeData['center'], [6.9271, 79.8612]);
    expect(map.nativeData['selectable'], false);
    final markers = map.nativeData['markers'] as List;
    expect(markers.length, 2);
    expect(markers.first['subtitle'], 'Colombo');
    expect(map.nativeData['lines'], [
      [
        [6.93, 79.86],
        [6.9271, 79.8612],
      ],
    ]);
  });

  test('location picker enables native tap handling', () {
    final map = CareMap(
      initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
      onTap: (_) {},
    );
    expect(map.nativeData['selectable'], true);
    expect(map.nativeData['markers'], isEmpty);
  });

  test('recenter forwards latest caregiver position', () async {
    LatLng? received;
    final controller = CareMapController((target) async {
      received = target;
    });
    await controller.moveTo(const LatLng(7.1, 80.2));
    expect(received, const LatLng(7.1, 80.2));
  });
}
