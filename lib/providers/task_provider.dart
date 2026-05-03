import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/restriction_service.dart';
import '../services/home_widget_service.dart';
import '../services/offline_cache_service.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  final _offlineCacheService = OfflineCacheService();
  final _restrictionService = RestrictionService();
  final _homeWidgetService = HomeWidgetService();
  Timer? _midnightTimer;
  bool _isLoading = false;

  // Track pending operations to prevent race conditions
  final Set<String> _pendingOperations = {};

  // Store current default restrictions for syncing
  List<String> _defaultRestrictedApps = [];
  List<String> _defaultRestrictedWebsites = [];

  // Store permanently blocked apps/websites (always active)
  List<String> _permanentlyBlockedApps = [];
  List<String> _permanentlyBlockedWebsites = [];

  // Serialize native sync calls to avoid overlapping stale updates.
  bool _syncRestrictionsRunning = false;
  bool _syncRestrictionsQueued = false;
  String? _lastRestrictionsPayloadSignature;
  bool _tasksLoaded = false;
  bool _hasRestrictionSnapshot = false;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  List<Task> get todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _tasks.where((task) {
      final taskDate = DateTime(
          task.startTime.year, task.startTime.month, task.startTime.day);
      return taskDate.isAtSameMomentAs(today) ||
          (taskDate.isBefore(today) && !task.completed);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Map<DateTime, List<Task>> get futureTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final Map<DateTime, List<Task>> grouped = {};

    for (var task in _tasks) {
      final taskDate = DateTime(
          task.startTime.year, task.startTime.month, task.startTime.day);
      if (taskDate.isAfter(today)) {
        grouped.putIfAbsent(taskDate, () => []).add(task);
      }
    }

    grouped.forEach((date, taskList) {
      taskList.sort((a, b) => a.startTime.compareTo(b.startTime));
    });

    return Map.fromEntries(
        grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  List<Task> get overdueTasks => _tasks.where((t) => t.isOverdue).toList();

  bool get shouldRestrictionsBeActive {
    if (overdueTasks.isNotEmpty) return true;
    final activeTasks =
        _tasks.where((t) => t.isActive && !t.completed).toList();
    return activeTasks.isNotEmpty;
  }

  /// Trigger a re-sync after task changes (restrictions + widget)
  Future<void> _resync({bool updateWidget = true}) async {
    await syncRestrictions(
      _defaultRestrictedApps,
      _defaultRestrictedWebsites,
      _permanentlyBlockedApps,
      _permanentlyBlockedWebsites,
    );
    if (updateWidget) {
      // Update home screen widget
      await _updateHomeWidget();
    }
  }

  /// Update the home screen widget with current tasks
  Future<void> _updateHomeWidget() async {
    try {
      await _homeWidgetService.updateWidgetWithTasks(_tasks);
    } catch (e) {
      debugPrint('⚠️ TaskProvider: Failed to update home widget: $e');
    }
  }

  Future<void> syncHomeWidgetNow() async {
    await _updateHomeWidget();
  }

  Future<void> resyncNow({bool updateWidget = true}) async {
    await _resync(updateWidget: updateWidget);
  }

  /// Syncs current task restrictions to native Android service
  /// Call this whenever tasks change or default restrictions change
  /// Permanently blocked apps are ALWAYS blocked, regardless of tasks
  Future<void> syncRestrictions(
    List<String> defaultRestrictedApps,
    List<String> defaultRestrictedWebsites,
    List<String> permanentlyBlockedApps,
    List<String> permanentlyBlockedWebsites,
  ) async {
    // Always keep latest config snapshot.
    _defaultRestrictedApps = defaultRestrictedApps;
    _defaultRestrictedWebsites = defaultRestrictedWebsites;
    _permanentlyBlockedApps = permanentlyBlockedApps;
    _permanentlyBlockedWebsites = permanentlyBlockedWebsites;
    _hasRestrictionSnapshot = true;

    // Avoid pushing incomplete startup state before tasks are loaded.
    if (!_tasksLoaded) {
      debugPrint(
          '⏸️ TaskProvider.syncRestrictions - deferred until initial task load completes');
      return;
    }

    // Coalesce concurrent calls; process only latest state in a serialized loop.
    _syncRestrictionsQueued = true;
    if (_syncRestrictionsRunning) {
      return;
    }

    _syncRestrictionsRunning = true;
    try {
      while (_syncRestrictionsQueued) {
        _syncRestrictionsQueued = false;

        await _performSyncRestrictions(
          List<String>.from(_defaultRestrictedApps),
          List<String>.from(_defaultRestrictedWebsites),
          List<String>.from(_permanentlyBlockedApps),
          List<String>.from(_permanentlyBlockedWebsites),
        );
      }
    } finally {
      _syncRestrictionsRunning = false;
    }
  }

  Future<void> _performSyncRestrictions(
    List<String> defaultRestrictedApps,
    List<String> defaultRestrictedWebsites,
    List<String> permanentlyBlockedApps,
    List<String> permanentlyBlockedWebsites,
  ) async {
    debugPrint(
        '🔄 TaskProvider.syncRestrictions - ========== SYNCING RESTRICTIONS ==========');

    // Get all active or overdue tasks
    final relevantTasks = _tasks
        .where((t) => (t.isActive || t.isOverdue) && !t.completed)
        .toList();

    debugPrint('📋 Found ${relevantTasks.length} active/overdue tasks');

    // Collect all apps and websites to restrict
    final appsToRestrict = <String>{};
    final websitesToRestrict = <String>{};

    // ALWAYS add permanently blocked apps/websites first
    appsToRestrict.addAll(permanentlyBlockedApps);
    websitesToRestrict.addAll(permanentlyBlockedWebsites);
    debugPrint(
        '🔒 Added ${permanentlyBlockedApps.length} permanently blocked apps');
    debugPrint(
        '🔒 Added ${permanentlyBlockedWebsites.length} permanently blocked websites');

    // Add task-based restrictions
    for (var task in relevantTasks) {
      debugPrint('   Task: ${task.title} (mode: ${task.restrictionMode})');
      if (task.restrictionMode == TaskRestrictionMode.defaultMode) {
        appsToRestrict.addAll(defaultRestrictedApps);
        websitesToRestrict.addAll(defaultRestrictedWebsites);
        debugPrint('   -> Using default restrictions');
      } else if (task.restrictionMode == TaskRestrictionMode.custom) {
        appsToRestrict.addAll(task.customRestrictedApps);
        websitesToRestrict.addAll(task.customRestrictedWebsites);
        debugPrint(
            '   -> Using custom restrictions (${task.customRestrictedApps.length} apps, ${task.customRestrictedWebsites.length} websites)');
      }
    }

    debugPrint('📱 Total apps to restrict: ${appsToRestrict.length}');
    if (appsToRestrict.isNotEmpty) {
      debugPrint('   Apps: ${appsToRestrict.join(", ")}');
    }
    debugPrint('🌐 Total websites to restrict: ${websitesToRestrict.length}');
    if (websitesToRestrict.isNotEmpty) {
      debugPrint('   Websites: ${websitesToRestrict.join(", ")}');
    }

    // Activate native monitoring only when there is something to enforce.
    final shouldBeActive =
        appsToRestrict.isNotEmpty || websitesToRestrict.isNotEmpty;
    debugPrint('🔒 Restrictions should be active: $shouldBeActive');

    // Prepare pending tasks info for the blocking screen
    final pendingTasksInfo = relevantTasks
        .map((task) => {
              'id': task.id,
              'title': task.title,
              'description': task.description,
              'startTime': task.startTime.toIso8601String(),
              'endTime': task.endTime.toIso8601String(),
              'isOverdue': task.isOverdue,
            })
        .toList();

    final sortedApps = appsToRestrict.toList()..sort();
    final sortedWebsites = websitesToRestrict.toList()..sort();
    final sortedPendingTaskIds = relevantTasks.map((t) => t.id).toList()
      ..sort();

    final payloadSignature = jsonEncode({
      'apps': sortedApps,
      'websites': sortedWebsites,
      'active': shouldBeActive,
      'pendingTaskIds': sortedPendingTaskIds,
      'permanentApps': [...permanentlyBlockedApps]..sort(),
      'permanentWebsites': [...permanentlyBlockedWebsites]..sort(),
    });

    if (payloadSignature == _lastRestrictionsPayloadSignature) {
      debugPrint(
          '⏭️ TaskProvider.syncRestrictions - Skipping native sync (no effective change)');
      return;
    }

    try {
      debugPrint('📡 Sending to native Android service...');
      final nativeServiceConnected =
          await _restrictionService.updateRestrictions(
        sortedApps,
        sortedWebsites,
        shouldBeActive,
        pendingTasks: pendingTasksInfo,
        permanentlyBlockedApps: permanentlyBlockedApps,
        permanentlyBlockedWebsites: permanentlyBlockedWebsites,
      );
      _lastRestrictionsPayloadSignature = payloadSignature;
      if (nativeServiceConnected) {
        debugPrint(
            '✅ TaskProvider.syncRestrictions - Successfully synced to native!');
      } else {
        debugPrint(
            '⚠️ TaskProvider.syncRestrictions - Native service not connected; restrictions are queued in local prefs');
      }
      debugPrint('✅ ========== SYNC COMPLETE ==========');
    } catch (e, stackTrace) {
      debugPrint(
          '❌ TaskProvider.syncRestrictions - Error syncing to native: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    }
  }

  Timer? _widgetSyncTimer;

  TaskProvider() {
    _load().then((_) {
      _pollWidgetToggles();
      _widgetSyncTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _pollWidgetToggles(),
      );
    });
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _widgetSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollWidgetToggles() async {
    if (!_tasksLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final pendingEvents =
          prefs.getStringList(HomeWidgetService.pendingWidgetTogglesKey);
      if (pendingEvents != null && pendingEvents.isNotEmpty) {
        await prefs
            .setStringList(HomeWidgetService.pendingWidgetTogglesKey, []);

        bool requiresSync = false;
        for (final eventStr in pendingEvents) {
          try {
            final event = jsonDecode(eventStr);
            final taskId = event['taskId'] as String;
            final i = _tasks.indexWhere((x) => x.id == taskId);

            if (i != -1) {
              _tasks[i].completed = !_tasks[i].completed;
              if (_tasks[i].completed) {
                _tasks[i].completedAt = DateTime.now();
              } else {
                _tasks[i].completedAt = null;
              }
              await _offlineCacheService.upsertTask(_tasks[i].toJson());
              requiresSync = true;
            }
          } catch (_) {}
        }

        if (requiresSync) {
          notifyListeners();
          await _resync();
        }
      }
    } catch (e) {
      debugPrint('⚠️ TaskProvider: Error polling widget toggles: $e');
    }
  }

  Future<void> _load() async {
    debugPrint('🟢 TaskProvider._load - Loading local tasks...');
    _isLoading = true;
    notifyListeners();

    try {
      final wasLoaded = _tasksLoaded;
      if (!_offlineCacheService.isInitialized) {
        await _offlineCacheService.initialize();
      }

      final tasksData = _offlineCacheService.getCachedTasks();
      debugPrint(
          '🟢 TaskProvider._load - Received ${tasksData.length} raw task records');

      _tasks = tasksData
          .map((data) => Task.fromJson(Map<String, dynamic>.from(data)))
          .toList();

      debugPrint(
          '✅ TaskProvider._load - Successfully loaded ${_tasks.length} tasks');
      if (_tasks.isNotEmpty) {
        debugPrint('📋 Task titles: ${_tasks.map((t) => t.title).join(", ")}');
        debugPrint('📋 Task IDs: ${_tasks.map((t) => t.id).join(", ")}');
      } else {
        debugPrint('📋 No local tasks found');
      }
      // Update home screen widget after loading tasks
      await _updateHomeWidget();

      _tasksLoaded = true;

      // Run exactly one deferred initial restriction sync after first task load.
      if (!wasLoaded && _hasRestrictionSnapshot) {
        await syncRestrictions(
          _defaultRestrictedApps,
          _defaultRestrictedWebsites,
          _permanentlyBlockedApps,
          _permanentlyBlockedWebsites,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ TaskProvider._load - Error loading tasks: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint('🟢 TaskProvider._load - Load complete, isLoading=false');
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  /// Adds a new task with optimistic update and rollback on error.
  /// Returns true if successful, false if operation is already pending.
  Future<bool> addTask(Task t) async {
    // Prevent duplicate operations
    final operationKey = 'add_${t.id}';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ TaskProvider.addTask - Operation already pending for ${t.id}');
      return false;
    }
    _pendingOperations.add(operationKey);

    debugPrint(
        '🟢 TaskProvider.addTask - ========== ADDING NEW TASK ==========');
    debugPrint('🟢 Task title: ${t.title}');
    debugPrint('🟢 Task ID: ${t.id}');
    debugPrint('🟢 Start time: ${t.startTime}');
    debugPrint('🟢 End time: ${t.endTime}');

    _tasks.add(t);
    notifyListeners();
    debugPrint('🟢 Task added to local list, total count: ${_tasks.length}');

    try {
      final jsonData = t.toJson();
      debugPrint('🟢 Task JSON generated:');
      jsonData.forEach((key, value) {
        debugPrint('   $key: $value');
      });

      debugPrint('🟢 Saving task to local storage...');
      await _offlineCacheService.upsertTask(jsonData);
      debugPrint(
          '✅ TaskProvider.addTask - Task saved to local storage successfully!');

      // Sync restrictions to native service
      await _resync();

      debugPrint('✅ ========== TASK ADD COMPLETE ==========');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ TaskProvider.addTask - ERROR SAVING LOCALLY ❌❌❌');
      debugPrint('❌ Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _tasks.removeWhere((task) => task.id == t.id);
      notifyListeners();
      debugPrint(
          '❌ Task rolled back from local list, count now: ${_tasks.length}');
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  /// Updates an existing task with optimistic update and rollback on error.
  /// Returns true if successful, false if task not found or operation pending.
  Future<bool> updateTask(Task t) async {
    // Prevent duplicate operations
    final operationKey = 'update_${t.id}';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ TaskProvider.updateTask - Operation already pending for ${t.id}');
      return false;
    }

    debugPrint(
        '🟢 TaskProvider.updateTask - Updating task: ${t.title} (${t.id})');
    final i = _tasks.indexWhere((x) => x.id == t.id);
    if (i == -1) {
      debugPrint(
          '⚠️ TaskProvider.updateTask - Task not found in list: ${t.id}');
      return false;
    }

    _pendingOperations.add(operationKey);
    final oldTask = _tasks[i];
    _tasks[i] = t;
    notifyListeners();
    debugPrint('🟢 Task updated in local list');

    try {
      await _offlineCacheService.upsertTask(t.toJson());
      debugPrint('✅ TaskProvider.updateTask - Task updated in local storage');

      // Sync restrictions to native service
      await _resync();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ TaskProvider.updateTask - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _tasks[i] = oldTask;
      notifyListeners();
      debugPrint('❌ Task update rolled back');
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  /// Removes a task with optimistic update and rollback on error.
  /// Returns true if successful, false if task not found or operation pending.
  Future<bool> removeTask(String id) async {
    // Prevent duplicate operations
    final operationKey = 'remove_$id';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ TaskProvider.removeTask - Operation already pending for $id');
      return false;
    }

    debugPrint('🟢 TaskProvider.removeTask - Removing task ID: $id');
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex == -1) {
      debugPrint('⚠️ TaskProvider.removeTask - Task not found: $id');
      return false;
    }

    _pendingOperations.add(operationKey);
    final removedTask = _tasks[taskIndex];
    _tasks.removeAt(taskIndex);
    notifyListeners();
    debugPrint('🟢 Task removed from local list, count: ${_tasks.length}');

    try {
      await _offlineCacheService.removeCachedTask(id);
      debugPrint('✅ TaskProvider.removeTask - Task deleted from local storage');

      // Sync restrictions to native service
      await _resync();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ TaskProvider.removeTask - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _tasks.insert(taskIndex, removedTask);
      notifyListeners();
      debugPrint('❌ Task deletion rolled back, count: ${_tasks.length}');
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  /// Toggles task completion status with optimistic update and rollback on error.
  /// Returns true if successful, false if task not found or operation pending.
  Future<bool> toggleComplete(
    String id, {
    bool updateWidget = true,
    bool syncRestrictions = true,
  }) async {
    // Prevent duplicate operations (critical for double-tap prevention)
    final operationKey = 'toggle_$id';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ TaskProvider.toggleComplete - Operation already pending for $id');
      return false;
    }

    debugPrint('🟢 TaskProvider.toggleComplete - Toggling task ID: $id');
    final i = _tasks.indexWhere((x) => x.id == id);
    if (i == -1) {
      debugPrint('⚠️ TaskProvider.toggleComplete - Task not found: $id');
      return false;
    }

    _pendingOperations.add(operationKey);
    final wasCompleted = _tasks[i].completed;
    final previousCompletedAt = _tasks[i].completedAt;

    _tasks[i].completed = !_tasks[i].completed;
    if (_tasks[i].completed) {
      _tasks[i].completedAt = DateTime.now();
    } else {
      _tasks[i].completedAt = null;
    }
    debugPrint(
        '🟢 Task completion toggled: $wasCompleted -> ${_tasks[i].completed}');
    notifyListeners();

    try {
      await _offlineCacheService.upsertTask(_tasks[i].toJson());
      debugPrint('✅ TaskProvider.toggleComplete - Saved locally');

      // Sync restrictions/widget unless caller is performing a batched apply.
      if (syncRestrictions) {
        await _resync(updateWidget: updateWidget);
      } else if (updateWidget) {
        await _updateHomeWidget();
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ TaskProvider.toggleComplete - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error - restore exact previous state
      _tasks[i].completed = wasCompleted;
      _tasks[i].completedAt = previousCompletedAt;
      notifyListeners();
      debugPrint('❌ Toggle rolled back');
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  void _scheduleMidnightReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);

    _midnightTimer = Timer(duration, () {
      performMidnightReset();
      _scheduleMidnightReset(); // Reschedule for next day
    });
  }

  Future<void> performMidnightReset() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    // Archive completed tasks from yesterday
    final completedYesterday = _tasks.where((task) {
      if (!task.completed || task.completedAt == null) return false;
      final completedDate = DateTime(
        task.completedAt!.year,
        task.completedAt!.month,
        task.completedAt!.day,
      );
      return completedDate.isBefore(yesterday) ||
          completedDate.isAtSameMomentAs(yesterday);
    }).toList();

    for (var task in completedYesterday) {
      try {
        await _offlineCacheService.archiveTask(task.toJson());
        await _offlineCacheService.removeCachedTask(task.id);
      } catch (e, stackTrace) {
        debugPrint('❌ Error archiving task ${task.id}: $e');
        debugPrint('📍 Stack trace: $stackTrace');
      }
    }

    // Remove from local list
    _tasks.removeWhere((task) => completedYesterday.contains(task));
    notifyListeners();

    // Refresh restrictions and widget data after rolling over to a new day.
    await _resync();
  }
}
