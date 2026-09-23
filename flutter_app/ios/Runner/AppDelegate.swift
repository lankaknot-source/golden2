import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // google_maps_flutter requires the iOS SDK key before any GoogleMap widget
    // is created. The value is injected as GOOGLE_MAPS_API_KEY by Codemagic;
    // keep it out of source control and restrict it to this bundle ID in
    // Google Cloud.
    let configuredMapsKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
    let firebaseConfig = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
        .flatMap { NSDictionary(contentsOfFile: $0) }
    let mapsKey = (configuredMapsKey?.hasPrefix("$(") == false ? configuredMapsKey : nil)
        ?? firebaseConfig?["API_KEY"] as? String
    if let mapsKey, !mapsKey.isEmpty {
      GMSServices.provideAPIKey(mapsKey)
    }

    // Push notifications: become the UNUserNotificationCenter delegate so that
    // foreground notifications and notification taps are delivered to
    // firebase_messaging / flutter_local_notifications. With Firebase method
    // swizzling enabled (default), the APNs token is forwarded to FCM automatically.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
