import Flutter
import MapKit
import UIKit

final class AppleMapFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    AppleMapView(frame: frame, id: viewId, args: args, messenger: messenger)
  }
}

private final class CareAnnotation: MKPointAnnotation {
  var identifier = ""
}

final class AppleMapView: NSObject, FlutterPlatformView, MKMapViewDelegate {
  private let map: MKMapView
  private let channel: FlutterMethodChannel
  private var selectable = false
  private var annotations: [String: CareAnnotation] = [:]

  init(frame: CGRect, id: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    map = MKMapView(frame: frame)
    channel = FlutterMethodChannel(name: "golden_hand/apple_map/\(id)", binaryMessenger: messenger)
    super.init()
    map.delegate = self
    map.showsUserLocation = false
    // Leave MapKit's legal attribution visible above the Flutter bottom card.
    map.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 230, right: 0)
    if let data = args as? [String: Any] {
      update(data)
      if selectable {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
      }
      if let center = data["center"] as? [Double], center.count == 2 {
        let zoom = data["zoom"] as? Double ?? 15
        let span = 360 / pow(2, zoom)
        map.setRegion(MKCoordinateRegion(
          center: CLLocationCoordinate2D(latitude: center[0], longitude: center[1]),
          span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)), animated: false)
      }
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let data = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "update": self.update(data); result(nil)
      case "recenter":
        if let coordinate = self.coordinate(data) {
          self.map.setRegion(MKCoordinateRegion(center: coordinate,
            latitudinalMeters: 1500, longitudinalMeters: 1500), animated: true)
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { map }

  private func coordinate(_ data: [String: Any]) -> CLLocationCoordinate2D? {
    guard let lat = data["lat"] as? Double, let lng = data["lng"] as? Double,
          lat.isFinite, lng.isFinite, abs(lat) <= 90, abs(lng) <= 180 else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lng)
  }

  private func update(_ data: [String: Any]) {
    selectable = data["selectable"] as? Bool ?? false
    let markers = data["markers"] as? [[String: Any]] ?? []
    let ids = Set(markers.compactMap { $0["id"] as? String })
    for id in Array(annotations.keys) where !ids.contains(id) {
      if let annotation = annotations.removeValue(forKey: id) { map.removeAnnotation(annotation) }
    }
    for item in markers {
      guard let id = item["id"] as? String, let point = coordinate(item) else { continue }
      let existing = annotations[id]
      let annotation = existing ?? CareAnnotation()
      annotation.identifier = id
      annotation.title = item["title"] as? String
      annotation.subtitle = item["subtitle"] as? String
      annotation.coordinate = point
      if existing == nil { annotations[id] = annotation; map.addAnnotation(annotation) }
    }
    map.removeOverlays(map.overlays)
    for line in data["lines"] as? [[[Double]]] ?? [] {
      let points = line.compactMap { pair -> CLLocationCoordinate2D? in
        guard pair.count == 2 else { return nil }
        return coordinate(["lat": pair[0], "lng": pair[1]])
      }
      if points.count >= 2 { map.addOverlay(MKPolyline(coordinates: points, count: points.count)) }
    }
  }

  @objc private func tapped(_ gesture: UITapGestureRecognizer) {
    guard selectable, gesture.state == .ended else { return }
    let point = map.convert(gesture.location(in: map), toCoordinateFrom: map)
    channel.invokeMethod("tap", arguments: ["lat": point.latitude, "lng": point.longitude])
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard let pin = annotation as? CareAnnotation else { return nil }
    let view = mapView.dequeueReusableAnnotationView(withIdentifier: "care-pin") as? MKMarkerAnnotationView
      ?? MKMarkerAnnotationView(annotation: pin, reuseIdentifier: "care-pin")
    view.annotation = pin
    view.canShowCallout = !(pin.title ?? "").isEmpty
    view.markerTintColor = pin.identifier == "caregiver" ? .systemGreen : .systemBlue
    return view
  }

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
    let renderer = MKPolylineRenderer(polyline: line)
    renderer.strokeColor = .systemBlue
    renderer.lineWidth = 3
    renderer.lineDashPattern = [8, 6]
    return renderer
  }

  func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
    channel.invokeMethod("mapLoaded", arguments: nil)
  }
  func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
    channel.invokeMethod("mapError", arguments: nil)
  }
  deinit { channel.setMethodCallHandler(nil); map.delegate = nil }
}
