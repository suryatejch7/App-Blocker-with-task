# Debugging Guide - App Blocking Not Working

## Issues Identified

### 1. ❌ **Tasks Not Detected as Active**
Logs show:
```
📋 Found 0 active/overdue tasks
🔒 Restrictions should be active: false
```

**Possible Causes:**
- Timezone conversion issue (UTC vs local time)
- Task times not matching current time
- `isActive` getter logic issue

### 2. ❌ **Restrictions Not Being Sent to Android**
Even though sync is happening, restrictions might not reach the Android service.

## Debug Logs Added

### Flutter Side:
- ✅ TaskProvider.syncRestrictions() - Shows which apps should be restricted
- ✅ RestrictionService.updateRestrictions() - Shows data being sent to native
- ✅ SupabaseService - Shows data loading from database

### Android Side (NEW!):
- ✅ AppBlockingService.onServiceConnected() - Shows when service starts
- ✅ AppBlockingService.loadRestrictions() - Shows what's loaded from SharedPreferences  
- ✅ AppBlockingService.updateRestrictions() - Shows when Flutter sends new restrictions
- ✅ AppBlockingService.onAccessibilityEvent() - Shows EVERY app switch with detailed info

## Expected Log Flow

### When App Starts:
```
[Flutter] 🚀 ========== APP STARTING ==========
[Flutter] 🟢 TaskProvider._load - Loading tasks...
[Flutter] 🟢 RestrictionsProvider._load - Loading restrictions...
[Android] ========== LOADING RESTRICTIONS ==========
[Android] Apps JSON from prefs: ["com.instagram.android"]
[Android] Loaded 1 restricted apps: [com.instagram.android]
```

### When Restriction Added:
```
[Flutter] 🟢 RestrictionsProvider.addApp - Adding app: com.whatsapp
[Flutter] ✅ Saved to Supabase
[Flutter] 🔗 Notifying TaskProvider
[Flutter] 🔄 TaskProvider.syncRestrictions - SYNCING
[Flutter] 📱 Total apps to restrict: 2
[Flutter] 📡 Sending to native Android service...
[Android] ========== UPDATE RESTRICTIONS CALLED ==========
[Android] Apps to restrict (2): [com.instagram.android, com.whatsapp]
[Android] Active: true
[Android] ========== UPDATE COMPLETE ==========
```

### When You Open Instagram:
```
[Android] ========== NEW EVENT ==========
[Android] Package: com.instagram.android
[Android] Restrictions active: true
[Android] Restricted apps count: 2
[Android] Restricted apps list: [com.instagram.android, com.whatsapp]
[Android] Window state changed event detected
[Android] 🚫 BLOCKING APP: com.instagram.android
```

## Testing Steps

1. **Hot reload the app:**
   ```bash
   flutter run --hot
   ```

2. **Check task time:**
   - Open your task details
   - Verify start time is in the PAST
   - Verify end time is in the FUTURE
   - Make sure it's NOT completed

3. **Add Instagram to restrictions** (if not already added)
   - Watch Flutter logs for sync

4. **Open Instagram:**
   - Watch Android logs for blocking attempt
   - Should see "🚫 BLOCKING APP" message

5. **If still not working, check these logs:**
   - `Restrictions active: true` ← Should be true
   - `Restricted apps list:` ← Should contain com.instagram.android
   - `Service instance exists: true` ← Should be true

## Common Issues

### Issue: "Service instance exists: false"
**Solution:** Restart the accessibility service:
1. Settings → Accessibility → Habit Tracker → Turn OFF
2. Wait 5 seconds
3. Turn ON again

### Issue: "Restrictions active: false"
**Problem:** No active tasks found
**Solution:** Check task start/end times match current time

### Issue: "Restricted apps list: []"  
**Problem:** Sync didn't work
**Solution:** Check Flutter logs for sync errors

## Manual Test Command

After hot reload, run this in terminal to check logs:
```bash
adb logcat | grep -E "(AppBlockingService|flutter)"
```

This will show both Flutter and Android logs together.
