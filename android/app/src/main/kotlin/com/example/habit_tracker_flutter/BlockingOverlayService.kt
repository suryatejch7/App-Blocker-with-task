package com.example.habit_tracker_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.ScrollView
import org.json.JSONArray

/**
 * A floating overlay service that creates a system-level overlay window.
 * This overlay appears above ALL other windows including floating windows,
 * split screen dividers, and other overlays.
 */
class BlockingOverlayService : Service() {
    
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    
    companion object {
        private const val CHANNEL_ID = "blocking_overlay_channel"
        private const val NOTIFICATION_ID = 1001
        private var instance: BlockingOverlayService? = null
        private var isOverlayShowing = false
        
        fun showOverlay(context: Context, blockedPackage: String, isPermanent: Boolean, tasksJson: String) {
            android.util.Log.d("BlockingOverlayService", "showOverlay called for $blockedPackage")
            
            val intent = Intent(context, BlockingOverlayService::class.java).apply {
                putExtra("blockedPackage", blockedPackage)
                putExtra("isPermanent", isPermanent)
                putExtra("pendingTasks", tasksJson)
                putExtra("action", "show")
            }
            
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                android.util.Log.e("BlockingOverlayService", "Error starting service: $e")
            }
        }
        
        fun hideOverlay(context: Context) {
            try {
                val intent = Intent(context, BlockingOverlayService::class.java).apply {
                    putExtra("action", "hide")
                }
                context.startService(intent)
            } catch (e: Exception) {
                android.util.Log.e("BlockingOverlayService", "Error hiding overlay: $e")
            }
        }
        
        fun isShowing(): Boolean = isOverlayShowing
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        android.util.Log.d("BlockingOverlayService", "Service onCreate")
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when an app is being blocked"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("App Blocked")
                .setContentText("A restricted app is being blocked")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("App Blocked")
                .setContentText("A restricted app is being blocked")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("BlockingOverlayService", "onStartCommand called")
        
