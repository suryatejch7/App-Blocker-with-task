import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/supabase_service.dart';
import '../services/restriction_service.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  final _supabaseService = SupabaseService();
  final _restrictionService = RestrictionService();
  Timer? _midnightTimer;
  bool _isLoading = false;

  // Store current default restrictions for syncing
  List<String> _defaultRestrictedApps = [];
  List<String> _defaultRestrictedWebsites = [];

  // Store permanently blocked apps/websites (always active)
  List<String> _permanentlyBlockedApps = [];
  List<String> _permanentlyBlockedWebsites = [];

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

  /// Trigger a re-sync after task changes
  Future<void> _resync() async {
    await syncRestrictions(
      _defaultRestrictedApps,
      _defaultRestrictedWebsites,
      _permanentlyBlockedApps,
      _permanentlyBlockedWebsites,
    );
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
    debugPrint(
        '🔄 TaskProvider.syncRestrictions - ========== SYNCING RESTRICTIONS ==========');

    // Store the restrictions
    _defaultRestrictedApps = defaultRestrictedApps;
    _defaultRestrictedWebsites = defaultRestrictedWebsites;
    _permanentlyBlockedApps = permanentlyBlockedApps;
    _permanentlyBlockedWebsites = permanentlyBlockedWebsites;

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
      if (task.restrictionMode == 'default') {
        appsToRestrict.addAll(defaultRestrictedApps);
        websitesToRestrict.addAll(defaultRestrictedWebsites);
        debugPrint('   -> Using default restrictions');
      } else if (task.restrictionMode == 'custom') {
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

    // Restrictions are active if there are active tasks OR permanent blocks exist
    final shouldBeActive = shouldRestrictionsBeActive ||
        permanentlyBlockedApps.isNotEmpty ||
        permanentlyBlockedWebsites.isNotEmpty;
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

    try {
      debugPrint('📡 Sending to native Android service...');
      await _restrictionService.updateRestrictions(
        appsToRestrict.toList(),
        websitesToRestrict.toList(),
        shouldBeActive,
        pendingTasks: pendingTasksInfo,
        permanentlyBlockedApps: permanentlyBlockedApps,
        permanentlyBlockedWebsites: permanentlyBlockedWebsites,
      );
      debugPrint(
          '✅ TaskProvider.syncRestrictions - Successfully synced to native!');
      debugPrint('✅ ========== SYNC COMPLETE ==========');
    } catch (e, stackTrace) {
      debugPrint(
          '❌ TaskProvider.syncRestrictions - Error syncing to native: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    }
  }

  TaskProvider() {
    _load();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    debugPrint(
        '🟢 TaskProvider._load - Starting to load tasks from Supabase...');
    _isLoading = true;
    notifyListeners();

    try {
      final tasksData = await _supabaseService.getTasks();
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
        debugPrint('📋 No tasks in database');
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

  void addTask(Task t) async {
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

      debugPrint('🟢 Calling SupabaseService.insertTask...');
      await _supabaseService.insertTask(jsonData);
      debugPrint(
          '✅ TaskProvider.addTask - Task saved to Supabase successfully!');

      // Sync restrictions to native service
      await _resync();

      debugPrint('✅ ========== TASK ADD COMPLETE ==========');
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ TaskProvider.addTask - ERROR SAVING TO SUPABASE ❌❌❌');
      debugPrint('❌ Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _tasks.removeWhere((task) => task.id == t.id);
      notifyListeners();
      debugPrint(
          '❌ Task rolled back from local list, count now: ${_tasks.length}');
      rethrow;
    }
  }

  void updateTask(Task t) async {
    debugPrint(
        '🟢 TaskProvider.updateTask - Updating task: ${t.title} (${t.id})');
    final i = _tasks.indexWhere((x) => x.id == t.id);
    if (i != -1) {
      final oldTask = _tasks[i];
      _tasks[i] = t;
      notifyListeners();
      debugPrint('🟢 Task updated in local list');

      try {
        await _supabaseService.updateTask(t.id, t.toJson());
        debugPrint('✅ TaskProvider.updateTask - Task updated in Supabase');

        // Sync restrictions to native service
        await _resync();
      } catch (e, stackTrace) {
        debugPrint('❌ TaskProvider.updateTask - Error: $e');
        debugPrint('📍 Stack trace: $stackTrace');
        // Rollback on error
        _tasks[i] = oldTask;
        notifyListeners();
        debugPrint('❌ Task update rolled back');
        rethrow;
      }
    } else {
      debugPrint(
          '⚠️ TaskProvider.updateTask - Task not found in list: ${t.id}');
    }
  }

  void removeTask(String id) async {
    debugPrint('🟢 TaskProvider.removeTask - Removing task ID: $id');
    final removedTask = _tasks.firstWhere((t) => t.id == id);
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    debugPrint('🟢 Task removed from local list, count: ${_tasks.length}');

    try {
      await _supabaseService.deleteTask(id);
      debugPrint('✅ TaskProvider.removeTask - Task deleted from Supabase');

      // Sync restrictions to native service
      await _resync();
    } catch (e, stackTrace) {
      debugPrint('❌ TaskProvider.removeTask - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _tasks.add(removedTask);
      notifyListeners();
      debugPrint('❌ Task deletion rolled back, count: ${_tasks.length}');
      rethrow;
    }
  }

  void toggleComplete(String id) async {
    debugPrint('🟢 TaskProvider.toggleComplete - Toggling task ID: $id');
    final i = _tasks.indexWhere((x) => x.id == id);
    if (i != -1) {
      final wasCompleted = _tasks[i].completed;
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
        await _supabaseService.updateTask(_tasks[i].id, _tasks[i].toJson());
        debugPrint('✅ TaskProvider.toggleComplete - Saved to Supabase');

        // Sync restrictions to native service
        await _resync();
      } catch (e, stackTrace) {
        debugPrint('❌ TaskProvider.toggleComplete - Error: $e');
        debugPrint('📍 Stack trace: $stackTrace');
        // Rollback on error
        _tasks[i].completed = wasCompleted;
        _tasks[i].completedAt = wasCompleted ? _tasks[i].completedAt : null;
        notifyListeners();
        debugPrint('❌ Toggle rolled back');
        rethrow;
      }
    } else {
      debugPrint('⚠️ TaskProvider.toggleComplete - Task not found: $id');
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
        await _supabaseService.archiveCompletedTask(task.toJson());
        await _supabaseService.deleteTask(task.id);
      } catch (e, stackTrace) {
        debugPrint('❌ Error archiving task ${task.id}: $e');
        debugPrint('📍 Stack trace: $stackTrace');
      }
    }

    // Remove from local list
    _tasks.removeWhere((task) => completedYesterday.contains(task));
    notifyListeners();
  }
}
