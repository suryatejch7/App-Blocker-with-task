import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

/// Service for managing Android home screen widget data synchronization.
///
/// This service handles:
/// - Serializing task data for the native widget
/// - Updating widget when tasks change
/// - Handling widget tap interactions
class HomeWidgetService {
  static const String _appGroupId = 'group.habit_tracker_flutter';
  static const String _androidWidgetName = 'TaskWidgetProvider';

  // Data keys for widget shared preferences
  static const String _keyTasks = 'tasks_data';
  static const String _keyTaskCount = 'task_count';
  static const String _keyNextTask = 'next_task';
  static const String _keyLastUpdate = 'last_update';
  static const String _keyWidgetIsDark = 'widget_is_dark';
  static const String _themeKey = 'theme_mode';
  static const String lastWidgetToggleAtKey = 'last_widget_toggle_at_ms';
  static const String pendingWidgetTogglesKey = 'pending_widget_toggles';

  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  /// Initialize the home widget service
  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      HomeWidget.registerInteractivityCallback(backgroundCallback);
      debugPrint('✅ HomeWidgetService initialized');
    } catch (e) {
      debugPrint('❌ HomeWidgetService initialization error: $e');
    }
  }

  /// Update widget with current task list.
  ///
  /// Shows two groups in order:
  ///   1. Overdue / past-deadline tasks (any day), sorted by deadline ascending.
  ///   2. Today's pending + completed tasks, sorted by deadline ascending.
  ///
  /// Completed tasks that are NOT overdue and NOT from today are omitted —
  /// they're done and gone, no need to clutter the widget.
  Future<bool> updateWidgetWithTasks(List<Task> tasks) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      final isDarkMode = await _readIsDarkTheme();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // ── Group 1: overdue tasks (past deadline, not yet completed) ──────────
      // These can be from any previous day (or even today if deadline already
      // passed). Sort by endTime ascending so the most-overdue appears first.
      final overdueTasks = tasks
          .where((t) => t.isOverdue && !t.completed)
          .toList()
        ..sort((a, b) => a.endTime.compareTo(b.endTime));

      // ── Group 2: today's tasks (excluding already-included overdue ones) ────
      // Include both pending and completed tasks scheduled for today.
      final todayTasks = tasks.where((task) {
        final taskDate = DateTime(
          task.startTime.year,
          task.startTime.month,
          task.startTime.day,
        );
        // Already shown above if overdue.
        if (task.isOverdue && !task.completed) return false;
        return taskDate.isAtSameMomentAs(today);
      }).toList()
        ..sort((a, b) => a.endTime.compareTo(b.endTime));

      // ── Merge: overdue first, then today ────────────────────────────────────
      final widgetTasks = [...overdueTasks, ...todayTasks];

      debugPrint(
          '📊 HomeWidgetService: ${overdueTasks.length} overdue + ${todayTasks.length} today = ${widgetTasks.length} total');

      // Serialize for widget
      final tasksJson = widgetTasks
          .map((task) => <String, dynamic>{
                'id': task.id,
                'title': task.title,
                'description': task.description,
                'startTime': _formatTime(task.startTime),
                'endTime': _formatTime(task.endTime),
                'deadlineText': _formatDeadlineText(task, today),
                'completed': task.completed,
                'isOverdue': task.isOverdue,
                'isActive': task.isActive,
              })
          .toList();

      await HomeWidget.saveWidgetData<String>(
        _keyTasks,
        jsonEncode(tasksJson),
      );

      await HomeWidget.saveWidgetData<int>(
        _keyTaskCount,
        widgetTasks.length,
      );

      // Save next upcoming task info (overdue takes priority)
      final nextTask = _getNextUpcomingTask(widgetTasks);
      if (nextTask != null) {
        await HomeWidget.saveWidgetData<String>(
          _keyNextTask,
          jsonEncode({
            'id': nextTask.id,
            'title': nextTask.title,
            'startTime': _formatTime(nextTask.startTime),
            'endTime': _formatTime(nextTask.endTime),
            'isOverdue': nextTask.isOverdue,
          }),
        );
      } else {
        await HomeWidget.saveWidgetData<String>(_keyNextTask, '');
      }

      await HomeWidget.saveWidgetData<String>(
        _keyLastUpdate,
        DateTime.now().toIso8601String(),
      );

      await HomeWidget.saveWidgetData<bool>(_keyWidgetIsDark, isDarkMode);

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'com.android.krama.$_androidWidgetName',
      );

      debugPrint(
          '✅ HomeWidgetService: Widget updated with ${widgetTasks.length} tasks');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ HomeWidgetService: Error updating widget: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Produces a deadline label that includes the date for overdue tasks
  /// so the user can see at a glance how far past they are.
  ///
  /// Examples:
  ///   - Overdue from yesterday  → "Apr 9 · 11:00 PM"
  ///   - Overdue from today      → "11:00 PM (overdue)"
  ///   - Normal today task       → "11:00 PM"
  String _formatDeadlineText(Task task, DateTime today) {
    final taskDay = DateTime(
      task.endTime.year,
      task.endTime.month,
      task.endTime.day,
    );
    final isFromPreviousDay = taskDay.isBefore(today);

    if (task.isOverdue && !task.completed) {
      if (isFromPreviousDay) {
        // Show date so user knows how old the overdue task is.
        final month = _monthAbbr(task.endTime.month);
        return '$month ${task.endTime.day} · ${_formatTime(task.endTime)}';
      } else {
        return '${_formatTime(task.endTime)} (overdue)';
      }
    }
    return _formatTime(task.endTime);
  }

  String _monthAbbr(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  /// Update only the widget theme without changing task data.
  Future<bool> updateWidgetTheme(bool isDarkMode) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      await HomeWidget.saveWidgetData<bool>(_keyWidgetIsDark, isDarkMode);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'com.android.krama.$_androidWidgetName',
      );
      debugPrint(
          '✅ HomeWidgetService: Widget theme updated (dark=$isDarkMode)');
      return true;
    } catch (e) {
      debugPrint('❌ HomeWidgetService: Error updating widget theme: $e');
      return false;
    }
  }

  /// Priority order: overdue → active → upcoming
  Task? _getNextUpcomingTask(List<Task> tasks) {
    final now = DateTime.now();

    final overdueTasks =
        tasks.where((t) => t.isOverdue && !t.completed).toList();
    if (overdueTasks.isNotEmpty) return overdueTasks.first;

    final activeTasks = tasks.where((t) => t.isActive && !t.completed).toList();
    if (activeTasks.isNotEmpty) return activeTasks.first;

    final upcomingTasks =
        tasks.where((t) => !t.completed && t.startTime.isAfter(now)).toList();
    if (upcomingTasks.isNotEmpty) return upcomingTasks.first;

    return null;
  }

  /// Format time for display in widget  (e.g. "9:05 AM")
  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  Future<bool> _readIsDarkTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_themeKey) ?? false;
    } catch (e) {
      debugPrint('⚠️ HomeWidgetService: Unable to read theme preference: $e');
      return false;
    }
  }

  /// Clear all widget data
  Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData<String>(_keyTasks, '[]');
      await HomeWidget.saveWidgetData<int>(_keyTaskCount, 0);
      await HomeWidget.saveWidgetData<String>(_keyNextTask, '');
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'com.android.krama.$_androidWidgetName',
      );
      debugPrint('✅ HomeWidgetService: Widget data cleared');
    } catch (e) {
      debugPrint('❌ HomeWidgetService: Error clearing widget data: $e');
    }
  }

  /// Handle widget click - returns the URI that was clicked
  Future<Uri?> getWidgetClickUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('❌ HomeWidgetService: Error getting widget click URI: $e');
      return null;
    }
  }

  /// Check if app was launched from widget and get task ID if available
  Future<String?> getLaunchedTaskId() async {
    final uri = await getWidgetClickUri();
    if (uri != null && uri.queryParameters.containsKey('taskId')) {
      return uri.queryParameters['taskId'];
    }
    return null;
  }
}

