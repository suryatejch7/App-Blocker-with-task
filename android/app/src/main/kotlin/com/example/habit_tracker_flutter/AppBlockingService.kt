package com.android.krama

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
import android.provider.Settings
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

    // Emergency release (one-shot per package while restrictions stay active)
    private var emergencyReleasePackage: String? = null
    private var emergencyReleaseUntilMs: Long = 0L
    private var emergencyReblockRunnable: Runnable? = null
    private var emergencyLockoutPackages = mutableSetOf<String>()
    
    // Track recently blocked packages to avoid spam
    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0
    private val BLOCK_COOLDOWN = 1000L // 1 second cooldown
    private var lastWindowScanTime: Long = 0
    private val WINDOW_SCAN_COOLDOWN = 300L // reduce heavy scan frequency
    private var lastImePackageReadTime: Long = 0
    private var cachedImePackage: String? = null
    
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
        const val KEY_EMERGENCY_LOCKOUT_PACKAGES = "emergency_lockout_packages"

        const val ACTION_DISMISS_BLOCKING_UI = "com.android.krama.DISMISS_BLOCKING_UI"
        
        private var instance: AppBlockingService? = null
        
        fun updateRestrictions(
            context: Context,
            apps: List<String>, 
            websites: List<String>, 
            active: Boolean,
            tasks: List<Map<String, Any>> = emptyList(),
            permanentApps: List<String> = emptyList(),
            permanentWebsites: List<String> = emptyList()
        ): Boolean {
            android.util.Log.d("AppBlockingService", "========== UPDATE RESTRICTIONS CALLED ==========")
            android.util.Log.d("AppBlockingService", "Apps to restrict (${apps.size}): $apps")
            android.util.Log.d("AppBlockingService", "Websites to restrict (${websites.size}): $websites")
            android.util.Log.d("AppBlockingService", "Active: $active")
            android.util.Log.d("AppBlockingService", "Active/overdue task payload entries: ${tasks.size}")
            android.util.Log.d("AppBlockingService", "Permanently blocked apps: ${permanentApps.size}")
            android.util.Log.d("AppBlockingService", "Service instance exists: ${instance != null}")

            // Always persist latest restrictions so they can be loaded whenever
            // the accessibility service connects/reconnects.
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .apply {
                    putString(KEY_RESTRICTED_APPS, JSONArray(apps).toString())
                    putString(KEY_RESTRICTED_WEBSITES, JSONArray(websites).toString())
                    putBoolean(KEY_RESTRICTIONS_ACTIVE, active)
                    putString(KEY_PENDING_TASKS, JSONArray(tasks.map { JSONObject(it) }).toString())
                    putString(KEY_PERMANENTLY_BLOCKED_APPS, JSONArray(permanentApps).toString())
                    putString(KEY_PERMANENTLY_BLOCKED_WEBSITES, JSONArray(permanentWebsites).toString())

                    // If restrictions are turned off, clear emergency lockouts.
                    if (!active) {
                        putString(KEY_EMERGENCY_LOCKOUT_PACKAGES, JSONArray(emptyList<String>()).toString())
                    }
                    apply()
                }
            
            instance?.apply {
                restrictedApps = apps.toMutableSet()
                restrictedWebsites = websites.toMutableSet()
                restrictionsActive = active
                pendingTasks = tasks.toMutableList()
                permanentlyBlockedApps = permanentApps.toMutableSet()
                permanentlyBlockedWebsites = permanentWebsites.toMutableSet()

                if (!active) {
                    emergencyLockoutPackages.clear()
                    emergencyReleasePackage = null
                    emergencyReleaseUntilMs = 0L
                    emergencyReblockRunnable?.let { handler.removeCallbacks(it) }
                    emergencyReblockRunnable = null
                }
                
                android.util.Log.d("AppBlockingService", "Updated in-memory lists")
                android.util.Log.d("AppBlockingService", "Applied to live service instance")
                android.util.Log.d("AppBlockingService", "========== UPDATE COMPLETE ==========")
                return true
            }

            android.util.Log.w(
                "AppBlockingService",
                "⚠️ SERVICE INSTANCE IS NULL. Restrictions saved and will apply when service connects."
            )
            return false
        }

        /**
         * Request a one-time emergency release for a blocked package.
         * This temporarily suspends blocking for [durationSeconds] and then re-checks.
         */
        fun requestEmergencyRelease(
            context: Context,
            blockedPackage: String,
            durationSeconds: Int
        ): Boolean {
            val clampedSeconds = durationSeconds.coerceIn(10, 60)

            instance?.apply {
                startEmergencyRelease(blockedPackage, clampedSeconds)
                return true
            }

            android.util.Log.w("AppBlockingService", "Emergency release requested but service instance is null")
            return false
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
        val emergencyLockoutJson = prefs.getString(KEY_EMERGENCY_LOCKOUT_PACKAGES, "[]")
        restrictionsActive = prefs.getBoolean(KEY_RESTRICTIONS_ACTIVE, false)
        
        android.util.Log.d("AppBlockingService", "Apps JSON from prefs: $appsJson")
        android.util.Log.d("AppBlockingService", "Websites JSON from prefs: $websitesJson")
        android.util.Log.d("AppBlockingService", "Restrictions active from prefs: $restrictionsActive")
        
        val appsArray = JSONArray(appsJson)
        val websitesArray = JSONArray(websitesJson)
        val tasksArray = JSONArray(tasksJson)
        val permanentAppsArray = JSONArray(permanentAppsJson)
        val permanentWebsitesArray = JSONArray(permanentWebsitesJson)
        val emergencyLockoutArray = JSONArray(emergencyLockoutJson)
        
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

        emergencyLockoutPackages.clear()
        for (i in 0 until emergencyLockoutArray.length()) {
            emergencyLockoutPackages.add(emergencyLockoutArray.getString(i))
        }
        
        android.util.Log.d("AppBlockingService", "Loaded ${restrictedApps.size} restricted apps: $restrictedApps")
        android.util.Log.d("AppBlockingService", "Loaded ${restrictedWebsites.size} restricted websites: $restrictedWebsites")
        android.util.Log.d("AppBlockingService", "Loaded ${pendingTasks.size} active/overdue task payload entries")
        android.util.Log.d("AppBlockingService", "Loaded ${permanentlyBlockedApps.size} permanently blocked apps")
        android.util.Log.d("AppBlockingService", "Loaded ${emergencyLockoutPackages.size} emergency lockout packages")
        android.util.Log.d("AppBlockingService", "========== LOAD COMPLETE ==========")
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        val packageName = event.packageName?.toString() ?: return

        // Ignore noisy/system packages that generate many events but should never be blocked.
        if (shouldIgnorePackage(packageName)) return
        
        if (!restrictionsActive) {
            return
        }

        // Nothing to enforce: avoid expensive scanning on every accessibility event.
        if (restrictedApps.isEmpty() && restrictedWebsites.isEmpty() &&
            permanentlyBlockedApps.isEmpty() && permanentlyBlockedWebsites.isEmpty()) {
            return
        }
        
        // Handle multiple event types to catch floating windows and multi-window mode
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> {
                val shouldScanAllWindows = event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
                handleWindowEvent(packageName, shouldScanAllWindows)
            }
        }
    }

    private fun shouldIgnorePackage(packageName: String): Boolean {
        if (packageName == application.packageName ||
            packageName == "com.android.krama" ||
            packageName == "com.android.systemui") {
            return true
        }

        // Ignore current keyboard package (IME) events - they are very frequent and unrelated.
        val imePackage = getCurrentImePackageName()
        if (imePackage != null && imePackage == packageName) {
            return true
        }

        return false
    }

    private fun getCurrentImePackageName(): String? {
        val now = System.currentTimeMillis()
        if (now - lastImePackageReadTime < 5_000L) {
            return cachedImePackage
        }

        return try {
            val ime = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.DEFAULT_INPUT_METHOD
            )
            // Format is usually: com.package/.ImeService
            val packageName = ime?.substringBefore('/')
            cachedImePackage = packageName
            lastImePackageReadTime = now
            packageName
        } catch (e: Exception) {
            cachedImePackage
        }
    }
    
    private fun handleWindowEvent(packageName: String, shouldScanAllWindows: Boolean) {
        // Don't block the Krama app itself or the blocking activity
        if (packageName == application.packageName || packageName == "com.android.krama") {
            return
        }

        val emergencyActiveForThisPackage = isEmergencyReleaseActiveFor(packageName)
        
        // Also scan ALL visible windows to catch floating windows/split screen
        if (shouldScanAllWindows) {
            scanAndBlockRestrictedWindows()
        }
        
        // Check if app is permanently blocked
        if (!emergencyActiveForThisPackage && permanentlyBlockedApps.contains(packageName)) {
            android.util.Log.d("AppBlockingService", "🚫 PERMANENTLY BLOCKING APP: $packageName")
            blockApp(packageName, isPermanent = true)
            return
        }
        
        // Check if app is restricted by tasks
        if (!emergencyActiveForThisPackage && restrictedApps.contains(packageName)) {
            android.util.Log.d("AppBlockingService", "🚫 BLOCKING APP (task-based): $packageName")
            blockApp(packageName, isPermanent = false)
            return
        }
        
        // Check if it's a browser with restricted website
        if (!emergencyActiveForThisPackage && isBrowserApp(packageName)) {
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
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastWindowScanTime < WINDOW_SCAN_COOLDOWN) return
            lastWindowScanTime = currentTime

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val windows = windows
                
                windows?.forEach { window ->
                    val windowPackage = window.root?.packageName?.toString()
                    
                    if (windowPackage != null && 
                        windowPackage != application.packageName &&
                        windowPackage != "com.android.krama") {
                        
                        // Check if this window's package is blocked
                        val isPermanentlyBlocked = permanentlyBlockedApps.contains(windowPackage)
                        val isTaskBlocked = restrictedApps.contains(windowPackage)
                        val isBrowserWithBlockedSites = isBrowserApp(windowPackage) && 
                            (permanentlyBlockedWebsites.isNotEmpty() || restrictedWebsites.isNotEmpty())
                        
                        if (isPermanentlyBlocked || isTaskBlocked || isBrowserWithBlockedSites) {
                            if (isEmergencyReleaseActiveFor(windowPackage)) {
                                return@forEach
                            }
                            android.util.Log.d("AppBlockingService", "⚠️ Found blocked app in visible window: $windowPackage")
                            blockApp(windowPackage, isPermanentlyBlocked || (isBrowserWithBlockedSites && permanentlyBlockedWebsites.isNotEmpty()))
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("AppBlockingService", "Error scanning windows: $e")
        }
    }

    private fun isEmergencyReleaseActiveFor(packageName: String): Boolean {
        val until = emergencyReleaseUntilMs
        val allowedPackage = emergencyReleasePackage
        if (allowedPackage == null || until <= 0L) return false
        return allowedPackage == packageName && System.currentTimeMillis() < until
    }

    private fun startEmergencyRelease(blockedPackage: String, durationSeconds: Int) {
        val now = System.currentTimeMillis()
        emergencyReleasePackage = blockedPackage
        emergencyReleaseUntilMs = now + (durationSeconds * 1000L)

        // Cancel any previous expiry callback.
        emergencyReblockRunnable?.let { handler.removeCallbacks(it) }

        emergencyReblockRunnable = Runnable {
            onEmergencyReleaseExpired(blockedPackage)
        }.also { runnable ->
            handler.postDelayed(runnable, durationSeconds * 1000L)
        }

        // Dismiss any currently showing blocking UI so the user can proceed.
        try {
            sendBroadcast(Intent(ACTION_DISMISS_BLOCKING_UI))
            if (BlockingOverlayService.isShowing()) {
                BlockingOverlayService.hideOverlay(this)
            }
        } catch (_: Exception) {
            // ignore
        }

        android.util.Log.d("AppBlockingService", "🆘 Emergency release started for $blockedPackage: ${durationSeconds}s")
    }

    private fun onEmergencyReleaseExpired(blockedPackage: String) {
        emergencyReleasePackage = null
        emergencyReleaseUntilMs = 0L
        emergencyReblockRunnable = null

        if (!restrictionsActive) return

        val topPackage = getTopVisiblePackageName()
        if (topPackage != blockedPackage) {
            android.util.Log.d("AppBlockingService", "Emergency release expired; $blockedPackage not foreground (top=$topPackage)")
            return
        }

        val isPermanentlyBlocked = permanentlyBlockedApps.contains(blockedPackage) ||
            (isBrowserApp(blockedPackage) && permanentlyBlockedWebsites.isNotEmpty())
        val isTaskBlocked = restrictedApps.contains(blockedPackage) ||
            (isBrowserApp(blockedPackage) && restrictedWebsites.isNotEmpty())

        if (isPermanentlyBlocked || isTaskBlocked) {
            android.util.Log.d("AppBlockingService", "⏱️ Emergency release expired; re-blocking $blockedPackage")

            // Lock out emergency extend for this package since user stayed in the blocked app.
            emergencyLockoutPackages.add(blockedPackage)
            try {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString(KEY_EMERGENCY_LOCKOUT_PACKAGES, JSONArray(emergencyLockoutPackages.toList()).toString())
                    .apply()
            } catch (_: Exception) {
                // ignore
            }

            showBlockingScreen(blockedPackage, isPermanentlyBlocked)
        }
    }

    private fun getTopVisiblePackageName(): String? {
        // Best-effort: choose the topmost application window by layer.
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val candidates = windows
                    ?.filter { it.type == AccessibilityWindowInfo.TYPE_APPLICATION && it.root != null }
                    ?.sortedByDescending { it.layer }

                candidates?.firstOrNull()?.root?.packageName?.toString()
                    ?: rootInActiveWindow?.packageName?.toString()
            } else {
                rootInActiveWindow?.packageName?.toString()
            }
        } catch (_: Exception) {
            rootInActiveWindow?.packageName?.toString()
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
        if (isEmergencyReleaseActiveFor(blockedPackage)) {
            android.util.Log.d("AppBlockingService", "Emergency release active; skipping block for $blockedPackage")
            return
        }

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
                val emergencyLockedOut = emergencyLockoutPackages.contains(blockedPackage)
                BlockingOverlayService.showOverlay(this, blockedPackage, isPermanent, tasksJson, emergencyLockedOut)
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
            putExtra("emergencyLockedOut", emergencyLockoutPackages.contains(blockedPackage))
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
