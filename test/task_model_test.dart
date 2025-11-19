import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker_flutter/models/task.dart';
import 'package:habit_tracker_flutter/services/supabase_service.dart';

void main() {
  group('Task Model Tests', () {
    test('Task toJson should use snake_case for Supabase', () {
      final task = Task(
        id: 'test-123',
        title: 'Test Task',
        description: 'Test Description',
        startTime: DateTime(2025, 11, 19, 10, 0),
        endTime: DateTime(2025, 11, 19, 12, 0),
        completed: false,
        repeatSettings: 'daily',
        restrictionMode: 'default',
        customRestrictedApps: ['com.example.app'],
        customRestrictedWebsites: ['example.com'],
      );

      final json = task.toJson();

      expect(json['id'], 'test-123');
      expect(json['title'], 'Test Task');
      expect(json['description'], 'Test Description');
      expect(json['start_time'], isNotNull);
      expect(json['end_time'], isNotNull);
      expect(json['completed'], false);
      expect(json['repeat_settings'], 'daily');
      expect(json['restriction_mode'], 'default');
      expect(json['custom_restricted_apps'], ['com.example.app']);
      expect(json['custom_restricted_websites'], ['example.com']);

      // Should NOT have camelCase keys
      expect(json.containsKey('startTime'), false);
      expect(json.containsKey('endTime'), false);
      expect(json.containsKey('repeatSettings'), false);
    });

    test('Task fromJson should handle snake_case from Supabase', () {
      final json = {
        'id': 'test-456',
        'title': 'Another Task',
        'description': 'Another Description',
        'start_time': '2025-11-19T14:00:00.000Z',
        'end_time': '2025-11-19T16:00:00.000Z',
        'completed': true,
        'repeat_settings': 'weekly',
        'restriction_mode': 'custom',
        'custom_restricted_apps': ['com.test.app'],
        'custom_restricted_websites': ['test.com'],
        'completed_at': '2025-11-19T15:30:00.000Z',
      };

      final task = Task.fromJson(json);

      expect(task.id, 'test-456');
      expect(task.title, 'Another Task');
      expect(task.description, 'Another Description');
      expect(task.startTime.year, 2025);
      expect(task.endTime.year, 2025);
      expect(task.completed, true);
      expect(task.repeatSettings, 'weekly');
      expect(task.restrictionMode, 'custom');
      expect(task.customRestrictedApps, ['com.test.app']);
      expect(task.customRestrictedWebsites, ['test.com']);
      expect(task.completedAt, isNotNull);
    });

    test(
        'Task fromJson should handle legacy camelCase for backwards compatibility',
        () {
      final json = {
        'id': 'test-789',
        'title': 'Legacy Task',
        'startTime': '2025-11-19T10:00:00.000Z',
        'endTime': '2025-11-19T12:00:00.000Z',
        'completed': false,
        'repeatSettings': 'none',
        'restrictionMode': 'default',
        'customRestrictedApps': [],
        'customRestrictedWebsites': [],
      };

      final task = Task.fromJson(json);

      expect(task.id, 'test-789');
      expect(task.title, 'Legacy Task');
      expect(task.startTime.year, 2025);
      expect(task.endTime.year, 2025);
    });

    test('Task isOverdue should detect overdue tasks', () {
      final overdueTask = Task(
        id: 'overdue-1',
        title: 'Overdue Task',
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        completed: false,
      );

      expect(overdueTask.isOverdue, true);
    });

    test('Task isActive should detect active tasks', () {
      final activeTask = Task(
        id: 'active-1',
        title: 'Active Task',
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        endTime: DateTime.now().add(const Duration(minutes: 30)),
        completed: false,
      );

      expect(activeTask.isActive, true);
    });

    test('Completed task should not be overdue', () {
      final completedTask = Task(
        id: 'completed-1',
        title: 'Completed Task',
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        completed: true,
      );

      expect(completedTask.isOverdue, false);
    });
  });

  group('Supabase Service Tests', () {
    test('SupabaseService should be singleton', () {
      final service1 = SupabaseService();
      final service2 = SupabaseService();

      expect(identical(service1, service2), true);
    });

    test('Supabase URL and key should be configured', () {
      expect(SupabaseService.supabaseUrl,
          'https://cwupmrfxwdqagvhyqnen.supabase.co');
      expect(SupabaseService.supabaseAnonKey, isNotEmpty);
      expect(SupabaseService.supabaseAnonKey.startsWith('eyJ'), true);
    });
  });

  group('Task Integration Tests', () {
    test('Task roundtrip: toJson -> fromJson should preserve data', () {
      final originalTask = Task(
        id: 'roundtrip-123',
        title: 'Roundtrip Test',
        description: 'Testing serialization',
        startTime: DateTime(2025, 11, 20, 9, 0),
        endTime: DateTime(2025, 11, 20, 11, 0),
        completed: false,
        repeatSettings: 'daily',
        restrictionMode: 'custom',
        customRestrictedApps: ['com.facebook.katana', 'com.instagram.android'],
        customRestrictedWebsites: ['youtube.com', 'twitter.com'],
        completedAt: null,
      );

      final json = originalTask.toJson();
      final reconstructedTask = Task.fromJson(json);

      expect(reconstructedTask.id, originalTask.id);
      expect(reconstructedTask.title, originalTask.title);
      expect(reconstructedTask.description, originalTask.description);
      expect(reconstructedTask.startTime.toIso8601String(),
          originalTask.startTime.toIso8601String());
      expect(reconstructedTask.endTime.toIso8601String(),
          originalTask.endTime.toIso8601String());
      expect(reconstructedTask.completed, originalTask.completed);
      expect(reconstructedTask.repeatSettings, originalTask.repeatSettings);
      expect(reconstructedTask.restrictionMode, originalTask.restrictionMode);
      expect(reconstructedTask.customRestrictedApps,
          originalTask.customRestrictedApps);
      expect(reconstructedTask.customRestrictedWebsites,
          originalTask.customRestrictedWebsites);
    });

    test('Empty arrays should serialize correctly', () {
      final task = Task(
        id: 'empty-arrays',
        title: 'Empty Arrays Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        customRestrictedApps: [],
        customRestrictedWebsites: [],
      );

      final json = task.toJson();

      expect(json['custom_restricted_apps'], isEmpty);
      expect(json['custom_restricted_websites'], isEmpty);

      final reconstructed = Task.fromJson(json);
      expect(reconstructed.customRestrictedApps, isEmpty);
      expect(reconstructed.customRestrictedWebsites, isEmpty);
    });
  });
}
