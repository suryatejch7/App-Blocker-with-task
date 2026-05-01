package com.android.krama

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.util.UUID
import org.json.JSONArray
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
    private var isDarkTheme: Boolean = false
    private var titleTextSize: Float = 12f
    private var timeTextSize: Float = 10f
    
    data class TaskItem(
        val id: String,
        val title: String,
        val deadlineText: String,
        val completed: Boolean,
        val isOverdue: Boolean,
        val isActive: Boolean
    )
    
    override fun onCreate() {
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
            isDarkTheme = widgetData.getBoolean("widget_is_dark", false)
            titleTextSize = widgetData.getFloat("widget_title_size", 12f)
            timeTextSize = widgetData.getFloat("widget_time_size", 10f)
            val jsonArray = JSONArray(tasksJson)
            
            val taskList = mutableListOf<TaskItem>()
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                taskList.add(TaskItem(
                    id = obj.optString("id", ""),
                    title = obj.optString("title", "Untitled Task"),
                    deadlineText = obj.optString("deadlineText", obj.optString("endTime", "")),
                    completed = obj.optBoolean("completed", false),
                    isOverdue = obj.optBoolean("isOverdue", false),
                    isActive = obj.optBoolean("isActive", false)
                ))
            }
            tasks = taskList
        } catch (e: Exception) {
            android.util.Log.e(
                "TaskWidgetService",
                "Error loading tasks in package=${context.packageName}: ${e.message}",
                e
            )
            tasks = emptyList()
        }
    }
    
    override fun onDestroy() {
        tasks = emptyList()
    }
    
    override fun getCount(): Int {
        return tasks.size
    }
    
    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.task_widget_item)
        
        if (position < 0 || position >= tasks.size) {
            views.setTextViewText(R.id.task_item_title, "Loading...")
            views.setTextViewText(R.id.task_item_time, "")
            views.setTextViewText(R.id.task_item_status, "○")
            return views
        }
        
        return try {
            val task = tasks[position]

            val overdueColor = if (isDarkTheme) 0xFFFF5252.toInt() else 0xFFD32F2F.toInt()
            val completedColor = if (isDarkTheme) 0xFF888888.toInt() else 0xFF6B7280.toInt()
            val primaryColor = if (isDarkTheme) 0xFFFFFFFF.toInt() else 0xFF1F2937.toInt()
            val secondaryColor = if (isDarkTheme) 0xFFB0B0B0.toInt() else 0xFF6B7280.toInt()

            val backgroundRes = if (task.isOverdue && !task.completed) {
                if (isDarkTheme) R.drawable.task_item_overdue_background else R.drawable.task_item_overdue_background_light
            } else {
                if (isDarkTheme) R.drawable.task_item_background else R.drawable.task_item_background_light
            }
            views.setInt(R.id.task_item_container, "setBackgroundResource", backgroundRes)
            
            // Set task title
            views.setTextViewText(R.id.task_item_title, task.title)
            views.setTextColor(R.id.task_item_title, if (task.completed) completedColor else primaryColor)
            views.setTextViewTextSize(R.id.task_item_title, android.util.TypedValue.COMPLEX_UNIT_SP, titleTextSize)
            
            // Set time range
            val deadlineText = if (task.deadlineText.isNotEmpty()) {
                "Due ${task.deadlineText}"
            } else {
                "No deadline set"
            }
            views.setTextViewText(R.id.task_item_time, deadlineText)
            views.setTextColor(R.id.task_item_time, secondaryColor)
            views.setTextViewTextSize(R.id.task_item_time, android.util.TypedValue.COMPLEX_UNIT_SP, timeTextSize)
            
            // Set status indicator
            val statusIcon = when {
                task.completed -> "✓"
                else -> "○"
            }
            views.setTextViewText(R.id.task_item_status, statusIcon)
            views.setTextColor(
                R.id.task_item_status,
                when {
                    task.completed -> 0xFF4CAF50.toInt()
                    task.isOverdue -> overdueColor
                    else -> 0xFFB0B0B0.toInt()
                }
            )

            val fillInIntent = Intent().apply {
                action = "${TaskWidgetProvider.ACTION_TOGGLE_TASK}.${task.id}"
                data = Uri.parse("krama://toggle-task/${task.id}")
                putExtra(TaskWidgetProvider.EXTRA_TASK_ID, task.id)
                putExtra(TaskWidgetProvider.EXTRA_WIDGET_ACTION, TaskWidgetProvider.ACTION_TOGGLE_TASK)
            }
            views.setOnClickFillInIntent(R.id.task_item_container, fillInIntent)
            views.setOnClickFillInIntent(R.id.task_item_status, fillInIntent)
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
        return RemoteViews(context.packageName, R.layout.task_widget_loading)
    }
    
    override fun getViewTypeCount(): Int {
        return 1
    }
    
    override fun getItemId(position: Int): Long {
        if (position < 0 || position >= tasks.size) return position.toLong()
        return stableItemId(tasks[position].id)
    }
    
    // Use stable IDs so launcher hosts don't mismatch recycled rows/fill-in intents.
    override fun hasStableIds(): Boolean {
        return true
    }

    private fun stableItemId(taskId: String): Long {
        return try {
            val uuid = UUID.fromString(taskId)
            uuid.mostSignificantBits xor uuid.leastSignificantBits
        } catch (_: Exception) {
            taskId.hashCode().toLong()
        }
    }
}
