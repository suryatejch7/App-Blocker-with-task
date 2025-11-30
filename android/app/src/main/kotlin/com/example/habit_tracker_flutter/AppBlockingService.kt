package com.example.habit_tracker_flutter

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import android.content.Context
import android.content.SharedPreferences
import android.app.ActivityManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject

class AppBlockingService : AccessibilityService() {
    
    private lateinit var prefs: SharedPreferences
    private var restrictedApps = mutableSetOf<String>()
    private var restrictedWebsites = mutableSetOf<String>()
    private var restrictionsActive = false
    private var pendingTasks = mutableListOf<Map<String, Any>>()
    private var permanentlyBlockedApps = mutableSetOf<String>()
    private var permanentlyBlockedWebsites = mutableSetOf<String>()
    
    // Track recently blocked packages to avoid spam
    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0
    private val BLOCK_COOLDOWN = 1000L // 1 second cooldown
    
    // Handler for delayed actions
    private val handler = Handler(Looper.getMainLooper())
    
    companion object {
        const val PREFS_NAME = "restriction_prefs"
        const val KEY_RESTRICTED_APPS = "restricted_apps"
        const val KEY_RESTRICTED_WEBSITES = "restricted_websites"
        const val KEY_RESTRICTIONS_ACTIVE = "restrictions_active"
        const val KEY_PENDING_TASKS = "pending_tasks"
        const val KEY_PERMANENTLY_BLOCKED_APPS = "permanently_blocked_apps"
        const val KEY_PERMANENTLY_BLOCKED_WEBSITES = "permanently_blocked_websites"
        
        private var instance: AppBlockingService? = null
        
        fun updateRestrictions(
            apps: List<String>, 
            websites: List<String>, 
            active: Boolean,
            tasks: List<Map<String, Any>> = emptyList(),
            permanentApps: List<String> = emptyList(),
            permanentWebsites: List<String> = emptyList()
        ) {
            android.util.Log.d("AppBlockingService", "========== UPDATE RESTRICTIONS CALLED ==========")
            android.util.Log.d("AppBlockingService", "Apps to restrict (${apps.size}): $apps")
            android.util.Log.d("AppBlockingService", "Websites to restrict (${websites.size}): $websites")
            android.util.Log.d("AppBlockingService", "Active: $active")
            android.util.Log.d("AppBlockingService", "Pending tasks: ${tasks.size}")
            android.util.Log.d("AppBlockingService", "Permanently blocked apps: ${permanentApps.size}")
            android.util.Log.d("AppBlockingService", "Service instance exists: ${instance != null}")
            
            instance?.apply {
                restrictedApps = apps.toMutableSet()
                restrictedWebsites = websites.toMutableSet()
                restrictionsActive = active
                pendingTasks = tasks.toMutableList()
                permanentlyBlockedApps = permanentApps.toMutableSet()
                permanentlyBlockedWebsites = permanentWebsites.toMutableSet()
                
                android.util.Log.d("AppBlockingService", "Updated in-memory lists")
                
                // Save to preferences
                prefs.edit().apply {
                    putString(KEY_RESTRICTED_APPS, JSONArray(apps).toString())
                    putString(KEY_RESTRICTED_WEBSITES, JSONArray(websites).toString())
                    putBoolean(KEY_RESTRICTIONS_ACTIVE, active)
                    putString(KEY_PENDING_TASKS, JSONArray(tasks.map { JSONObject(it) }).toString())
                    putString(KEY_PERMANENTLY_BLOCKED_APPS, JSONArray(permanentApps).toString())
                    putString(KEY_PERMANENTLY_BLOCKED_WEBSITES, JSONArray(permanentWebsites).toString())
                    apply()
                }
                
                android.util.Log.d("AppBlockingService", "Saved to SharedPreferences")
                android.util.Log.d("AppBlockingService", "========== UPDATE COMPLETE ==========")
            } ?: android.util.Log.e("AppBlockingService", "❌ SERVICE INSTANCE IS NULL! Cannot update restrictions!")
        }
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        loadRestrictions()
    }
    
