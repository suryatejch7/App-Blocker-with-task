import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
// import '../services/restriction_service.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  // Will be used for updating restrictions based on task state
  // final RestrictionService _restrictionService = RestrictionService();

  List<Task> get tasks => _tasks;

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

  TaskProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('tasks');
    if (s != null) {
      final List decoded = jsonDecode(s);
      _tasks = decoded
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
      _updateRestrictions();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'tasks', jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  Future<void> _updateRestrictions() async {
    // Notify native side about restriction changes
    notifyListeners();
  }

  void addTask(Task t) {
    _tasks.add(t);
    _save();
    _updateRestrictions();
  }

  void updateTask(Task t) {
    final i = _tasks.indexWhere((x) => x.id == t.id);
    if (i != -1) {
      _tasks[i] = t;
      _save();
      _updateRestrictions();
    }
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _save();
    _updateRestrictions();
  }

  void toggleComplete(String id) {
    final i = _tasks.indexWhere((x) => x.id == id);
    if (i != -1) {
      _tasks[i].completed = !_tasks[i].completed;
      if (_tasks[i].completed) {
        _tasks[i].completedAt = DateTime.now();
      } else {
        _tasks[i].completedAt = null;
      }
      _save();
      _updateRestrictions();
    }
  }

  Future<void> performMidnightReset() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _tasks.removeWhere((task) {
      final taskDate = DateTime(
          task.startTime.year, task.startTime.month, task.startTime.day);
      return task.completed && taskDate.isBefore(today);
    });

    await _save();
    _updateRestrictions();
  }
}
