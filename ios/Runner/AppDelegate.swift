import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Latched once GMSServices has been keyed. GMSServices cannot be
  /// un-initialised, which is why the app-level invariant (spec §2c) is enforced
  /// above the SDK: revocation blocks surfaces and requests, it does not pretend
  /// to tear the SDK down.
  private var mapsSdkInitialized = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Spec §2b: NO GMSServices.provideAPIKey here. Initialisation is deferred to
    // the "initialize" method call, which Dart only issues once maps consent has
    // resolved positively. The old `!key.isEmpty` guard made a launch-time call
    // harmless ONLY while the app shipped keyless; once the keys ship it would
    // initialise Google's SDK on every cold start, for every user, before any UI.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AonMapsSdk") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "aon2026/maps_sdk",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "initialize":
        result(self?.initializeMapsSdk() ?? false)
      case "openSourceLicenseInfo":
        // Static bundled text, not a network call — safe before consent.
        result(GMSServices.openSourceLicenseInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func initializeMapsSdk() -> Bool {
    if mapsSdkInitialized { return true }
    guard let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
          !key.isEmpty else {
      return false // built without the secret → feature stays dark
    }
    GMSServices.provideAPIKey(key)
    mapsSdkInitialized = true
    return true
  }
}
