package com.example.habit_tracker_flutter

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.content.Context
import android.content.SharedPreferences
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
        android.util.Log.d("AppBlockingService", "Restrictions active: $restrictionsActive")
        android.util.Log.d("AppBlockingService", "Restricted apps count: ${restrictedApps.size}")
        android.util.Log.d("AppBlockingService", "Restricted apps list: $restrictedApps")
        android.util.Log.d("AppBlockingService", "Restricted websites count: ${restrictedWebsites.size}")
        
        if (!restrictionsActive) {
            android.util.Log.d("AppBlockingService", "Restrictions NOT active, allowing all apps")
            return
        }
        
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                android.util.Log.d("AppBlockingService", "Window state changed event detected")
                
                // Don't block the habit tracker app itself or the blocking activity
                if (packageName == application.packageName || packageName == "com.example.habit_tracker_flutter") {
                    android.util.Log.d("AppBlockingService", "Skipping own app")
                    return
                }
                
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
        // Go back to home screen
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        
        // Prepare tasks JSON for the blocking screen
        val tasksJson = JSONArray(pendingTasks.map { JSONObject(it) }).toString()
        
        // Show blocking screen with info about why it's blocked
        val blockIntent = Intent(this, BlockingActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_NO_HISTORY
            putExtra("blockedPackage", blockedPackage)
            putExtra("isPermanent", isPermanent)
            putExtra("pendingTasks", tasksJson)
        }
        startActivity(blockIntent)
    }
    
    override fun onInterrupt() {
        // Required override
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }
}