        // Start as foreground service immediately
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForeground(NOTIFICATION_ID, createNotification())
        }
        
        val action = intent?.getStringExtra("action") ?: "show"
        android.util.Log.d("BlockingOverlayService", "Action: $action")
        
        when (action) {
            "show" -> {
                val blockedPackage = intent?.getStringExtra("blockedPackage") ?: ""
                val isPermanent = intent?.getBooleanExtra("isPermanent", false) ?: false
                val tasksJson = intent?.getStringExtra("pendingTasks") ?: "[]"
                android.util.Log.d("BlockingOverlayService", "Creating overlay for $blockedPackage")
                createOverlay(blockedPackage, isPermanent, tasksJson)
            }
            "hide" -> {
                removeOverlay()
                stopForeground(true)
                stopSelf()
            }
        }
        
        return START_NOT_STICKY
    }
    
    private fun createOverlay(blockedPackage: String, isPermanent: Boolean, tasksJson: String) {
        // If overlay already showing, don't recreate
        if (isOverlayShowing && overlayView != null) {
            android.util.Log.d("BlockingOverlayService", "Overlay already showing, skipping")
            return
        }
        
        // Remove existing overlay first
        removeOverlay()
        
        // Check if we can draw overlays
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!android.provider.Settings.canDrawOverlays(this)) {
                android.util.Log.e("BlockingOverlayService", "Cannot draw overlays - permission not granted")
                stopSelf()
                return
            }
        }
        
        android.util.Log.d("BlockingOverlayService", "Permission OK, creating overlay view")
        
        // Parse tasks
        val tasks = mutableListOf<Map<String, Any>>()
        try {
            val tasksArray = JSONArray(tasksJson)
            for (i in 0 until tasksArray.length()) {
                val taskObj = tasksArray.getJSONObject(i)
                val taskMap = mutableMapOf<String, Any>()
                taskMap["id"] = taskObj.optString("id", "")
                taskMap["title"] = taskObj.optString("title", "")
                taskMap["description"] = taskObj.optString("description", "")
                taskMap["isOverdue"] = taskObj.optBoolean("isOverdue", false)
                tasks.add(taskMap)
            }
        } catch (e: Exception) {
            android.util.Log.e("BlockingOverlayService", "Error parsing tasks: $e")
        }
        
        // Create overlay layout
        overlayView = createOverlayLayout(isPermanent, tasks)
        
        // Create layout params for the overlay - FULL SCREEN BLOCKING
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }
        
        // Key flags: Remove FLAG_NOT_FOCUSABLE to capture all touches
        // FLAG_LAYOUT_IN_SCREEN ensures it covers the entire screen including status bar
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }
        
        try {
            windowManager?.addView(overlayView, params)
            isOverlayShowing = true
            android.util.Log.d("BlockingOverlayService", "✅ Overlay added successfully")
        } catch (e: Exception) {
            android.util.Log.e("BlockingOverlayService", "❌ Error adding overlay: $e")
            e.printStackTrace()
        }
    }
    
    private fun createOverlayLayout(isPermanent: Boolean, tasks: List<Map<String, Any>>): View {
        // Root layout - FULLY OPAQUE to block everything behind it
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#FF121212")) // Fully opaque dark background
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
            // Make clickable to intercept all touches
            isClickable = true
            isFocusable = true
        }
        
        // Scrollable content
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }
        
        val contentLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 100, 48, 48)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            gravity = Gravity.CENTER_HORIZONTAL
        }
        
        // Icon
        val iconText = TextView(this).apply {
            text = if (isPermanent) "🚫" else "🔒"
            textSize = 64f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }
        contentLayout.addView(iconText)
        
        // Title
        val titleText = TextView(this).apply {
            text = if (isPermanent) "App Permanently Blocked" else "App Blocked"
            textSize = 28f
            setTextColor(if (isPermanent) Color.parseColor("#FF5252") else Color.parseColor("#FFD700"))
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }
        contentLayout.addView(titleText)
        
        if (isPermanent) {
            val messageText = TextView(this).apply {
                text = "This app has been permanently blocked.\nYou chose to block this app 24/7."
                textSize = 16f
                setTextColor(Color.parseColor("#BBBBBB"))
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 40)
            }
            contentLayout.addView(messageText)
            
            val infoCard = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.parseColor("#1E1E1E"))
                setPadding(32, 24, 32, 24)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(0, 0, 0, 32)
                }
            }
            
            val infoText = TextView(this).apply {
                text = "To unblock this app, go to Settings > Restrictions in the Habit Tracker app."
                textSize = 14f
                setTextColor(Color.parseColor("#888888"))
            }
            infoCard.addView(infoText)
            contentLayout.addView(infoCard)
        } else {
            val messageText = TextView(this).apply {
                text = "Complete your pending tasks to unlock access"
                textSize = 16f
                setTextColor(Color.parseColor("#4A90E2"))
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 32)
            }
            contentLayout.addView(messageText)
            
            if (tasks.isNotEmpty()) {
                val tasksHeader = TextView(this).apply {
                    text = "PENDING TASKS (${tasks.size})"
                    textSize = 12f
                    setTextColor(Color.parseColor("#888888"))
                    setTypeface(null, Typeface.BOLD)
                    setPadding(0, 0, 0, 16)
                }
                contentLayout.addView(tasksHeader)
                
                for (task in tasks.take(5)) { // Limit to 5 tasks for overlay
                    val taskCard = createTaskCard(task)
                    contentLayout.addView(taskCard)
                }
            }
        }
        
        scrollView.addView(contentLayout)
        rootLayout.addView(scrollView)
        
        // Bottom button
        val buttonLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 24, 48, 48)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        
        val openAppButton = TextView(this).apply {
            text = if (isPermanent) "Open Habit Tracker" else "Open App to Complete Tasks"
            textSize = 16f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#4A90E2"))
            gravity = Gravity.CENTER
            setPadding(32, 20, 32, 20)
            setTypeface(null, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener {
                openHabitTracker()
            }
        }
        buttonLayout.addView(openAppButton)
        
        rootLayout.addView(buttonLayout)
        
        return rootLayout
    }
    
    private fun createTaskCard(task: Map<String, Any>): LinearLayout {
        val isOverdue = task["isOverdue"] as? Boolean ?: false
        val title = task["title"] as? String ?: "Untitled Task"
        
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#1E1E1E"))
            setPadding(24, 16, 24, 16)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 8)
            }
            
            setOnClickListener {
                openHabitTracker()
            }
            
            // Status dot
            val statusDot = View(this@BlockingOverlayService).apply {
                setBackgroundColor(if (isOverdue) Color.parseColor("#FF5252") else Color.parseColor("#4A90E2"))
                layoutParams = LinearLayout.LayoutParams(10, 10).apply {
                    setMargins(0, 8, 12, 0)
                }
            }
            addView(statusDot)
            
            // Task title
            val titleText = TextView(this@BlockingOverlayService).apply {
                text = title
                textSize = 14f
                setTextColor(Color.WHITE)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            addView(titleText)
            
            // Overdue indicator
            if (isOverdue) {
                val overdueText = TextView(this@BlockingOverlayService).apply {
                    text = "OVERDUE"
                    textSize = 10f
                    setTextColor(Color.parseColor("#FF5252"))
                    setTypeface(null, Typeface.BOLD)
                }
                addView(overdueText)
            }
        }
    }
    
    private fun openHabitTracker() {
        val intent = packageManager.getLaunchIntentForPackage("com.example.habit_tracker_flutter")
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(intent)
        }
        removeOverlay()
        stopSelf()
    }
    
    private fun removeOverlay() {
        try {
            overlayView?.let {
                windowManager?.removeView(it)
                overlayView = null
            }
            isOverlayShowing = false
        } catch (e: Exception) {
            android.util.Log.e("BlockingOverlayService", "Error removing overlay: $e")
        }
    }
    
    override fun onDestroy() {
        removeOverlay()
        instance = null
        super.onDestroy()
    }
}
