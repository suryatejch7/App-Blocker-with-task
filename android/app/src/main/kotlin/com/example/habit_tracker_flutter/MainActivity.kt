package com.example.habit_tracker_flutter

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.habittracker/restrictions"
    private val ACCESSIBILITY_REQUEST_CODE = 1001
    private val OVERLAY_REQUEST_CODE = 1002
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> {
                    requestPermissions()
                    result.success(true)
                }
                "checkPermissions" -> {
                    val hasPermissions = checkAccessibilityPermission()
                    result.success(hasPermissions)
                }
                "checkOverlayPermission" -> {
                    result.success(checkOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "updateRestrictions" -> {
                    val apps = call.argument<List<String>>("apps") ?: emptyList()
                    val websites = call.argument<List<String>>("websites") ?: emptyList()
                    val active = call.argument<Boolean>("active") ?: false
                    val pendingTasks = call.argument<List<Map<String, Any>>>("pendingTasks") ?: emptyList()
                    val permanentlyBlockedApps = call.argument<List<String>>("permanentlyBlockedApps") ?: emptyList()
                    val permanentlyBlockedWebsites = call.argument<List<String>>("permanentlyBlockedWebsites") ?: emptyList()
                    
                    AppBlockingService.updateRestrictions(
                        apps, 
                        websites, 
                        active,
                        pendingTasks,
                        permanentlyBlockedApps,
                        permanentlyBlockedWebsites
                    )
                    result.success(null)
                }
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                "startMonitoring" -> {
                    // Start foreground service if needed
                    result.success(null)
                }
                "stopMonitoring" -> {
                    // Stop foreground service if needed
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun requestPermissions() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivityForResult(intent, ACCESSIBILITY_REQUEST_CODE)
    }
    
    private fun checkOverlayPermission(): Boolean {
        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
        android.util.Log.d("MainActivity", "checkOverlayPermission: $hasPermission")
        return hasPermission
    }
    
    private fun requestOverlayPermission() {
        android.util.Log.d("MainActivity", "requestOverlayPermission called")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                android.util.Log.d("MainActivity", "Opening overlay settings for package: $packageName")
                startActivityForResult(intent, OVERLAY_REQUEST_CODE)
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error opening overlay settings: $e")
                // Fallback to general overlay settings if app-specific doesn't work
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                startActivityForResult(intent, OVERLAY_REQUEST_CODE)
            }
        } else {
            android.util.Log.d("MainActivity", "Android version < M, overlay permission not needed")
        }
    }
    
    private fun checkAccessibilityPermission(): Boolean {
        var accessibilityEnabled = 0
        val service = packageName + "/" + AppBlockingService::class.java.canonicalName
        try {
            accessibilityEnabled = Settings.Secure.getInt(
                applicationContext.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED
            )
        } catch (e: Settings.SettingNotFoundException) {
            e.printStackTrace()
        }
        
        if (accessibilityEnabled == 1) {
            val settingValue = Settings.Secure.getString(
                applicationContext.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            if (settingValue != null) {
                return settingValue.contains(service)
            }
        }
        return false
    }
    
    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val apps = mutableListOf<Map<String, String>>()
        
        val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        for (app in installedApps) {
            // Skip system apps and our own app
            if (app.packageName == packageName) continue
            if ((app.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0) continue
            
            val appMap = mapOf(
                "name" to (app.loadLabel(pm).toString()),
                "packageName" to app.packageName
            )
            apps.add(appMap)
        }
        
        return apps.sortedBy { it["name"] }
    }
}