/// Background callback for widget interactions
/// This is called when widget is tapped while app is in background
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  debugPrint('🔔 HomeWidget background callback: $uri');

  if (uri == null) return;

  final action = uri.host;
  final taskId = uri.queryParameters['taskId'];
  debugPrint('🔔 Widget action: $action, taskId: $taskId');

  if (action != 'toggle-task' || taskId == null || taskId.isEmpty) return;

  try {
    final prefs = await SharedPreferences.getInstance();

    // CRITICAL: Reload to clear memory cache, otherwise it will revive already
    // processed events that the foreground isolate deleted, leading to stale
    // events toggling tasks backward!
    await prefs.reload();

    final pendingEvents =
        prefs.getStringList(HomeWidgetService.pendingWidgetTogglesKey) ??
            <String>[];

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final eventId = '$nowMs:$taskId';
    final eventPayload = jsonEncode({
      'eventId': eventId,
      'taskId': taskId,
      'ts': nowMs,
    });

    pendingEvents.add(eventPayload);

    // Keep queue bounded in case the app is backgrounded for long periods.
    if (pendingEvents.length > 200) {
      pendingEvents.removeRange(0, pendingEvents.length - 200);
    }

    await prefs.setStringList(
      HomeWidgetService.pendingWidgetTogglesKey,
      pendingEvents,
    );

    await prefs.setInt(
      HomeWidgetService.lastWidgetToggleAtKey,
      nowMs,
    );

    // Optimistically update the widget UI immediately so it feels instant
    try {
      await HomeWidget.setAppGroupId(HomeWidgetService._appGroupId);
      final tasksJsonString =
          await HomeWidget.getWidgetData<String>(HomeWidgetService._keyTasks);
      if (tasksJsonString != null) {
        final List<dynamic> decoded = jsonDecode(tasksJsonString);
        bool changed = false;
        for (var task in decoded) {
          if (task['id'] == taskId) {
            task['completed'] = !(task['completed'] as bool);
            changed = true;
            break;
          }
        }
        if (changed) {
          await HomeWidget.saveWidgetData<String>(
              HomeWidgetService._keyTasks, jsonEncode(decoded));
          await HomeWidget.updateWidget(
            androidName: HomeWidgetService._androidWidgetName,
            qualifiedAndroidName:
                'com.android.krama.${HomeWidgetService._androidWidgetName}',
          );
        }
      }
    } catch (e) {
      debugPrint('Optimistic widget UI update failed: $e');
    }

    debugPrint('✅ Background widget toggle queued for task: $taskId');
  } catch (e, stackTrace) {
    debugPrint('❌ Background widget toggle failed: $e');
    debugPrint('📍 Stack trace: $stackTrace');
  }
}