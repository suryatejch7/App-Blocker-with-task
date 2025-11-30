package com.example.habit_tracker_flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.graphics.Color
import android.graphics.Typeface
import android.view.View
import android.view.Gravity
import android.widget.TextView
import android.widget.LinearLayout
import android.widget.ScrollView
import org.json.JSONArray

class BlockingActivity : Activity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Get intent extras
        val blockedPackage = intent.getStringExtra("blockedPackage") ?: ""
        val isPermanent = intent.getBooleanExtra("isPermanent", false)
        val tasksJson = intent.getStringExtra("pendingTasks") ?: "[]"
        
        android.util.Log.d("BlockingActivity", "Blocked package: $blockedPackage")
        android.util.Log.d("BlockingActivity", "Is permanent: $isPermanent")
        android.util.Log.d("BlockingActivity", "Tasks JSON: $tasksJson")
        
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
            android.util.Log.e("BlockingActivity", "Error parsing tasks: $e")
        }
        
        // Create layout programmatically
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#121212"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
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
            // Permanent block message
            val messageText = TextView(this).apply {
                text = "This app has been permanently blocked.\nYou chose to block this app 24/7."
                textSize = 16f
                setTextColor(Color.parseColor("#BBBBBB"))
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 40)
            }
            contentLayout.addView(messageText)
            
            // Info card
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
                text = "To unblock this app, go to Settings > Restrictions in the Habit Tracker app and remove it from the 'Always Block' list."
                textSize = 14f
                setTextColor(Color.parseColor("#888888"))
            }
            infoCard.addView(infoText)
            contentLayout.addView(infoCard)
            
        } else {
            // Task-based block message
            val messageText = TextView(this).apply {
                text = "Complete your pending tasks to unlock access"
                textSize = 16f
                setTextColor(Color.parseColor("#4A90E2"))
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 32)
            }
            contentLayout.addView(messageText)
            
            // Pending tasks section
            if (tasks.isNotEmpty()) {
                val tasksHeader = TextView(this).apply {
                    text = "PENDING TASKS (${tasks.size})"
                    textSize = 12f
                    setTextColor(Color.parseColor("#888888"))
                    setTypeface(null, Typeface.BOLD)
                    setPadding(0, 0, 0, 16)
                }
                contentLayout.addView(tasksHeader)
                
                // Task cards
                for (task in tasks) {
                    val taskCard = createTaskCard(task)
                    contentLayout.addView(taskCard)
                }
            } else {
                val noTasksText = TextView(this).apply {
                    text = "No pending tasks found.\nOpen the app to refresh."
                    textSize = 14f
                    setTextColor(Color.parseColor("#888888"))
                    gravity = Gravity.CENTER
                    setPadding(0, 16, 0, 16)
                }
                contentLayout.addView(noTasksText)
            }
        }
        
        scrollView.addView(contentLayout)
        rootLayout.addView(scrollView)
        
        // Bottom button - Open Habit Tracker
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
        
        setContentView(rootLayout)
        
        // Make it fullscreen
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        )
    }
    
    private fun createTaskCard(task: Map<String, Any>): LinearLayout {
        val isOverdue = task["isOverdue"] as? Boolean ?: false
        val title = task["title"] as? String ?: "Untitled Task"
        val description = task["description"] as? String ?: ""
        
        val cardLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#1E1E1E"))
            setPadding(24, 20, 24, 20)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 12)
            }
            
            // Make the card clickable to open the app
            setOnClickListener {
                openHabitTracker()
            }
        }
        
        // Status indicator
        val statusDot = View(this).apply {
            setBackgroundColor(if (isOverdue) Color.parseColor("#FF5252") else Color.parseColor("#4A90E2"))
            layoutParams = LinearLayout.LayoutParams(12, 12).apply {
                setMargins(0, 8, 16, 0)
            }
        }
        cardLayout.addView(statusDot)
        
        // Task info
        val infoLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        
        val titleText = TextView(this).apply {
            text = title
            textSize = 16f
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
        }
        infoLayout.addView(titleText)
        
        if (description.isNotEmpty()) {
            val descText = TextView(this).apply {
                text = description
                textSize = 13f
                setTextColor(Color.parseColor("#888888"))
                maxLines = 1
            }
            infoLayout.addView(descText)
        }
        
        if (isOverdue) {
            val overdueText = TextView(this).apply {
                text = "OVERDUE"
                textSize = 11f
                setTextColor(Color.parseColor("#FF5252"))
                setTypeface(null, Typeface.BOLD)
                setPadding(0, 4, 0, 0)
            }
            infoLayout.addView(overdueText)
        }
        
        cardLayout.addView(infoLayout)
        
        // Arrow indicator
        val arrowText = TextView(this).apply {
            text = "→"
            textSize = 20f
            setTextColor(Color.parseColor("#4A90E2"))
            gravity = Gravity.CENTER
            setPadding(16, 0, 0, 0)
        }
        cardLayout.addView(arrowText)
        
        return cardLayout
    }
    
    private fun openHabitTracker() {
        val intent = packageManager.getLaunchIntentForPackage("com.example.habit_tracker_flutter")
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(intent)
        }
        finish()
    }
    
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // For permanent blocks, allow going to home screen
        // For task-based blocks, also allow home screen but not the blocked app
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }
}
