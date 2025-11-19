import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker_flutter/services/supabase_service.dart';
import 'package:habit_tracker_flutter/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseService - Configuration Tests', () {
    test('SupabaseService should be a singleton', () {
      final service1 = SupabaseService();
      final service2 = SupabaseService();

      expect(identical(service1, service2), true,
          reason: 'SupabaseService should return the same instance');
    });

    test('Supabase URL should be correctly configured', () {
      expect(SupabaseService.supabaseUrl,
          'https://cwupmrfxwdqagvhyqnen.supabase.co');
      expect(SupabaseService.supabaseUrl.startsWith('https://'), true);
      expect(SupabaseService.supabaseUrl.contains('supabase.co'), true);
    });

    test('Supabase anon key should be configured and valid JWT format', () {
      expect(SupabaseService.supabaseAnonKey, isNotEmpty);
      expect(SupabaseService.supabaseAnonKey.startsWith('eyJ'), true,
          reason: 'JWT token should start with eyJ');
      expect(SupabaseService.supabaseAnonKey.split('.').length, 3,
          reason: 'JWT should have 3 parts separated by dots');
    });

    test('Supabase URL should not have trailing slash', () {
      expect(SupabaseService.supabaseUrl.endsWith('/'), false);
    });

    test('Supabase URL should be a valid URL', () {
      final uri = Uri.tryParse(SupabaseService.supabaseUrl);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, isNotEmpty);
    });
  });

  group('SupabaseService - Task JSON Tests', () {
    test('Task JSON should have snake_case fields for Supabase', () {
      final task = Task(
        id: 'json-test-1',
        title: 'JSON Test Task',
        description: 'Testing JSON serialization',
        startTime: DateTime(2025, 11, 20, 10, 0),
        endTime: DateTime(2025, 11, 20, 12, 0),
        completed: false,
        repeatSettings: 'daily',
        restrictionMode: 'custom',
        customRestrictedApps: ['com.facebook.katana'],
        customRestrictedWebsites: ['youtube.com'],
      );

      final json = task.toJson();

      // Verify snake_case fields
      expect(json.containsKey('start_time'), true,
          reason: 'Should have start_time (snake_case)');
      expect(json.containsKey('end_time'), true,
          reason: 'Should have end_time (snake_case)');
      expect(json.containsKey('repeat_settings'), true,
          reason: 'Should have repeat_settings (snake_case)');
      expect(json.containsKey('restriction_mode'), true,
          reason: 'Should have restriction_mode (snake_case)');
      expect(json.containsKey('custom_restricted_apps'), true,
          reason: 'Should have custom_restricted_apps (snake_case)');
      expect(json.containsKey('custom_restricted_websites'), true,
          reason: 'Should have custom_restricted_websites (snake_case)');

      // Should NOT have camelCase fields
      expect(json.containsKey('startTime'), false,
          reason: 'Should NOT have startTime (camelCase)');
      expect(json.containsKey('endTime'), false,
          reason: 'Should NOT have endTime (camelCase)');
      expect(json.containsKey('repeatSettings'), false,
          reason: 'Should NOT have repeatSettings (camelCase)');
      expect(json.containsKey('restrictionMode'), false,
          reason: 'Should NOT have restrictionMode (camelCase)');
    });

    test('Task JSON values should be correctly formatted', () {
      final startTime = DateTime(2025, 11, 20, 10, 0);
      final endTime = DateTime(2025, 11, 20, 12, 0);

      final task = Task(
        id: 'json-test-2',
        title: 'Value Test Task',
        startTime: startTime,
        endTime: endTime,
        completed: false,
        repeatSettings: 'weekly',
        restrictionMode: 'default',
      );

      final json = task.toJson();

      expect(json['id'], 'json-test-2');
      expect(json['title'], 'Value Test Task');
      expect(json['start_time'], isA<String>());
      expect(json['end_time'], isA<String>());
      expect(json['completed'], false);
      expect(json['repeat_settings'], 'weekly');
      expect(json['restriction_mode'], 'default');
    });

    test('Task JSON should handle null values correctly', () {
      final task = Task(
        id: 'json-test-3',
        title: 'Null Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        description: null,
        completedAt: null,
      );

      final json = task.toJson();

      expect(json['description'], isNull);
      expect(json['completed_at'], isNull);
    });

    test('Task JSON should handle empty arrays correctly', () {
      final task = Task(
        id: 'json-test-4',
        title: 'Empty Arrays Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        customRestrictedApps: [],
        customRestrictedWebsites: [],
      );

      final json = task.toJson();

      expect(json['custom_restricted_apps'], isEmpty);
      expect(json['custom_restricted_apps'], isA<List>());
      expect(json['custom_restricted_websites'], isEmpty);
      expect(json['custom_restricted_websites'], isA<List>());
    });

    test('Task fromJson should parse snake_case correctly', () {
      final json = {
        'id': 'parse-test-1',
        'title': 'Parse Test',
        'description': 'Testing parsing',
        'start_time': '2025-11-20T10:00:00.000Z',
        'end_time': '2025-11-20T12:00:00.000Z',
        'completed': false,
        'repeat_settings': 'daily',
        'restriction_mode': 'custom',
        'custom_restricted_apps': ['com.facebook.katana'],
        'custom_restricted_websites': ['youtube.com'],
        'completed_at': null,
      };

      final task = Task.fromJson(json);

      expect(task.id, 'parse-test-1');
      expect(task.title, 'Parse Test');
      expect(task.description, 'Testing parsing');
      expect(task.startTime, isA<DateTime>());
      expect(task.endTime, isA<DateTime>());
      expect(task.completed, false);
      expect(task.repeatSettings, 'daily');
      expect(task.restrictionMode, 'custom');
      expect(task.customRestrictedApps, ['com.facebook.katana']);
      expect(task.customRestrictedWebsites, ['youtube.com']);
    });

    test(
        'Task fromJson should handle legacy camelCase for backward compatibility',
        () {
      final json = {
        'id': 'parse-test-2',
        'title': 'Legacy Parse Test',
        'startTime': '2025-11-20T10:00:00.000Z',
        'endTime': '2025-11-20T12:00:00.000Z',
        'completed': false,
        'repeatSettings': 'none',
        'restrictionMode': 'default',
        'customRestrictedApps': [],
        'customRestrictedWebsites': [],
      };

      final task = Task.fromJson(json);

      expect(task.id, 'parse-test-2');
      expect(task.title, 'Legacy Parse Test');
      expect(task.startTime, isA<DateTime>());
      expect(task.endTime, isA<DateTime>());
    });
  });

  group('SupabaseService - Method Existence Tests', () {
    test('SupabaseService should have all required methods', () {
      final service = SupabaseService();

      expect(SupabaseService.initialize, isA<Function>());
      expect(service.getTasks, isA<Function>());
      expect(service.insertTask, isA<Function>());
      expect(service.updateTask, isA<Function>());
      expect(service.deleteTask, isA<Function>());
      expect(service.getDefaultRestrictedApps, isA<Function>());
      expect(service.getDefaultRestrictedWebsites, isA<Function>());
      expect(service.addDefaultRestriction, isA<Function>());
      expect(service.removeDefaultRestriction, isA<Function>());
      expect(service.archiveCompletedTask, isA<Function>());
    });
  });

  group('SupabaseService - Data Integrity Tests', () {
    test('Task serialization roundtrip should preserve all data', () {
      final originalTask = Task(
        id: 'roundtrip-1',
        title: 'Roundtrip Test',
        description: 'Testing full roundtrip',
        startTime: DateTime(2025, 11, 20, 10, 0),
        endTime: DateTime(2025, 11, 20, 12, 0),
        completed: false,
        repeatSettings: 'daily',
        restrictionMode: 'custom',
        customRestrictedApps: ['app1', 'app2', 'app3'],
        customRestrictedWebsites: ['site1.com', 'site2.com'],
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
      expect(reconstructedTask.completedAt, originalTask.completedAt);
    });

    test('Task with special characters should serialize correctly', () {
      final task = Task(
        id: 'special-1',
        title: 'Task with "quotes" and \'apostrophes\'',
        description: 'Description with\nnewlines\tand\ttabs',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        customRestrictedApps: ['com.app.with-dash', 'com.app_with_underscore'],
        customRestrictedWebsites: [
          'site-with-dash.com',
          'site_with_underscore.com'
        ],
      );

      final json = task.toJson();
      final reconstructed = Task.fromJson(json);

      expect(reconstructed.title, task.title);
      expect(reconstructed.description, task.description);
      expect(reconstructed.customRestrictedApps, task.customRestrictedApps);
      expect(reconstructed.customRestrictedWebsites,
          task.customRestrictedWebsites);
    });

    test('Task with unicode characters should serialize correctly', () {
      final task = Task(
        id: 'unicode-1',
        title: 'Task with émojis 🎯 and 中文',
        description: 'Description with émojis 🚀 🎉 and special chars ñ ü',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );

      final json = task.toJson();
      final reconstructed = Task.fromJson(json);

      expect(reconstructed.title, task.title);
      expect(reconstructed.description, task.description);
    });

    test('Task with very long arrays should serialize correctly', () {
      final manyApps = List.generate(50, (i) => 'com.app$i.package');
      final manyWebsites = List.generate(50, (i) => 'website$i.com');

      final task = Task(
        id: 'long-arrays-1',
        title: 'Long Arrays Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        customRestrictedApps: manyApps,
        customRestrictedWebsites: manyWebsites,
      );

      final json = task.toJson();
      final reconstructed = Task.fromJson(json);

      expect(reconstructed.customRestrictedApps.length, 50);
      expect(reconstructed.customRestrictedWebsites.length, 50);
      expect(reconstructed.customRestrictedApps[0], 'com.app0.package');
      expect(reconstructed.customRestrictedApps[49], 'com.app49.package');
    });
  });

  group('SupabaseService - Date and Time Tests', () {
    test('Task dates should serialize to ISO8601 format', () {
      final task = Task(
        id: 'date-test-1',
        title: 'Date Test',
        startTime: DateTime(2025, 11, 20, 10, 30, 45),
        endTime: DateTime(2025, 11, 20, 12, 30, 45),
      );

      final json = task.toJson();

      expect(json['start_time'], contains('2025-11-20'));
      expect(json['start_time'], contains('T'));
      expect(json['end_time'], contains('2025-11-20'));
    });

    test('Task dates should parse from ISO8601 format', () {
      final json = {
        'id': 'date-test-2',
        'title': 'Date Parse Test',
        'start_time': '2025-11-20T10:30:45.000Z',
        'end_time': '2025-11-20T12:30:45.000Z',
        'completed': false,
      };

      final task = Task.fromJson(json);

      expect(task.startTime.year, 2025);
      expect(task.startTime.month, 11);
      expect(task.startTime.day, 20);
      expect(task.startTime.hour, 10);
      expect(task.startTime.minute, 30);
      expect(task.startTime.second, 45);
    });

    test('Task completedAt should serialize correctly when set', () {
      final completedAt = DateTime(2025, 11, 20, 15, 30);

      final task = Task(
        id: 'completed-date-1',
        title: 'Completed Date Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        completed: true,
        completedAt: completedAt,
      );

      final json = task.toJson();

      expect(json['completed'], true);
      expect(json['completed_at'], isNotNull);
      expect(json['completed_at'], contains('2025-11-20'));
    });

    test('Task completedAt should be null when not completed', () {
      final task = Task(
        id: 'not-completed-1',
        title: 'Not Completed Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        completed: false,
      );

      final json = task.toJson();

      expect(json['completed'], false);
      expect(json['completed_at'], isNull);
    });
  });

  group('SupabaseService - Field Name Consistency Tests', () {
    test('All snake_case fields should be present in JSON', () {
      final task = Task(
        id: 'consistency-1',
        title: 'Consistency Test',
        description: 'Testing field names',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        completed: false,
        repeatSettings: 'daily',
        restrictionMode: 'custom',
        customRestrictedApps: ['app'],
        customRestrictedWebsites: ['site.com'],
        completedAt: null,
      );

      final json = task.toJson();

      final requiredSnakeCaseFields = [
        'id',
        'title',
        'start_time',
        'end_time',
        'completed',
        'repeat_settings',
        'restriction_mode',
        'custom_restricted_apps',
        'custom_restricted_websites',
      ];

      for (final field in requiredSnakeCaseFields) {
        expect(json.containsKey(field), true,
            reason: 'JSON should contain field: $field');
      }
    });

    test('No camelCase fields should be in JSON output', () {
      final task = Task(
        id: 'no-camel-1',
        title: 'No Camel Case Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        repeatSettings: 'daily',
        restrictionMode: 'custom',
        customRestrictedApps: ['app'],
        customRestrictedWebsites: ['site.com'],
      );

      final json = task.toJson();

      final forbiddenCamelCaseFields = [
        'startTime',
        'endTime',
        'repeatSettings',
        'restrictionMode',
        'customRestrictedApps',
        'customRestrictedWebsites',
        'completedAt',
      ];

      for (final field in forbiddenCamelCaseFields) {
        expect(json.containsKey(field), false,
            reason: 'JSON should NOT contain camelCase field: $field');
      }
    });
  });

  group('SupabaseService - Edge Case Tests', () {
    test('Task with minimum required fields should serialize', () {
      final task = Task(
        id: 'minimal-1',
        title: 'Minimal Task',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );

      final json = task.toJson();
      final reconstructed = Task.fromJson(json);

      expect(reconstructed.id, task.id);
      expect(reconstructed.title, task.title);
    });

    test('Task with all optional fields null should serialize', () {
      final task = Task(
        id: 'all-null-1',
        title: 'All Null Task',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        description: null,
        completedAt: null,
      );

      final json = task.toJson();

      expect(json['description'], isNull);
      expect(json['completed_at'], isNull);
    });

    test('Task with empty strings should be preserved', () {
      final task = Task(
        id: '',
        title: '',
        description: '',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );

      final json = task.toJson();
      final reconstructed = Task.fromJson(json);

      expect(reconstructed.id, '');
      expect(reconstructed.title, '');
      expect(reconstructed.description, '');
    });
  });
}
