import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_keys.dart';
import '../models/task.dart';

/// Service for managing Android home screen widget data synchronization.
///
/// This service handles:
/// - Serializing task data for the native widget
/// - Updating widget when tasks change
/// - Handling widget tap interactions
class HomeWidgetService {
  // Expose queue keys to other layers (TaskProvider consumes these).
  static const String lastWidgetToggleAtKey = PrefsKeys.lastWidgetToggleAtMs;
  static const String pendingWidgetTogglesKey = PrefsKeys.pendingWidgetToggles;

  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  /// Initialize the home widget service
  Future<void> initialize() async {
    try {
      // Set app group ID for data sharing (required for iOS, good practice for Android)
      await HomeWidget.setAppGroupId(WidgetKeys.appGroupId);

      // Register callback for widget interactions
      HomeWidget.registerInteractivityCallback(backgroundCallback);

      debugPrint('✅ HomeWidgetService initialized');
    } catch (e) {
      debugPrint('❌ HomeWidgetService initialization error: $e');
    }
  }

  /// Update widget with current task list
  /// Call this whenever tasks are added, updated, or removed
  Future<bool> updateWidgetWithTasks(List<Task> tasks) async {
    try {
      await HomeWidget.setAppGroupId(WidgetKeys.appGroupId);
      final isDarkMode = await _readIsDarkTheme();

      // Filter strictly to today's tasks and sort by deadline
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayTasks = tasks.where((task) {
        final taskDate = DateTime(
          task.startTime.year,
          task.startTime.month,
          task.startTime.day,
        );
        return taskDate.isAtSameMomentAs(today);
      }).toList()
        ..sort((a, b) => a.endTime.compareTo(b.endTime));

      // Serialize tasks for widget
      final tasksJson = todayTasks
          .map((task) => <String, dynamic>{
                'id': task.id,
                'title': task.title,
                'description': task.description,
                'startTime': _formatTime(task.startTime),
                'endTime': _formatTime(task.endTime),
                'deadlineText': _formatTime(task.endTime),
                'completed': task.completed,
                'isOverdue': task.isOverdue,
                'isActive': task.isActive,
              })
          .toList();

      // Save data to shared preferences for widget access
      await HomeWidget.saveWidgetData<String>(
        WidgetKeys.tasksData,
        jsonEncode(tasksJson),
      );

      await HomeWidget.saveWidgetData<int>(
        WidgetKeys.taskCount,
        todayTasks.length,
      );

      // Save next upcoming task info for small widget
      final nextTask = _getNextUpcomingTask(todayTasks);
      if (nextTask != null) {
        await HomeWidget.saveWidgetData<String>(
          WidgetKeys.nextTask,
          jsonEncode({
            'id': nextTask.id,
            'title': nextTask.title,
            'startTime': _formatTime(nextTask.startTime),
            'endTime': _formatTime(nextTask.endTime),
            'isOverdue': nextTask.isOverdue,
          }),
        );
      } else {
        await HomeWidget.saveWidgetData<String>(WidgetKeys.nextTask, '');
      }

      await HomeWidget.saveWidgetData<String>(
        WidgetKeys.lastUpdate,
        DateTime.now().toIso8601String(),
      );

      await HomeWidget.saveWidgetData<bool>(WidgetKeys.widgetIsDark, isDarkMode);

      // Trigger widget update
      await HomeWidget.updateWidget(
        androidName: WidgetKeys.androidWidgetName,
        qualifiedAndroidName: 'com.android.krama.${WidgetKeys.androidWidgetName}',
      );

      debugPrint(
          '✅ HomeWidgetService: Widget updated with ${todayTasks.length} tasks');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ HomeWidgetService: Error updating widget: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Update only the widget theme without changing task data.
  Future<bool> updateWidgetTheme(bool isDarkMode) async {
    try {
      await HomeWidget.setAppGroupId(WidgetKeys.appGroupId);
      await HomeWidget.saveWidgetData<bool>(WidgetKeys.widgetIsDark, isDarkMode);
      await HomeWidget.updateWidget(
        androidName: WidgetKeys.androidWidgetName,
        qualifiedAndroidName: 'com.android.krama.${WidgetKeys.androidWidgetName}',
      );
      debugPrint(
          '✅ HomeWidgetService: Widget theme updated (dark=$isDarkMode)');
      return true;
    } catch (e) {
      debugPrint('❌ HomeWidgetService: Error updating widget theme: $e');
      return false;
    }
  }

  /// Get the next upcoming (not completed, not started yet or currently active) task
  Task? _getNextUpcomingTask(List<Task> tasks) {
    final now = DateTime.now();

    // First, look for overdue tasks
    final overdueTasks =
        tasks.where((t) => t.isOverdue && !t.completed).toList();
    if (overdueTasks.isNotEmpty) {
      return overdueTasks.first;
    }

    // Then, look for currently active tasks
    final activeTasks = tasks.where((t) => t.isActive && !t.completed).toList();
    if (activeTasks.isNotEmpty) {
      return activeTasks.first;
    }

    // Finally, look for upcoming tasks
    final upcomingTasks =
        tasks.where((t) => !t.completed && t.startTime.isAfter(now)).toList();
    if (upcomingTasks.isNotEmpty) {
      return upcomingTasks.first;
    }

    return null;
  }

  /// Format time for display in widget
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
      return prefs.getBool(PrefsKeys.themeMode) ?? false;
    } catch (e) {
      debugPrint('⚠️ HomeWidgetService: Unable to read theme preference: $e');
      return false;
    }
  }

  /// Clear all widget data
  Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData<String>(WidgetKeys.tasksData, '[]');
      await HomeWidget.saveWidgetData<int>(WidgetKeys.taskCount, 0);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.nextTask, '');
      await HomeWidget.updateWidget(
        androidName: WidgetKeys.androidWidgetName,
        qualifiedAndroidName: 'com.android.krama.${WidgetKeys.androidWidgetName}',
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

    // CRITICAL: Reload to clear memory cache, otherwise it will revive already processed events
    // that the foreground isolate deleted, leading to stale events toggling tasks backward!
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
      await HomeWidget.setAppGroupId(WidgetKeys.appGroupId);
      final tasksJsonString =
          await HomeWidget.getWidgetData<String>(WidgetKeys.tasksData);
      if (tasksJsonString != null) {
        final decoded = jsonDecode(tasksJsonString);
        if (decoded is! List) {
          throw const FormatException('Widget tasks payload is not a list');
        }
        bool changed = false;
        for (final item in decoded) {
          if (item is! Map) continue;
          if (item['id'] == taskId) {
            final currentCompleted = item['completed'];
            item['completed'] = currentCompleted is bool ? !currentCompleted : true;
            changed = true;
            break;
          }
        }
        if (changed) {
          await HomeWidget.saveWidgetData<String>(
              WidgetKeys.tasksData, jsonEncode(decoded));
          await HomeWidget.updateWidget(
            androidName: WidgetKeys.androidWidgetName,
            qualifiedAndroidName:
                'com.android.krama.${WidgetKeys.androidWidgetName}',
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
