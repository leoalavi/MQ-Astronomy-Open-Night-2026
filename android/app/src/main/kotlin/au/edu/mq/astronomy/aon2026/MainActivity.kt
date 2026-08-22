package au.edu.mq.astronomy.aon2026

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    // M4: exposes the running app's signing-certificate SHA-1 so the Dart side
    // can send it as the X-Android-Cert header when calling the Routes API with
    // an Android-restricted key. Reading the LIVE cert (not a build-time
    // constant) guarantees the header always matches the shipped signature.
    private val routesIdentityChannel = "au.edu.mq.astronomy.aon2026/routes_identity"

    // Spec §2b. Android has no deferrable Maps SDK init: the SDK reads
    // com.google.android.geo.API_KEY from the manifest when a MapView is first
    // constructed. The invariant is therefore enforced by not CONSTRUCTING a map
    // view before consent — mapsSdkReadyProvider does that. This handler only
    // reports whether a key is present, so "ready" means the same thing on both
    // platforms.
    private val mapsSdkChannel = "aon2026/maps_sdk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, routesIdentityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSigningCertSha1" -> result.success(signingCertSha1())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mapsSdkChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> result.success(hasMapsApiKey())
                    // GoogleApiAvailability.getOpenSourceSoftwareLicenseInfo has
                    // been deprecated since Play services v11.0 and Google states
                    // it is no longer required — Android surfaces Play services
                    // licences at Settings > Google > Open Source Licenses. There
                    // is nothing for the app to render, so the Credits button
                    // hides itself on this platform.
                    "openSourceLicenseInfo" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasMapsApiKey(): Boolean = try {
        val info = packageManager.getApplicationInfo(
            packageName, PackageManager.GET_META_DATA
        )
        !info.metaData?.getString("com.google.android.geo.API_KEY").isNullOrEmpty()
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun signingCertSha1(): String? {
        return try {
            @Suppress("DEPRECATION")
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = packageManager.getPackageInfo(
                    packageName, PackageManager.GET_SIGNING_CERTIFICATES
                )
                info.signingInfo?.apkContentsSigners
            } else {
                packageManager.getPackageInfo(
                    packageName, PackageManager.GET_SIGNATURES
                ).signatures
            }
            val sig = signatures?.firstOrNull() ?: return null
            val digest = MessageDigest.getInstance("SHA-1").digest(sig.toByteArray())
            // Colon-separated uppercase hex, matching keytool / Cloud console
            // display. Exact format is confirmed at T10 against a live
            // accept-correct / reject-wrong verification.
            digest.joinToString(":") { "%02X".format(it) }
        } catch (e: Exception) {
            null
        }
    }
}
