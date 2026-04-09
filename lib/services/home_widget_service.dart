import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
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

  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  /// Initialize the home widget service
  Future<void> initialize() async {
    try {
      // Set app group ID for data sharing (required for iOS, good practice for Android)
      await HomeWidget.setAppGroupId(_appGroupId);

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
      // Filter to today's tasks and sort by start time
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayTasks = tasks.where((task) {
        final taskDate = DateTime(
          task.startTime.year,
          task.startTime.month,
          task.startTime.day,
        );
        // Include today's tasks and overdue incomplete tasks
        return taskDate.isAtSameMomentAs(today) ||
            (taskDate.isBefore(today) && !task.completed);
      }).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      // Serialize tasks for widget
      final tasksJson = todayTasks
          .map((task) => <String, dynamic>{
                'id': task.id,
                'title': task.title,
                'description': task.description,
                'startTime': _formatTime(task.startTime),
                'endTime': _formatTime(task.endTime),
                'completed': task.completed,
                'isOverdue': task.isOverdue,
                'isActive': task.isActive,
              })
          .toList();

      // Save data to shared preferences for widget access
      await HomeWidget.saveWidgetData<String>(
        _keyTasks,
        jsonEncode(tasksJson),
      );

      await HomeWidget.saveWidgetData<int>(
        _keyTaskCount,
        todayTasks.length,
      );

      // Save next upcoming task info for small widget
      final nextTask = _getNextUpcomingTask(todayTasks);
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

      // Trigger widget update
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'com.android.krama.$_androidWidgetName',
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

  if (uri != null) {
    // Handle different widget actions
    final action = uri.host;
    final taskId = uri.queryParameters['taskId'];

    debugPrint('🔔 Widget action: $action, taskId: $taskId');

    // Actions are handled when app opens via getWidgetClickUri()
  }
}
