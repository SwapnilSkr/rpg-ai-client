package com.everloreapp

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.ViewTreeObserver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var flutterDrawn = false
    // A SplashScreenView (Android 12+), kept as View so older phones never load the class.
    private var systemSplash: View? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android removes its launch splash as soon as this activity draws and
        // fades our window in over black, while Flutter's surface is still empty:
        // the icon blinked to black and faded back. Instead, hold the activity's
        // first draw until Flutter has shown a frame, and take the splash over as
        // a view in our own window (Android 12+) so it is removed in one step,
        // over a Flutter frame that shows the same picture.
        val content = findViewById<View>(android.R.id.content)
        content.viewTreeObserver.addOnPreDrawListener(
            object : ViewTreeObserver.OnPreDrawListener {
                override fun onPreDraw(): Boolean {
                    if (!flutterDrawn) return false
                    content.viewTreeObserver.removeOnPreDrawListener(this)
                    return true
                }
            }
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view ->
                if (flutterDrawn) view.remove() else systemSplash = view
            }
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        flutterDrawn = true
        findViewById<View>(android.R.id.content).invalidate()
        // One more frame so Flutter's picture is on screen before the splash
        // view above it goes.
        val splash = systemSplash
        if (splash != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splash.postOnAnimation { (splash as android.window.SplashScreenView).remove() }
        }
        systemSplash = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The notification plugin can ask for the permission but cannot open
        // the app's notification settings, which is where a player who said no
        // has to go to say yes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "everlore/reminders")
            .setMethodCallHandler { call, result ->
                if (call.method == "openNotificationSettings") {
                    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
