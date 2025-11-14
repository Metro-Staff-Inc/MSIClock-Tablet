package com.example.msi_clock

import android.app.ActivityManager
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
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
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Start lock task mode (kiosk mode)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            startLockTask()
        }
    }

    override fun onResume() {
        super.onResume()
        hideSystemUI()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
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
    
    // Prevent user from using hardware back button
    override fun onBackPressed() {
        // Do nothing - prevents back button from working
    }
    
    // Prevent system keys like volume, power, etc.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Handle volume buttons, power button, etc.
        return when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_POWER,
            KeyEvent.KEYCODE_HOME,
            KeyEvent.KEYCODE_BACK -> true // Consume the event, prevent default behavior
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
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        try {
                            stopLockTask()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("EXIT_KIOSK_ERROR", "Failed to exit kiosk mode", e.toString())
                        }
                    } else {
                        result.success(false)
                    }
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
