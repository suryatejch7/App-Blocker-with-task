package com.example.habit_tracker_flutter

import android.app.Activity
import android.os.Bundle
import android.graphics.Color
import android.view.View
import android.widget.TextView
import android.widget.LinearLayout

class BlockingActivity : Activity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Create layout programmatically with black background and blue/yellow accents
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
            setPadding(40, 80, 40, 80)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
        }
        
        // Title
        val titleText = TextView(this).apply {
            text = "🔒 App Blocked"
            textSize = 28f
            setTextColor(Color.parseColor("#FFD700")) // Yellow
            setPadding(0, 0, 0, 40)
        }
        rootLayout.addView(titleText)
        
        // Message
        val messageText = TextView(this).apply {
            text = "Complete your pending tasks to unlock access"
            textSize = 18f
            setTextColor(Color.parseColor("#4A90E2")) // Blue
            setPadding(0, 0, 0, 60)
        }
        rootLayout.addView(messageText)
        
        // Instruction
        val instructionText = TextView(this).apply {
            text = "Return to Habit Tracker to mark tasks as complete"
            textSize = 16f
            setTextColor(Color.WHITE)
            setPadding(0, 0, 0, 40)
        }
        rootLayout.addView(instructionText)
        
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
    
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Prevent back button from dismissing - user must complete tasks
    }
}