    private fun loadRestrictions() {
        android.util.Log.d("AppBlockingService", "========== LOADING RESTRICTIONS ==========")
        val appsJson = prefs.getString(KEY_RESTRICTED_APPS, "[]")
        val websitesJson = prefs.getString(KEY_RESTRICTED_WEBSITES, "[]")
        val tasksJson = prefs.getString(KEY_PENDING_TASKS, "[]")
        val permanentAppsJson = prefs.getString(KEY_PERMANENTLY_BLOCKED_APPS, "[]")
        val permanentWebsitesJson = prefs.getString(KEY_PERMANENTLY_BLOCKED_WEBSITES, "[]")
        restrictionsActive = prefs.getBoolean(KEY_RESTRICTIONS_ACTIVE, false)
        
        android.util.Log.d("AppBlockingService", "Apps JSON from prefs: $appsJson")
        android.util.Log.d("AppBlockingService", "Websites JSON from prefs: $websitesJson")
        android.util.Log.d("AppBlockingService", "Restrictions active from prefs: $restrictionsActive")
        
        val appsArray = JSONArray(appsJson)
        val websitesArray = JSONArray(websitesJson)
        val tasksArray = JSONArray(tasksJson)
        val permanentAppsArray = JSONArray(permanentAppsJson)
        val permanentWebsitesArray = JSONArray(permanentWebsitesJson)
        
        restrictedApps.clear()
        for (i in 0 until appsArray.length()) {
            restrictedApps.add(appsArray.getString(i))
        }
        
        restrictedWebsites.clear()
        for (i in 0 until websitesArray.length()) {
            restrictedWebsites.add(websitesArray.getString(i))
        }
        
        pendingTasks.clear()
        for (i in 0 until tasksArray.length()) {
            val taskObj = tasksArray.getJSONObject(i)
            val taskMap = mutableMapOf<String, Any>()
            taskObj.keys().forEach { key ->
                taskMap[key] = taskObj.get(key)
            }
            pendingTasks.add(taskMap)
        }
        
        permanentlyBlockedApps.clear()
        for (i in 0 until permanentAppsArray.length()) {
            permanentlyBlockedApps.add(permanentAppsArray.getString(i))
        }
        
        permanentlyBlockedWebsites.clear()
        for (i in 0 until permanentWebsitesArray.length()) {
            permanentlyBlockedWebsites.add(permanentWebsitesArray.getString(i))
        }
        
        android.util.Log.d("AppBlockingService", "Loaded ${restrictedApps.size} restricted apps: $restrictedApps")
        android.util.Log.d("AppBlockingService", "Loaded ${restrictedWebsites.size} restricted websites: $restrictedWebsites")
        android.util.Log.d("AppBlockingService", "Loaded ${pendingTasks.size} pending tasks")
        android.util.Log.d("AppBlockingService", "Loaded ${permanentlyBlockedApps.size} permanently blocked apps")
        android.util.Log.d("AppBlockingService", "========== LOAD COMPLETE ==========")
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) {
            android.util.Log.d("AppBlockingService", "Event is null")
            return
        }
        
        val packageName = event.packageName?.toString() ?: run {
            android.util.Log.d("AppBlockingService", "Package name is null")
            return
        }
        
        android.util.Log.d("AppBlockingService", "========== NEW EVENT ==========")
        android.util.Log.d("AppBlockingService", "Package: $packageName")
        android.util.Log.d("AppBlockingService", "Event type: ${event.eventType}")
        android.util.Log.d("AppBlockingService", "Restrictions active: $restrictionsActive")
        android.util.Log.d("AppBlockingService", "Restricted apps count: ${restrictedApps.size}")
        android.util.Log.d("AppBlockingService", "Restricted apps list: $restrictedApps")
        android.util.Log.d("AppBlockingService", "Restricted websites count: ${restrictedWebsites.size}")
        
        if (!restrictionsActive) {
            android.util.Log.d("AppBlockingService", "Restrictions NOT active, allowing all apps")
            return
        }
        
