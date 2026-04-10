package com.android.krama

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.app.PendingIntent
import android.net.Uri
import android.widget.RemoteViews
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home screen widget provider for displaying tasks.
 * Extends HomeWidgetProvider for easy access to Flutter-synced SharedPreferences.
 */
class TaskWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_INTERACTION = "com.android.krama.ACTION_WIDGET_INTERACTION"
        const val ACTION_TOGGLE_TASK = "com.android.krama.ACTION_TOGGLE_TASK"
        const val ACTION_OPEN_ADD_TASK = "com.android.krama.ACTION_OPEN_ADD_TASK"
        const val ACTION_REFRESH = "com.android.krama.ACTION_REFRESH"
        const val EXTRA_TASK_ID = "taskId"
        const val EXTRA_WIDGET_ACTION = "widgetAction"
        
        private const val KEY_TASKS = "tasks_data"
        private const val KEY_TASK_COUNT = "task_count"
        // Debounce tracking: in-memory state for duplicate prevention
        // Works across broadcasts because TaskWidgetProvider singleton persists in app memory
        private val lastToggleTimeMs = mutableMapOf<String, Long>()
        private const val DEBOUNCE_MS = 500L

        // Option-change storm guards (many launchers spam ACTION_APPWIDGET_OPTIONS_CHANGED)
        private val lastOptionsSignatureByWidgetId = mutableMapOf<Int, String>()
        private val lastOptionsUpdateAtMsByWidgetId = mutableMapOf<Int, Long>()
        private const val OPTIONS_CHANGE_MIN_INTERVAL_MS = 350L
        private const val OPTIONS_CHANGE_APPLY_DELAY_MS = 700L
        private val mainHandler = Handler(Looper.getMainLooper())
        private val pendingOptionsRunnablesByWidgetId = mutableMapOf<Int, Runnable>()
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_WIDGET_INTERACTION -> {
                val widgetAction = intent.getStringExtra(EXTRA_WIDGET_ACTION)
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)

                when (widgetAction) {
                    ACTION_TOGGLE_TASK -> {
                        if (!taskId.isNullOrEmpty()) {
                            // Debounce: drop duplicate toggles within 500ms
                            val now = System.currentTimeMillis()
                            val lastTime = lastToggleTimeMs[taskId] ?: 0L
                            if (now - lastTime < DEBOUNCE_MS) {
                                android.util.Log.d(
                                    "TaskWidgetProvider",
                                    "🚫 Debounced duplicate toggle for $taskId (${now - lastTime}ms since last)"
                                )
                                return
                            }
                            lastToggleTimeMs[taskId] = now
                        
                            android.util.Log.d(
                                "TaskWidgetProvider",
                                "✅ Processing toggle for $taskId at $now"
                            )
                            val backgroundUri = Uri.parse("krama://toggle-task?taskId=$taskId")
                            val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                backgroundUri
                            )
                            try {
                                backgroundIntent.send()
                            } catch (e: Exception) {
                                android.util.Log.e(
                                    "TaskWidgetProvider",
                                    "Failed to send background intent: ${e.message}",
                                    e
                                )
                            }
                        }
                    }

                    ACTION_OPEN_ADD_TASK -> {
                        launchApp(context, Uri.parse("krama://add-task"))
                    }
                }
            }
            ACTION_REFRESH -> {
                // Trigger widget update
                val widgetManager = AppWidgetManager.getInstance(context)
                val widgetIds = widgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, TaskWidgetProvider::class.java)
                )
                widgetIds.forEach { appWidgetId ->
                    widgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_task_list)
                }
            }
        }
    }

    override fun onEnabled(context: Context) {
        // Called when first widget is created
    }

    override fun onDisabled(context: Context) {
        // Called when last widget is removed
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        appWidgetIds.forEach { id ->
            lastOptionsSignatureByWidgetId.remove(id)
            lastOptionsUpdateAtMsByWidgetId.remove(id)
            pendingOptionsRunnablesByWidgetId.remove(id)?.let { mainHandler.removeCallbacks(it) }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val minW = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val minH = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        val maxW = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
        val maxH = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        val signature = "$minW:$minH:$maxW:$maxH"
        val now = System.currentTimeMillis()

        val lastSignature = lastOptionsSignatureByWidgetId[appWidgetId]
        val lastUpdateAt = lastOptionsUpdateAtMsByWidgetId[appWidgetId] ?: 0L

        // Drop exact duplicates and very high-frequency resize spam.
        if (signature == lastSignature) {
            return
        }
        if (now - lastUpdateAt < OPTIONS_CHANGE_MIN_INTERVAL_MS) {
            return
        }

        lastOptionsSignatureByWidgetId[appWidgetId] = signature
        lastOptionsUpdateAtMsByWidgetId[appWidgetId] = now

        // Coalesce resize storms: schedule one trailing update per widget.
        pendingOptionsRunnablesByWidgetId.remove(appWidgetId)?.let { existing ->
            mainHandler.removeCallbacks(existing)
        }

        val runnable = Runnable {
            val widgetData = HomeWidgetPlugin.getData(context)
            updateAppWidget(context, appWidgetManager, appWidgetId, widgetData)
            pendingOptionsRunnablesByWidgetId.remove(appWidgetId)
        }

        pendingOptionsRunnablesByWidgetId[appWidgetId] = runnable
        mainHandler.postDelayed(runnable, OPTIONS_CHANGE_APPLY_DELAY_MS)
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.task_widget_layout)
        val todayDate = formatTodayDate()
        val isDarkTheme = widgetData.getBoolean("widget_is_dark", false)
        
        // Get task data
        val tasksJson = widgetData.getString(KEY_TASKS, "[]") ?: "[]"
        val taskCount = widgetData.getInt(KEY_TASK_COUNT, 0)
        val nextTaskPreview = widgetData.getString("next_task", null)
        val lastUpdate = widgetData.getString("last_update", null)

        val backgroundRes = if (isDarkTheme) {
            R.drawable.widget_background
        } else {
            R.drawable.widget_background_light
        }

        val headerColor = if (isDarkTheme) 0xFFFFFFFF.toInt() else 0xFF1F2937.toInt()
        val addIconColor = 0xFFFFFFFF.toInt()
        val emptyPrimaryColor = if (isDarkTheme) 0xFFB0B0B0.toInt() else 0xFF4B5563.toInt()
        val emptySecondaryColor = if (isDarkTheme) 0xFF888888.toInt() else 0xFF6B7280.toInt()

        views.setInt(R.id.widget_container, "setBackgroundResource", backgroundRes)
        views.setTextColor(R.id.widget_date, headerColor)
        views.setInt(R.id.widget_add_button, "setColorFilter", addIconColor)
        views.setTextColor(R.id.widget_empty_text, emptyPrimaryColor)
        views.setTextColor(R.id.widget_empty_hint, emptySecondaryColor)

        var hasListAdapter = false
        
        try {
            val tasks = JSONArray(tasksJson)
            
            // Always set up the adapter first (required for ListView to work)
            val serviceIntent = Intent(context, TaskWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_task_list, serviceIntent)
            views.setTextViewText(R.id.widget_date, todayDate)

            val addTaskPendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("krama://add-task")
            )
            val openAppPendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("krama://open-app")
            )
            views.setOnClickPendingIntent(R.id.widget_add_button, addTaskPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_date, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_header_middle, openAppPendingIntent)
            
            if (taskCount == 0 || tasks.length() == 0) {
                views.setViewVisibility(R.id.widget_empty_state, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_task_list, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_empty_state, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_task_list, android.view.View.VISIBLE)
                hasListAdapter = true
                
                // Set the empty view
                views.setEmptyView(R.id.widget_task_list, R.id.widget_empty_state)
                
                // Set up mutable broadcast template so fill-in extras (taskId/action) are merged.
                val toggleIntent = Intent(context, TaskWidgetProvider::class.java).apply {
                    action = ACTION_WIDGET_INTERACTION
                    putExtra(EXTRA_WIDGET_ACTION, ACTION_TOGGLE_TASK)
                    data = Uri.parse("krama://widget-toggle-template/$appWidgetId")
                }

                // PendingIntent template must be mutable on Android 12+ so fill-in intent
                // extras/action from each row can be merged by the host process.
                var togglePendingFlags = PendingIntent.FLAG_UPDATE_CURRENT
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                    togglePendingFlags = togglePendingFlags or PendingIntent.FLAG_MUTABLE
                }

                val togglePendingIntent = PendingIntent.getBroadcast(
                    context,
                    appWidgetId,
                    toggleIntent,
                    togglePendingFlags
                )
                views.setPendingIntentTemplate(R.id.widget_task_list, togglePendingIntent)
            }

        } catch (e: Exception) {
            // Show error state
            android.util.Log.e("TaskWidgetProvider", "Error configuring widget: ${e.message}", e)
            views.setTextViewText(R.id.widget_date, todayDate)
            views.setViewVisibility(R.id.widget_empty_state, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_task_list, android.view.View.GONE)
        }
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            val sizeMap = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minW = sizeMap.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
            val minH = sizeMap.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)

            val dateSize = when {
                minW >= 250 -> 14f
                minW >= 180 -> 12f
                else -> 10f
            }
            val titleSize = when {
                minH >= 250 -> 14f
                minH >= 180 -> 12f
                else -> 11f
            }
            val timeSize = when {
                minW >= 250 -> 11f
                else -> 10f
            }

            views.setTextViewTextSize(R.id.widget_date, android.util.TypedValue.COMPLEX_UNIT_SP, dateSize)

            val editor = widgetData.edit()
            val currentTitleSize = widgetData.getFloat("widget_title_size", -1f)
            val currentTimeSize = widgetData.getFloat("widget_time_size", -1f)
            if (currentTitleSize != titleSize || currentTimeSize != timeSize) {
                editor.putFloat("widget_title_size", titleSize)
                editor.putFloat("widget_time_size", timeSize)
                editor.apply()
            }
        }

        // Update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
        
        // Only notify list adapter if it was set up with visible list
        if (hasListAdapter) {
            try {
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_task_list)
            } catch (e: Exception) {
                android.util.Log.w(
                    "TaskWidgetProvider",
                    "notifyAppWidgetViewDataChanged failed for widgetId=$appWidgetId: ${e.message}"
                )
            }
        }
    }

    private fun launchApp(context: Context, uri: Uri) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            data = uri
        }
        context.startActivity(launchIntent)
    }

    private fun formatTodayDate(): String {
        val calendar = java.util.Calendar.getInstance()
        val day = calendar.get(java.util.Calendar.DAY_OF_MONTH)
        val suffix = when {
            day in 11..13 -> "th"
            day % 10 == 1 -> "st"
            day % 10 == 2 -> "nd"
            day % 10 == 3 -> "rd"
            else -> "th"
        }
        val month = SimpleDateFormat("MMMM", Locale.getDefault()).format(Date())
        return "$month $day$suffix"
    }
}
