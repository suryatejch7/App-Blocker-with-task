package com.android.krama

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Service that provides the data for the scrollable task list in the widget.
 */
class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TaskRemoteViewsFactory(applicationContext)
    }
}

/**
 * Factory that creates the individual task item views for the widget ListView.
 */
class TaskRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    
    private var tasks: List<TaskItem> = emptyList()
    
    data class TaskItem(
        val id: String,
        val title: String,
        val description: String,
        val startTime: String,
        val endTime: String,
        val completed: Boolean,
        val isOverdue: Boolean,
        val isActive: Boolean
    )
    
    override fun onCreate() {
        // Initial setup - load tasks immediately
        loadTasks()
    }
    
    override fun onDataSetChanged() {
        // Reload data from SharedPreferences
        // Clear Binder identity to avoid security exceptions when accessing SharedPreferences
        val identityToken = android.os.Binder.clearCallingIdentity()
        try {
            loadTasks()
        } finally {
            android.os.Binder.restoreCallingIdentity(identityToken)
        }
    }
    
    private fun loadTasks() {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val tasksJson = widgetData.getString("tasks_data", "[]") ?: "[]"
            val jsonArray = JSONArray(tasksJson)
            
            val taskList = mutableListOf<TaskItem>()
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                taskList.add(TaskItem(
                    id = obj.optString("id", ""),
                    title = obj.optString("title", "Untitled Task"),
                    description = obj.optString("description", ""),
                    startTime = obj.optString("startTime", ""),
                    endTime = obj.optString("endTime", ""),
                    completed = obj.optBoolean("completed", false),
                    isOverdue = obj.optBoolean("isOverdue", false),
                    isActive = obj.optBoolean("isActive", false)
                ))
            }
            tasks = taskList
            android.util.Log.d("TaskWidgetService", "Loaded ${tasks.size} tasks")
        } catch (e: Exception) {
            android.util.Log.e("TaskWidgetService", "Error loading tasks: ${e.message}")
            tasks = emptyList()
        }
    }
    
    override fun onDestroy() {
        tasks = emptyList()
    }
    
    override fun getCount(): Int {
        android.util.Log.d("TaskWidgetService", "getCount called, returning ${tasks.size}")
        return tasks.size
    }
    
    override fun getViewAt(position: Int): RemoteViews {
        android.util.Log.d("TaskWidgetService", "getViewAt called for position: $position, tasks.size: ${tasks.size}")
        
        val views = RemoteViews(context.packageName, R.layout.task_widget_item)
        
        if (position < 0 || position >= tasks.size) {
            android.util.Log.e("TaskWidgetService", "Invalid position: $position, returning placeholder")
            views.setTextViewText(R.id.task_item_title, "Loading...")
            views.setTextViewText(R.id.task_item_time, "")
            views.setTextViewText(R.id.task_item_status, "○")
            return views
        }
        
        return try {
            val task = tasks[position]
            
            android.util.Log.d("TaskWidgetService", "Rendering task: ${task.title}")
            
            // Set task title
            views.setTextViewText(R.id.task_item_title, task.title)
            
            // Set time range
            val timeText = if (task.startTime.isNotEmpty() && task.endTime.isNotEmpty()) {
                "${task.startTime} - ${task.endTime}"
            } else if (task.startTime.isNotEmpty()) {
                task.startTime
            } else {
                "No time set"
            }
            views.setTextViewText(R.id.task_item_time, timeText)
            
            // Set status indicator
            val statusIcon = when {
                task.completed -> "✓"
                task.isOverdue -> "⚠"
                task.isActive -> "▶"
                else -> "○"
            }
            views.setTextViewText(R.id.task_item_status, statusIcon)
            
            // Set text color based on status
            val textColor = when {
                task.completed -> 0xFF888888.toInt() // Gray for completed
                task.isOverdue -> 0xFFE57373.toInt() // Red for overdue
                task.isActive -> 0xFF81C784.toInt()  // Green for active
                else -> 0xFFFFFFFF.toInt()           // White for upcoming
            }
            views.setTextColor(R.id.task_item_title, textColor)
            
            // Set up fill-in intent for click handling
            val fillInIntent = Intent().apply {
                putExtra(TaskWidgetProvider.EXTRA_TASK_ID, task.id)
            }
            views.setOnClickFillInIntent(R.id.task_item_container, fillInIntent)
            
            android.util.Log.d("TaskWidgetService", "Successfully created view for task: ${task.title}")
            views
        } catch (e: Exception) {
            android.util.Log.e("TaskWidgetService", "Error in getViewAt: ${e.message}", e)
            // Return a placeholder view instead of null
            views.setTextViewText(R.id.task_item_title, "Error loading task")
            views.setTextViewText(R.id.task_item_time, "")
            views.setTextViewText(R.id.task_item_status, "!")
            views
        }
    }
    
    override fun getLoadingView(): RemoteViews {
        android.util.Log.d("TaskWidgetService", "getLoadingView called")
        return RemoteViews(context.packageName, R.layout.task_widget_loading)
    }
    
    override fun getViewTypeCount(): Int = 1
    
    override fun getItemId(position: Int): Long = position.toLong()
    
    // Return false since task IDs are UUIDs (strings) which cannot be 
    // reliably converted to unique longs without collision risk
    override fun hasStableIds(): Boolean = false
}
