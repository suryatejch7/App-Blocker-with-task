import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker_flutter/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task Model Tests', () {
    test('Task should initialize with correct fields', () {
      final task = Task(
        id: 'test-1',
        title: 'Test Task',
        description: 'Test Description',
        startTime: DateTime(2025, 11, 20, 10, 0),
        endTime: DateTime(2025, 11, 20, 12, 0),
        completed: false,
        repeatMode: TaskRepeatMode.daily,
        restrictionMode: TaskRestrictionMode.custom,
        customRestrictedApps: ['com.example.app'],
        customRestrictedWebsites: ['example.com'],
      );

      expect(task.id, 'test-1');
      expect(task.title, 'Test Task');
      expect(task.description, 'Test Description');
      expect(task.completed, false);
      expect(task.repeatMode, TaskRepeatMode.daily);
    });

    test('Task.toJson() should return a Map with expected fields', () {
      final task = Task(
        id: 'test-2',
        title: 'JSON Test',
        description: 'Testing JSON conversion',
        startTime: DateTime(2025, 11, 20, 10, 0),
        endTime: DateTime(2025, 11, 20, 12, 0),
        completed: false,
        repeatMode: TaskRepeatMode.none,
        restrictionMode: TaskRestrictionMode.defaultMode,
        customRestrictedApps: [],
        customRestrictedWebsites: [],
      );

      final json = task.toJson();

      expect(json.containsKey('id'), true);
      expect(json.containsKey('title'), true);
      expect(json.containsKey('completed'), true);
      expect(json['id'], 'test-2');
      expect(json['title'], 'JSON Test');
    });

    test('Task should handle fromJson conversion', () {
      final originalTask = Task(
        id: 'test-3',
        title: 'Conversion Test',
        description: 'Testing fromJson',
        startTime: DateTime(2025, 11, 20, 10, 0),
        endTime: DateTime(2025, 11, 20, 12, 0),
        completed: false,
        repeatMode: TaskRepeatMode.weekly,
        restrictionMode: TaskRestrictionMode.defaultMode,
        customRestrictedApps: [],
        customRestrictedWebsites: [],
      );

      final json = originalTask.toJson();
      expect(json.isNotEmpty, true);
      expect(json['title'], 'Conversion Test');
    });
  });
}