        // Handle multiple event types to catch floating windows and multi-window mode
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> {
                android.util.Log.d("AppBlockingService", "Window event detected (type: ${event.eventType})")
                handleWindowEvent(packageName)
            }
        }
    }
    
    private fun handleWindowEvent(packageName: String) {
        // Don't block the habit tracker app itself or the blocking activity
        if (packageName == application.packageName || packageName == "com.example.habit_tracker_flutter") {
            android.util.Log.d("AppBlockingService", "Skipping own app")
            return
        }
        
        // Also scan ALL visible windows to catch floating windows/split screen
        scanAndBlockRestrictedWindows()
        
        // Check if app is permanently blocked
        if (permanentlyBlockedApps.contains(packageName)) {
            android.util.Log.d("AppBlockingService", "🚫 PERMANENTLY BLOCKING APP: $packageName")
            blockApp(packageName, isPermanent = true)
            return
        }
        
        // Check if app is restricted by tasks
        if (restrictedApps.contains(packageName)) {
            android.util.Log.d("AppBlockingService", "🚫 BLOCKING APP (task-based): $packageName")
            blockApp(packageName, isPermanent = false)
            return
        } else {
            android.util.Log.d("AppBlockingService", "✅ App NOT in restricted list, allowing")
        }
        
        // Check if it's a browser with restricted website
        if (isBrowserApp(packageName)) {
            android.util.Log.d("AppBlockingService", "Browser detected: $packageName")
            // Check if browser is permanently blocked due to websites
            if (permanentlyBlockedWebsites.isNotEmpty()) {
                android.util.Log.d("AppBlockingService", "🚫 BLOCKING BROWSER (permanently blocked websites)")
                blockApp(packageName, isPermanent = true)
            } else if (restrictedWebsites.isNotEmpty()) {
                android.util.Log.d("AppBlockingService", "🚫 BLOCKING BROWSER (task-based websites)")
                blockApp(packageName, isPermanent = false)
            }
        }
    }
    
    /**
     * Scan all visible windows and block any that belong to restricted apps.
     * This catches floating windows, split screen, picture-in-picture, etc.
     */
    private fun scanAndBlockRestrictedWindows() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val windows = windows
                android.util.Log.d("AppBlockingService", "Scanning ${windows?.size ?: 0} windows")
                
                windows?.forEach { window ->
                    val windowPackage = window.root?.packageName?.toString()
                    val windowType = window.type
                    
                    android.util.Log.d("AppBlockingService", "Window: pkg=$windowPackage, type=$windowType, isActive=${window.isActive}, isFocused=${window.isFocused}")
                    
                    if (windowPackage != null && 
                        windowPackage != application.packageName &&
                        windowPackage != "com.example.habit_tracker_flutter") {
                        
                        // Check if this window's package is blocked
                        val isPermanentlyBlocked = permanentlyBlockedApps.contains(windowPackage)
                        val isTaskBlocked = restrictedApps.contains(windowPackage)
                        val isBrowserWithBlockedSites = isBrowserApp(windowPackage) && 
                            (permanentlyBlockedWebsites.isNotEmpty() || restrictedWebsites.isNotEmpty())
                        
                        if (isPermanentlyBlocked || isTaskBlocked || isBrowserWithBlockedSites) {
                            android.util.Log.d("AppBlockingService", "⚠️ Found blocked app in window: $windowPackage (type=$windowType)")
                            blockApp(windowPackage, isPermanentlyBlocked || (isBrowserWithBlockedSites && permanentlyBlockedWebsites.isNotEmpty()))
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("AppBlockingService", "Error scanning windows: $e")
        }
    }
    
    private fun isBrowserApp(packageName: String): Boolean {
        val browsers = setOf(
            "com.android.chrome",
            "org.mozilla.firefox",
            "com.microsoft.emmx",
            "com.opera.browser",
            "com.brave.browser",
            "com.vivaldi.browser",
            "com.kiwibrowser.browser",
            "com.duckduckgo.mobile.android"
        )
        return browsers.contains(packageName)
    }
    
    private fun blockApp(blockedPackage: String, isPermanent: Boolean) {
        val currentTime = System.currentTimeMillis()
        
        // Avoid blocking the same app multiple times in quick succession
        if (blockedPackage == lastBlockedPackage && currentTime - lastBlockTime < BLOCK_COOLDOWN) {
            android.util.Log.d("AppBlockingService", "Skipping duplicate block for $blockedPackage (cooldown)")
            return
        }
        
        lastBlockedPackage = blockedPackage
        lastBlockTime = currentTime
        
        android.util.Log.d("AppBlockingService", "🔥 AGGRESSIVE BLOCK STARTING for $blockedPackage")
        
        // Step 1: Perform multiple back actions to close floating windows/popups
        performGlobalAction(GLOBAL_ACTION_BACK)
        
        // Step 2: Close all windows of the blocked app
        closeAppWindows(blockedPackage)
        
        // Step 3: Go to home screen
        performGlobalAction(GLOBAL_ACTION_HOME)
        
        // Step 4: Kill the app's background processes
        forceStopApp(blockedPackage)
        
        // Step 5: Show blocking screen after a small delay to ensure home is shown
        handler.postDelayed({
            showBlockingScreen(blockedPackage, isPermanent)
        }, 100)
        
        // Step 6: Schedule additional checks to make sure app is really closed
        handler.postDelayed({
            // Check if the blocked app is still visible and close it again
            checkAndCloseBlockedApp(blockedPackage, isPermanent)
        }, 500)
    }
    
    private fun closeAppWindows(packageName: String) {
        try {
            // Get all windows and close any belonging to the blocked app
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val windows = windows
                windows?.forEach { window ->
                    val windowPackage = window.root?.packageName?.toString()
                    if (windowPackage == packageName) {
                        android.util.Log.d("AppBlockingService", "Found window for $packageName, type: ${window.type}")
                        // For floating windows (TYPE_ACCESSIBILITY_OVERLAY, TYPE_SPLIT_SCREEN_DIVIDER, etc.)
                        if (window.type == AccessibilityWindowInfo.TYPE_APPLICATION ||
                            window.type == AccessibilityWindowInfo.TYPE_SPLIT_SCREEN_DIVIDER) {
                            // Perform back action to try to dismiss
                            performGlobalAction(GLOBAL_ACTION_BACK)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("AppBlockingService", "Error closing app windows: $e")
        }
    }
    
    private fun checkAndCloseBlockedApp(blockedPackage: String, isPermanent: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val windows = windows
                var blockedAppStillVisible = false
                
                windows?.forEach { window ->
                    val windowPackage = window.root?.packageName?.toString()
                    if (windowPackage == blockedPackage) {
                        blockedAppStillVisible = true
                        android.util.Log.d("AppBlockingService", "⚠️ Blocked app $blockedPackage still visible!")
                    }
                }
                
                if (blockedAppStillVisible) {
                    // App is still showing, take more aggressive action
                    android.util.Log.d("AppBlockingService", "🔄 Performing additional close actions")
                    performGlobalAction(GLOBAL_ACTION_BACK)
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    forceStopApp(blockedPackage)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("AppBlockingService", "Error checking blocked app: $e")
        }
    }
    
    private fun showBlockingScreen(blockedPackage: String, isPermanent: Boolean) {
        // Prepare tasks JSON for the blocking screen
        val tasksJson = JSONArray(pendingTasks.map { JSONObject(it) }).toString()
        
        android.util.Log.d("AppBlockingService", "📱 showBlockingScreen called for $blockedPackage")
        
        // First, show the overlay which appears above ALL windows including floating windows
        try {
            android.util.Log.d("AppBlockingService", "Checking overlay permission...")
            val canDrawOverlays = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.provider.Settings.canDrawOverlays(this)
            } else {
                true
            }
            android.util.Log.d("AppBlockingService", "canDrawOverlays = $canDrawOverlays")
            
            if (canDrawOverlays) {
                android.util.Log.d("AppBlockingService", "🔲 Showing blocking overlay for $blockedPackage")
                BlockingOverlayService.showOverlay(this, blockedPackage, isPermanent, tasksJson)
            } else {
                android.util.Log.d("AppBlockingService", "⚠️ No overlay permission, using activity only")
            }
        } catch (e: Exception) {
            android.util.Log.e("AppBlockingService", "Error showing overlay: $e")
            e.printStackTrace()
        }
        
        // Also show blocking activity as fallback
        val blockIntent = Intent(this, BlockingActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_NO_HISTORY or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            putExtra("blockedPackage", blockedPackage)
            putExtra("isPermanent", isPermanent)
            putExtra("pendingTasks", tasksJson)
        }
        startActivity(blockIntent)
    }
    
    private fun forceStopApp(packageName: String) {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            
            // Kill the app using ActivityManager
            activityManager.killBackgroundProcesses(packageName)
            
            // Also try to remove all tasks for this app from recent apps
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val tasks = activityManager.appTasks
                tasks?.forEach { task ->
                    val taskInfo = task.taskInfo
                    if (taskInfo?.baseActivity?.packageName == packageName ||
                        taskInfo?.topActivity?.packageName == packageName) {
                        android.util.Log.d("AppBlockingService", "Finishing task for $packageName")
                        task.finishAndRemoveTask()
                    }
                }
            }
            
            android.util.Log.d("AppBlockingService", "Force stopped app: $packageName")
        } catch (e: Exception) {
            android.util.Log.e("AppBlockingService", "Error force stopping app: $e")
        }
    }
    
    override fun onInterrupt() {
        // Required override
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }
}
