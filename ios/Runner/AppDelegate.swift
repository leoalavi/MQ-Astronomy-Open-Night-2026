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
        // One-key wiring: Dart passes MAPS_API_KEY (from `.env`) as `apiKey`,
        // so the SDK can be keyed at consent time without a separate Xcode
        // build setting. A nil/empty arg falls back to Info.plist GMSApiKey.
        let key = (call.arguments as? [String: Any])?["apiKey"] as? String
        result(self?.initializeMapsSdk(overrideKey: key) ?? false)
      case "getMapsKey":
        // Configuration READ only — keys nothing, contacts nobody, so it is
        // safe before consent. Lets Dart detect (and reuse) a well-keyed
        // platform even when the app was launched without
        // --dart-define-from-file=.env. The value never leaves the process.
        let plistKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
        result((plistKey ?? "").isEmpty ? nil : plistKey)
      case "openSourceLicenseInfo":
        // Static bundled text, not a network call — safe before consent.
        result(GMSServices.openSourceLicenseInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func initializeMapsSdk(overrideKey: String? = nil) -> Bool {
    if mapsSdkInitialized { return true }
    // Prefer the Dart-supplied key (single source: MAPS_API_KEY from `.env`);
    // fall back to the Info.plist GMSApiKey for the old two-file setup.
    let plistKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
    let key = (overrideKey?.isEmpty == false) ? overrideKey : plistKey
    guard let key = key, !key.isEmpty else {
      return false // no key anywhere → feature stays dark
    }
    GMSServices.provideAPIKey(key)
    mapsSdkInitialized = true
    return true
  }
}
