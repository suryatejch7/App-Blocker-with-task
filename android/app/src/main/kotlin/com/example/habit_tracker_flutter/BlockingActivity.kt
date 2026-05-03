package com.android.krama

import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import org.json.JSONArray

class BlockingActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())

    companion object {
        private val emergencyUsedPackages = mutableSetOf<String>()
        private val EMERGENCY_STEPS = intArrayOf(10, 20, 30, 40, 50, 60)
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupWindowFlags()
        
        val blockedPackage = intent.getStringExtra("blockedPackage") ?: ""
        val isPermanent   = intent.getBooleanExtra("isPermanent", false)
        val tasksJson     = intent.getStringExtra("pendingTasks") ?: "[]"
        val emergencyAllowed = intent.getBooleanExtra("emergencyAllowed", true)
        
        android.util.Log.d("BlockingActivity", "Blocked package: $blockedPackage")
        android.util.Log.d("BlockingActivity", "Is permanent: $isPermanent")
        android.util.Log.d("BlockingActivity", "Tasks JSON: $tasksJson")
        
        val tasks = parseTasks(tasksJson)
        val showEmergency = emergencyAllowed && !emergencyUsedPackages.contains(blockedPackage)

        // ── Root ────────────────────────────────────────────────────────────
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#121212"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        // ── Scrollable content ──────────────────────────────────────────────
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
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
        
        val iconText = TextView(this).apply {
            text = if (isPermanent) "🚫" else "🔒"
            textSize = 64f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }
        contentLayout.addView(iconText)
        
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
                ).apply { setMargins(0, 0, 0, 32) }
            }
            val infoText = TextView(this).apply {
                text = "To unblock this app, go to Settings > Restrictions in the Krama app and remove it from the 'Always Block' list."
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
                for (task in tasks) contentLayout.addView(createTaskCard(task))
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

        // ── Bottom action area ──────────────────────────────────────────────
        val buttonLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 16, 48, 48)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        if (showEmergency) {
            buttonLayout.addView(buildEmergencySection(blockedPackage, isPermanent, tasksJson))
        }

        // Divider
        val divider = View(this).apply {
            setBackgroundColor(Color.parseColor("#2A2A2A"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 1
            ).apply { setMargins(0, 8, 0, 16) }
        }
        buttonLayout.addView(divider)
        
        val openAppButton = TextView(this).apply {
            text = if (isPermanent) "Open Krama" else "Open App to Complete Tasks"
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
            setOnClickListener { openHabitTracker() }
        }
        buttonLayout.addView(openAppButton)
        
        rootLayout.addView(buttonLayout)
        setContentView(rootLayout)
    }

    // ── Emergency section ───────────────────────────────────────────────────

    private fun buildEmergencySection(
        blockedPackage: String,
        isPermanent: Boolean,
        tasksJson: String
    ): LinearLayout {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            setPadding(32, 24, 32, 24)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, 0, 0, 16) }
        }

        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        headerRow.addView(TextView(this).apply {
            text = "⚠️"
            textSize = 18f
            setPadding(0, 0, 12, 0)
        })
        headerRow.addView(TextView(this).apply {
            text = "Emergency Access"
            textSize = 14f
            setTextColor(Color.parseColor("#FFA726"))
            setTypeface(null, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        })
        headerRow.addView(TextView(this).apply {
            text = "ONE-TIME"
            textSize = 10f
            setTextColor(Color.parseColor("#FF5252"))
            setTypeface(null, Typeface.BOLD)
            setBackgroundColor(Color.parseColor("#2A0A0A"))
            setPadding(8, 4, 8, 4)
        })
        card.addView(headerRow)

        val durationLabel = TextView(this).apply {
            text = "Extend by: 10 seconds"
            textSize = 13f
            setTextColor(Color.parseColor("#CCCCCC"))
            setPadding(0, 16, 0, 8)
        }
        card.addView(durationLabel)

        val seekBar = SeekBar(this).apply {
            max = EMERGENCY_STEPS.size - 1
            progress = 0
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                durationLabel.text = "Extend by: ${EMERGENCY_STEPS[progress]} seconds"
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {}
            override fun onStopTrackingTouch(sb: SeekBar?) {
                val secs = EMERGENCY_STEPS[sb?.progress ?: 0]
                android.util.Log.d("BlockingActivity", "🟡 Emergency extend: $secs s for $blockedPackage")
                emergencyUsedPackages.add(blockedPackage)
                scheduleReBlock(blockedPackage, isPermanent, tasksJson, secs)
                finish()
            }
        })

        card.addView(seekBar)

        card.addView(TextView(this).apply {
            text = "Slide to choose duration, then release to activate. Cannot be used again."
            textSize = 11f
            setTextColor(Color.parseColor("#666666"))
            setPadding(0, 8, 0, 0)
        })

        return card
    }

    private fun scheduleReBlock(
        blockedPackage: String,
        isPermanent: Boolean,
        tasksJson: String,
        seconds: Int
    ) {
        handler.postDelayed({
            if (isPackageVisible(blockedPackage)) {
                android.util.Log.d("BlockingActivity", "🔴 Emergency expired – re-blocking $blockedPackage")
                val intent = Intent(applicationContext, BlockingActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_NO_HISTORY or
                            Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                    putExtra("blockedPackage", blockedPackage)
                    putExtra("isPermanent", isPermanent)
                    putExtra("pendingTasks", tasksJson)
                    putExtra("emergencyAllowed", false) // no second chance
                }
                startActivity(intent)
            } else {
                android.util.Log.d("BlockingActivity", "✅ $blockedPackage gone after emergency – no re-block")
            }
        }, seconds * 1000L)
    }

    private fun isPackageVisible(packageName: String): Boolean {
        return try {
            val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                am.appTasks?.any { task ->
                    task.taskInfo?.topActivity?.packageName == packageName ||
                    task.taskInfo?.baseActivity?.packageName == packageName
                } ?: false
            } else {
                @Suppress("DEPRECATION")
                am.getRunningTasks(1)?.firstOrNull()?.topActivity?.packageName == packageName
            }
        } catch (e: Exception) {
            false
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun parseTasks(tasksJson: String): List<Map<String, Any>> {
        val tasks = mutableListOf<Map<String, Any>>()
        try {
            val arr = JSONArray(tasksJson)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                tasks.add(mutableMapOf<String, Any>(
                    "id" to obj.optString("id", ""),
                    "title" to obj.optString("title", ""),
                    "description" to obj.optString("description", ""),
                    "isOverdue" to obj.optBoolean("isOverdue", false)
                ))
            }
        } catch (e: Exception) {
            android.util.Log.e("BlockingActivity", "Error parsing tasks: $e")
        }
        return tasks
    }
    
    private fun createTaskCard(task: Map<String, Any>): LinearLayout {
        val isOverdue   = task["isOverdue"] as? Boolean ?: false
        val title       = task["title"] as? String ?: "Untitled Task"
        val description = task["description"] as? String ?: ""
        
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#1E1E1E"))
            setPadding(24, 20, 24, 20)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, 0, 0, 12) }
            setOnClickListener { openHabitTracker() }

            val statusDot = View(this@BlockingActivity).apply {
                setBackgroundColor(if (isOverdue) Color.parseColor("#FF5252") else Color.parseColor("#4A90E2"))
                layoutParams = LinearLayout.LayoutParams(12, 12).apply { setMargins(0, 8, 16, 0) }
            }
            addView(statusDot)

            val infoLayout = LinearLayout(this@BlockingActivity).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            infoLayout.addView(TextView(this@BlockingActivity).apply {
                text = title
                textSize = 16f
                setTextColor(Color.WHITE)
                setTypeface(null, Typeface.BOLD)
            })
            if (description.isNotEmpty()) {
                infoLayout.addView(TextView(this@BlockingActivity).apply {
                    text = description
                    textSize = 13f
                    setTextColor(Color.parseColor("#888888"))
                    maxLines = 1
                })
            }
            if (isOverdue) {
                infoLayout.addView(TextView(this@BlockingActivity).apply {
                    text = "OVERDUE"
                    textSize = 11f
                    setTextColor(Color.parseColor("#FF5252"))
                    setTypeface(null, Typeface.BOLD)
                    setPadding(0, 4, 0, 0)
                })
            }
            addView(infoLayout)

            addView(TextView(this@BlockingActivity).apply {
                text = "→"
                textSize = 20f
                setTextColor(Color.parseColor("#4A90E2"))
                gravity = Gravity.CENTER
                setPadding(16, 0, 0, 0)
            })
        }
    }
    
    private fun openHabitTracker() {
        packageManager.getLaunchIntentForPackage("com.android.krama")?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(it)
        }
        finish()
    }
    
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        startActivity(Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        })
        finish()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
    
    private fun setupWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        )
    }
}