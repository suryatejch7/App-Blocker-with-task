package com.android.krama

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.app.PendingIntent
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget provider for displaying tasks.
 * Extends HomeWidgetProvider for easy access to Flutter-synced SharedPreferences.
 */
class TaskWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_TASK_CLICK = "com.android.krama.ACTION_TASK_CLICK"
        const val ACTION_REFRESH = "com.android.krama.ACTION_REFRESH"
        const val EXTRA_TASK_ID = "taskId"
        
        private const val KEY_TASKS = "tasks_data"
        private const val KEY_TASK_COUNT = "task_count"
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
            ACTION_TASK_CLICK -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)
                if (taskId.isNullOrEmpty()) return
                // Launch app with task ID
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    data = Uri.parse("habittracker://task?taskId=$taskId")
                }
                context.startActivity(launchIntent)
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

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences
    ) {
        android.util.Log.d("TaskWidgetProvider", "updateAppWidget called for appWidgetId: $appWidgetId")
        
        val views = RemoteViews(context.packageName, R.layout.task_widget_layout)
        
        // Get task data
        val tasksJson = widgetData.getString(KEY_TASKS, "[]") ?: "[]"
        val taskCount = widgetData.getInt(KEY_TASK_COUNT, 0)
        
        android.util.Log.d("TaskWidgetProvider", "Task count: $taskCount, JSON length: ${tasksJson.length}")
        
        // Track if we should notify the list adapter
        var hasListAdapter = false
        
        try {
            val tasks = JSONArray(tasksJson)
            android.util.Log.d("TaskWidgetProvider", "Parsed ${tasks.length()} tasks from JSON")
            
            // Always set up the adapter first (required for ListView to work)
            val serviceIntent = Intent(context, TaskWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_task_list, serviceIntent)
            
            if (taskCount == 0 || tasks.length() == 0) {
                // Show empty state
                android.util.Log.d("TaskWidgetProvider", "Showing empty state")
                views.setTextViewText(R.id.widget_title, "📋 Today's Tasks")
                views.setTextViewText(R.id.widget_subtitle, "No tasks for today")
                views.setViewVisibility(R.id.widget_empty_state, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_task_list, android.view.View.GONE)
            } else {
                // Show task list
                android.util.Log.d("TaskWidgetProvider", "Showing task list with $taskCount tasks")
                views.setTextViewText(R.id.widget_title, "📋 Today's Tasks")
                views.setTextViewText(R.id.widget_subtitle, "$taskCount task${if (taskCount > 1) "s" else ""}")
                views.setViewVisibility(R.id.widget_empty_state, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_task_list, android.view.View.VISIBLE)
                hasListAdapter = true
                
                // Set the empty view
                views.setEmptyView(R.id.widget_task_list, R.id.widget_empty_state)
                
                // Set up click handling template for list items
                val clickIntent = Intent(context, TaskWidgetProvider::class.java).apply {
                    action = ACTION_TASK_CLICK
                }
                val clickPendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    clickIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_task_list, clickPendingIntent)
            }
            
            // Set up tap on header to open app
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                1,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_header, openAppPendingIntent)
            
            // Set up refresh button
            val refreshIntent = Intent(context, TaskWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                2,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_button, refreshPendingIntent)
            
            android.util.Log.d("TaskWidgetProvider", "Widget views configured successfully")
            
        } catch (e: Exception) {
            // Show error state
            android.util.Log.e("TaskWidgetProvider", "Error configuring widget: ${e.message}", e)
            views.setTextViewText(R.id.widget_title, "📋 Tasks")
            views.setTextViewText(R.id.widget_subtitle, "Tap to open app")
            views.setViewVisibility(R.id.widget_empty_state, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_task_list, android.view.View.GONE)
        }
        
        // Update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
        android.util.Log.d("TaskWidgetProvider", "updateAppWidget completed")
        
        // Only notify list adapter if it was set up with visible list
        if (hasListAdapter) {
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_task_list)
            android.util.Log.d("TaskWidgetProvider", "notifyAppWidgetViewDataChanged called")
        }
    }
}
