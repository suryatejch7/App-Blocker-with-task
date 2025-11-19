import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker_flutter/services/supabase_service.dart';
import 'package:habit_tracker_flutter/models/task.dart';

/// This test actually connects to Supabase to debug the issue
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DEBUG: Real Supabase Connection Tests', () {
    setUpAll(() async {
      // Initialize Supabase with real credentials
      await SupabaseService.initialize();
      print('✅ Supabase initialized');
    });

    test('DEBUG: Test fetching existing tasks from Supabase', () async {
      final service = SupabaseService();

      print('\n🔍 Fetching tasks from Supabase...');
      final tasks = await service.getTasks();

      print('📊 Found ${tasks.length} tasks in database');
      for (var i = 0; i < tasks.length; i++) {
        print('  Task $i: ${tasks[i]}');
      }

      expect(tasks, isA<List>());
    });

    test('DEBUG: Test inserting a new task to Supabase', () async {
      final service = SupabaseService();

      final testTask = Task(
        id: 'debug-test-${DateTime.now().millisecondsSinceEpoch}',
        title: 'DEBUG Test Task',
        description: 'This is a debug test task',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        completed: false,
        repeatSettings: 'none',
        restrictionMode: 'default',
        customRestrictedApps: [],
        customRestrictedWebsites: [],
      );

      print('\n📝 Inserting test task...');
      print('Task JSON: ${testTask.toJson()}');

      try {
        await service.insertTask(testTask.toJson());
        print('✅ Task inserted successfully');

        // Verify it was inserted
        print('\n🔍 Fetching tasks again to verify...');
        final tasks = await service.getTasks();
        print('📊 Now have ${tasks.length} tasks in database');

        final inserted = tasks.any((t) => t['id'] == testTask.id);
        print(inserted
            ? '✅ Task found in database!'
            : '❌ Task NOT found in database');

        expect(inserted, true, reason: 'Task should be in database');

        // Clean up
        print('\n🧹 Cleaning up test task...');
        await service.deleteTask(testTask.id);
        print('✅ Test task deleted');
      } catch (e, stackTrace) {
        print('❌ ERROR inserting task: $e');
        print('Stack trace: $stackTrace');
        fail('Failed to insert task: $e');
      }
    });

    test('DEBUG: Test adding restriction to Supabase', () async {
      final service = SupabaseService();

      final testPackage =
          'com.debug.test.${DateTime.now().millisecondsSinceEpoch}';

      print('\n📝 Adding test app restriction...');
      print('Package name: $testPackage');

      try {
        await service.addDefaultRestriction('app', testPackage);
        print('✅ Restriction added successfully');

        // Verify it was added
        print('\n🔍 Fetching restrictions to verify...');
        final apps = await service.getDefaultRestrictedApps();
        print('📊 Found ${apps.length} restricted apps');

        final added = apps.contains(testPackage);
        print(added
            ? '✅ Restriction found in database!'
            : '❌ Restriction NOT found in database');

        expect(added, true, reason: 'Restriction should be in database');

        // Clean up
        print('\n🧹 Cleaning up test restriction...');
        await service.removeDefaultRestriction('app', testPackage);
        print('✅ Test restriction deleted');
      } catch (e, stackTrace) {
        print('❌ ERROR adding restriction: $e');
        print('Stack trace: $stackTrace');
        fail('Failed to add restriction: $e');
      }
    });

    test('DEBUG: Check database schema matches expectations', () async {
      final service = SupabaseService();

      print('\n🔍 Checking if we can query tasks table...');
      try {
        final tasks = await service.getTasks();
        print('✅ Tasks table accessible, found ${tasks.length} tasks');

        if (tasks.isNotEmpty) {
          print('\n📋 Sample task structure:');
          final sample = tasks.first;
          print('  Keys: ${sample.keys.toList()}');

          // Check for snake_case fields
          final requiredFields = [
            'id',
            'title',
            'start_time',
            'end_time',
            'completed',
            'repeat_settings',
            'restriction_mode',
            'custom_restricted_apps',
            'custom_restricted_websites'
          ];

          for (var field in requiredFields) {
            if (sample.containsKey(field)) {
              print('  ✅ $field: ${sample[field]}');
            } else {
              print('  ❌ MISSING: $field');
            }
          }
        }
      } catch (e) {
        print('❌ ERROR accessing tasks table: $e');
        fail('Cannot access tasks table: $e');
      }

      print('\n🔍 Checking if we can query default_restrictions table...');
      try {
        final apps = await service.getDefaultRestrictedApps();
        final websites = await service.getDefaultRestrictedWebsites();
        print('✅ Restrictions table accessible');
        print('  Found ${apps.length} restricted apps');
        print('  Found ${websites.length} restricted websites');
      } catch (e) {
        print('❌ ERROR accessing restrictions table: $e');
        fail('Cannot access restrictions table: $e');
      }
    });
  });
}
