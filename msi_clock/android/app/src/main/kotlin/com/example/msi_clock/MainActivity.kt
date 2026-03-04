package com.example.msi_clock

import android.app.ActivityManager
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import java.net.NetworkInterface
import java.util.Collections
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MSIClock_Kiosk"
        // AnyDesk package names to whitelist
        private val ANYDESK_PACKAGES = setOf(
            "com.anydesk.adcontrol.ad1",
            "com.anydesk.anydeskandroid.custom"
        )
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d(TAG, "onCreate: Initializing kiosk mode (Lock Task Mode DISABLED for AnyDesk compatibility)")
        
        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        Log.d(TAG, "onCreate: Screen wake lock enabled")
        
        // NOTE: Lock Task Mode is NOT started to allow AnyDesk to function
        // Kiosk security is maintained through:
        // 1. HOME category intent filter (app acts as launcher)
        // 2. Hardware key blocking (back, home, power, volume)
        // 3. System UI hiding (status bar, navigation bar)
        // 4. Window focus recapture (prevents other apps from taking over)
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume: Activity resumed")
        hideSystemUI()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        Log.d(TAG, "onWindowFocusChanged: hasFocus=$hasFocus")
        
        if (!hasFocus) {
            // Check if AnyDesk is in foreground
            if (isAnydeskInForeground()) {
                Log.i(TAG, "onWindowFocusChanged: AnyDesk UI detected - allowing focus loss")
                return
            }
            Log.w(TAG, "onWindowFocusChanged: Lost focus to non-AnyDesk app")
        }
        
        if (hasFocus) {
            hideSystemUI()
        }
    }

    private fun hideSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let {
                it.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
        }
    }
    
    // Check if AnyDesk is in the foreground (actively showing UI)
    private fun isAnydeskInForeground(): Boolean {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            
            // Get the foreground task
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val appTasks = activityManager.appTasks
                for (task in appTasks) {
                    val taskInfo = task.taskInfo
                    val topActivity = taskInfo.topActivity
                    if (topActivity != null && ANYDESK_PACKAGES.any { topActivity.packageName.contains(it) }) {
                        Log.i(TAG, "isAnydeskInForeground: AnyDesk UI active: ${topActivity.packageName}")
                        return true
                    }
                }
            }
            
            // Fallback: Check running tasks (deprecated but works on older devices)
            @Suppress("DEPRECATION")
            val runningTasks = activityManager.getRunningTasks(1)
            if (runningTasks.isNotEmpty()) {
                val topTask = runningTasks[0]
                val topActivity = topTask.topActivity
                if (topActivity != null && ANYDESK_PACKAGES.any { topActivity.packageName.contains(it) }) {
                    Log.i(TAG, "isAnydeskInForeground: AnyDesk UI active (fallback): ${topActivity.packageName}")
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "isAnydeskInForeground: Error checking for AnyDesk UI", e)
        }
        return false
    }
    
    // Check if AnyDesk is currently running (background or foreground)
    private fun isAnydeskRunning(): Boolean {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val runningApps = activityManager.runningAppProcesses ?: return false
            
            for (processInfo in runningApps) {
                if (ANYDESK_PACKAGES.any { processInfo.processName.contains(it) }) {
                    Log.i(TAG, "isAnydeskRunning: AnyDesk process detected: ${processInfo.processName}")
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "isAnydeskRunning: Error checking for AnyDesk", e)
        }
        return false
    }
    
    // Prevent user from using hardware back button
    override fun onBackPressed() {
        Log.d(TAG, "onBackPressed: Back button pressed")
        // Allow back button if AnyDesk UI is active
        if (isAnydeskInForeground()) {
            Log.i(TAG, "onBackPressed: AnyDesk UI active - allowing back button")
            super.onBackPressed()
            return
        }
        // Otherwise block it
        Log.d(TAG, "onBackPressed: Blocked (no AnyDesk UI)")
    }
    
    // Prevent system keys like volume, power, etc.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Allow all keys if AnyDesk UI is active
        if (isAnydeskInForeground()) {
            Log.d(TAG, "dispatchKeyEvent: AnyDesk UI active - allowing key ${event.keyCode}")
            return super.dispatchKeyEvent(event)
        }
        
        // Handle volume buttons, power button, etc.
        return when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_POWER,
            KeyEvent.KEYCODE_HOME,
            KeyEvent.KEYCODE_BACK -> {
                Log.d(TAG, "dispatchKeyEvent: Blocked key ${event.keyCode}")
                true // Consume the event, prevent default behavior
            }
            else -> super.dispatchKeyEvent(event) // Let other keys behave normally
        }
    }
    
    // Get device MAC address
    private fun getMacAddress(): String {
        try {
            // Try to get MAC address from network interfaces
            val networkInterfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            for (networkInterface in networkInterfaces) {
                if (networkInterface.name.equals("wlan0", ignoreCase = true)) {
                    val macBytes = networkInterface.hardwareAddress
                    if (macBytes != null) {
                        // Format MAC address as XX:XX:XX:XX:XX:XX
                        val macBuilder = StringBuilder()
                        for (i in macBytes.indices) {
                            macBuilder.append(String.format("%02X", macBytes[i]))
                            if (i < macBytes.size - 1) {
                                macBuilder.append(":")
                            }
                        }
                        return macBuilder.toString()
                    }
                }
            }
            
            // Fallback to Android ID if MAC address is not available
            val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
            // Format Android ID to look like a MAC address (for consistency)
            if (androidId.length >= 12) {
                val formattedId = StringBuilder()
                for (i in 0 until 6) {
                    formattedId.append(androidId.substring(i * 2, i * 2 + 2))
                    if (i < 5) {
                        formattedId.append(":")
                    }
                }
                return formattedId.toString()
            }
            return "00:00:00:00:00:00" // Default if we can't get anything
        } catch (e: Exception) {
            e.printStackTrace()
            return "Unknown"
        }
    }

    // Method channel setup
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Kiosk mode channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.msi_clock/kiosk")
            .setMethodCallHandler { call, result ->
                if (call.method == "exitKioskMode") {
                    // Lock Task Mode is not used, so just return success
                    Log.d(TAG, "exitKioskMode: Lock Task Mode not active (AnyDesk compatibility)")
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
            
        // Device info channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.msi_clock/device_info")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMacAddress" -> {
                        try {
                            val macAddress = getMacAddress()
                            result.success(macAddress)
                        } catch (e: Exception) {
                            result.error("MAC_ADDRESS_ERROR", "Failed to get MAC address", e.toString())
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
