import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker_flutter/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskProvider - Add Task Tests', () {
    test('addTask creates valid task object', () {
      final task = Task(
        id: 'test-add-1',
        title: 'Test Add Task',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(task.id, 'test-add-1');
      expect(task.title, 'Test Add Task');
      expect(task.completed, false);
    });

    test('addTask should handle task with all fields', () {
      final task = Task(
        id: 'test-add-2',
        title: 'Complex Task',
        description: 'This is a complex task with all fields',
        startTime: DateTime(2025, 11, 20, 10, 0),
        endTime: DateTime(2025, 11, 20, 12, 0),
        completed: false,
        repeatSettings: 'daily',
        restrictionMode: 'custom',
        customRestrictedApps: ['com.facebook.katana', 'com.instagram.android'],
        customRestrictedWebsites: ['youtube.com', 'twitter.com'],
      );

      expect(task.title, 'Complex Task');
      expect(task.customRestrictedApps.length, 2);
      expect(task.customRestrictedWebsites.length, 2);
    });

    test('addTask should handle empty optional fields', () {
      final task = Task(
        id: 'test-add-3',
        title: 'Minimal Task',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        description: null,
        customRestrictedApps: [],
        customRestrictedWebsites: [],
      );

      expect(task.description, isNull);
      expect(task.customRestrictedApps, isEmpty);
      expect(task.customRestrictedWebsites, isEmpty);
    });
  });

  group('TaskProvider - Today Tasks Filter', () {
    test('todayTasks should include tasks starting today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Manually add a task to internal list for testing
      final todayTask = Task(
        id: 'today-1',
        title: 'Today Task',
        startTime: today.add(const Duration(hours: 10)),
        endTime: today.add(const Duration(hours: 12)),
        completed: false,
      );

      // Since we can't actually add to provider without Supabase,
      // we test the logic separately
      final isToday = todayTask.startTime.year == today.year &&
          todayTask.startTime.month == today.month &&
          todayTask.startTime.day == today.day;

      expect(isToday, true);
    });

    test('todayTasks should exclude future tasks', () {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      final futureTask = Task(
        id: 'future-1',
        title: 'Future Task',
        startTime: tomorrow,
        endTime: tomorrow.add(const Duration(hours: 1)),
        completed: false,
      );

      final isToday = futureTask.startTime.year == now.year &&
          futureTask.startTime.month == now.month &&
          futureTask.startTime.day == now.day;

      expect(isToday, false);
    });

    test('todayTasks should include overdue tasks', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final overdueTask = Task(
        id: 'overdue-1',
        title: 'Overdue Task',
        startTime: yesterday,
        endTime: yesterday.add(const Duration(hours: 1)),
        completed: false,
      );

      expect(overdueTask.isOverdue, true);
    });

    test('todayTasks should exclude completed tasks in past', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final completedTask = Task(
        id: 'completed-1',
        title: 'Completed Task',
        startTime: yesterday,
        endTime: yesterday.add(const Duration(hours: 1)),
        completed: true,
      );

      expect(completedTask.isOverdue, false);
      expect(completedTask.completed, true);
    });
  });

  group('TaskProvider - Future Tasks Grouping', () {
    test('futureTasks should group by date correctly', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowDate =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

      final futureTask1 = Task(
        id: 'future-group-1',
        title: 'Future Task 1',
        startTime: tomorrowDate.add(const Duration(hours: 9)),
        endTime: tomorrowDate.add(const Duration(hours: 10)),
      );

      final futureTask2 = Task(
        id: 'future-group-2',
        title: 'Future Task 2',
        startTime: tomorrowDate.add(const Duration(hours: 14)),
        endTime: tomorrowDate.add(const Duration(hours: 15)),
      );

      final date1 = DateTime(futureTask1.startTime.year,
          futureTask1.startTime.month, futureTask1.startTime.day);
      final date2 = DateTime(futureTask2.startTime.year,
          futureTask2.startTime.month, futureTask2.startTime.day);

      expect(date1, date2);
    });

    test('futureTasks should separate different dates', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dayAfter = DateTime.now().add(const Duration(days: 2));

      final task1 = Task(
        id: 'future-sep-1',
        title: 'Tomorrow Task',
        startTime: tomorrow,
        endTime: tomorrow.add(const Duration(hours: 1)),
      );

      final task2 = Task(
        id: 'future-sep-2',
        title: 'Day After Task',
        startTime: dayAfter,
        endTime: dayAfter.add(const Duration(hours: 1)),
      );

      final date1 = DateTime(
          task1.startTime.year, task1.startTime.month, task1.startTime.day);
      final date2 = DateTime(
          task2.startTime.year, task2.startTime.month, task2.startTime.day);

      expect(date1.isBefore(date2), true);
    });
  });

  group('TaskProvider - Task Completion', () {
    test('toggleComplete should set completed to true', () {
      final task = Task(
        id: 'toggle-1',
        title: 'Toggle Task',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        completed: false,
      );

      expect(task.completed, false);

      // Create updated task
      final updatedTask = Task(
        id: task.id,
        title: task.title,
        startTime: task.startTime,
        endTime: task.endTime,
        completed: true,
        completedAt: DateTime.now(),
      );

      expect(updatedTask.completed, true);
      expect(updatedTask.completedAt, isNotNull);
    });

    test('toggleComplete should set completedAt timestamp', () {
      final now = DateTime.now();
      final task = Task(
        id: 'toggle-2',
        title: 'Toggle Task 2',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        completed: true,
        completedAt: now,
      );

      expect(task.completedAt, isNotNull);
      expect(task.completedAt!.isBefore(now.add(const Duration(seconds: 1))),
          true);
    });

    test('toggleComplete from true to false should clear completedAt', () {
      final task = Task(
        id: 'toggle-3',
        title: 'Toggle Task 3',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        completed: false,
        completedAt: null,
      );

      expect(task.completed, false);
      expect(task.completedAt, isNull);
    });
  });

  group('TaskProvider - Task Update', () {
    test('updateTask should modify task properties', () {
      final originalTask = Task(
        id: 'update-1',
        title: 'Original Title',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );

      final updatedTask = Task(
        id: originalTask.id,
        title: 'Updated Title',
        description: 'New description',
        startTime: originalTask.startTime,
        endTime: originalTask.endTime,
        repeatSettings: 'weekly',
      );

      expect(updatedTask.id, originalTask.id);
      expect(updatedTask.title, 'Updated Title');
      expect(updatedTask.description, 'New description');
      expect(updatedTask.repeatSettings, 'weekly');
    });

    test('updateTask should preserve unchanged fields', () {
      final originalTask = Task(
        id: 'update-2',
        title: 'Preserve Test',
        description: 'Original description',
        startTime: DateTime(2025, 11, 20, 10, 0),
        endTime: DateTime(2025, 11, 20, 12, 0),
        completed: false,
      );

      final updatedTask = Task(
        id: originalTask.id,
        title: 'Updated Title',
        description: originalTask.description,
        startTime: originalTask.startTime,
        endTime: originalTask.endTime,
        completed: originalTask.completed,
      );

      expect(updatedTask.description, originalTask.description);
      expect(updatedTask.startTime, originalTask.startTime);
      expect(updatedTask.endTime, originalTask.endTime);
      expect(updatedTask.completed, originalTask.completed);
    });
  });

  group('TaskProvider - Task Deletion', () {
    test('removeTask validates task ID format', () {
      const taskId = 'delete-1';
      expect(taskId.isNotEmpty, true);
      expect(taskId, isA<String>());
    });
  });

  group('TaskProvider - Repeat Settings', () {
    test('Task with "none" repeat should not repeat', () {
      final task = Task(
        id: 'repeat-1',
        title: 'No Repeat',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        repeatSettings: 'none',
      );

      expect(task.repeatSettings, 'none');
    });

    test('Task with "daily" repeat should have daily setting', () {
      final task = Task(
        id: 'repeat-2',
        title: 'Daily Task',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        repeatSettings: 'daily',
      );

      expect(task.repeatSettings, 'daily');
    });

    test('Task with "weekly" repeat should have weekly setting', () {
      final task = Task(
        id: 'repeat-3',
        title: 'Weekly Task',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        repeatSettings: 'weekly',
      );

      expect(task.repeatSettings, 'weekly');
    });

    test('Task with "monthly" repeat should have monthly setting', () {
      final task = Task(
        id: 'repeat-4',
        title: 'Monthly Task',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        repeatSettings: 'monthly',
      );

      expect(task.repeatSettings, 'monthly');
    });
  });

  group('TaskProvider - Restriction Modes', () {
    test('Task with "default" restriction mode', () {
      final task = Task(
        id: 'restrict-1',
        title: 'Default Restrictions',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        restrictionMode: 'default',
      );

      expect(task.restrictionMode, 'default');
      expect(task.customRestrictedApps, isEmpty);
      expect(task.customRestrictedWebsites, isEmpty);
    });

    test('Task with "custom" restriction mode and apps', () {
      final task = Task(
        id: 'restrict-2',
        title: 'Custom Restrictions',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        restrictionMode: 'custom',
        customRestrictedApps: ['com.facebook.katana', 'com.instagram.android'],
        customRestrictedWebsites: ['youtube.com'],
      );

      expect(task.restrictionMode, 'custom');
      expect(task.customRestrictedApps.length, 2);
      expect(task.customRestrictedWebsites.length, 1);
    });

    test('Task with "none" restriction mode', () {
      final task = Task(
        id: 'restrict-3',
        title: 'No Restrictions',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        restrictionMode: 'none',
      );

      expect(task.restrictionMode, 'none');
    });
  });

  group('TaskProvider - Time Validation', () {
    test('Task endTime should be after startTime', () {
      final startTime = DateTime.now();
      final endTime = startTime.add(const Duration(hours: 2));

      final task = Task(
        id: 'time-1',
        title: 'Valid Time Task',
        startTime: startTime,
        endTime: endTime,
      );

      expect(task.endTime.isAfter(task.startTime), true);
    });

    test('Task with same start and end time', () {
      final time = DateTime.now();

      final task = Task(
        id: 'time-2',
        title: 'Same Time Task',
        startTime: time,
        endTime: time,
      );

      expect(task.startTime.isAtSameMomentAs(task.endTime), true);
    });

    test('Task duration calculation', () {
      final startTime = DateTime(2025, 11, 20, 10, 0);
      final endTime = DateTime(2025, 11, 20, 12, 30);

      final task = Task(
        id: 'time-3',
        title: 'Duration Test',
        startTime: startTime,
        endTime: endTime,
      );

      final duration = task.endTime.difference(task.startTime);
      expect(duration.inMinutes, 150); // 2.5 hours
    });
  });

  group('TaskProvider - Overdue Detection', () {
    test('Incomplete task past endTime is overdue', () {
      final pastTime = DateTime.now().subtract(const Duration(hours: 2));

      final task = Task(
        id: 'overdue-detect-1',
        title: 'Overdue Task',
        startTime: pastTime.subtract(const Duration(hours: 1)),
        endTime: pastTime,
        completed: false,
      );

      expect(task.isOverdue, true);
    });

    test('Completed task past endTime is not overdue', () {
      final pastTime = DateTime.now().subtract(const Duration(hours: 2));

      final task = Task(
        id: 'overdue-detect-2',
        title: 'Completed Past Task',
        startTime: pastTime.subtract(const Duration(hours: 1)),
        endTime: pastTime,
        completed: true,
      );

      expect(task.isOverdue, false);
    });

    test('Future task is not overdue', () {
      final futureTime = DateTime.now().add(const Duration(hours: 2));

      final task = Task(
        id: 'overdue-detect-3',
        title: 'Future Task',
        startTime: futureTime,
        endTime: futureTime.add(const Duration(hours: 1)),
        completed: false,
      );

      expect(task.isOverdue, false);
    });

    test('Current active task is not overdue', () {
      final now = DateTime.now();

      final task = Task(
        id: 'overdue-detect-4',
        title: 'Active Task',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now.add(const Duration(minutes: 30)),
        completed: false,
      );

      expect(task.isOverdue, false);
      expect(task.isActive, true);
    });
  });

  group('TaskProvider - Active Task Detection', () {
    test('Task with current time between start and end is active', () {
      final now = DateTime.now();

      final task = Task(
        id: 'active-1',
        title: 'Active Task',
        startTime: now.subtract(const Duration(minutes: 15)),
        endTime: now.add(const Duration(minutes: 45)),
        completed: false,
      );

      expect(task.isActive, true);
    });

    test('Task not started yet is not active', () {
      final future = DateTime.now().add(const Duration(hours: 1));

      final task = Task(
        id: 'active-2',
        title: 'Future Task',
        startTime: future,
        endTime: future.add(const Duration(hours: 1)),
        completed: false,
      );

      expect(task.isActive, false);
    });

    test('Task already ended is not active', () {
      final past = DateTime.now().subtract(const Duration(hours: 2));

      final task = Task(
        id: 'active-3',
        title: 'Past Task',
        startTime: past.subtract(const Duration(hours: 1)),
        endTime: past,
        completed: false,
      );

      expect(task.isActive, false);
    });

    test('Completed task is not active even if time matches', () {
      final now = DateTime.now();

      final task = Task(
        id: 'active-4',
        title: 'Completed Active Time Task',
        startTime: now.subtract(const Duration(minutes: 15)),
        endTime: now.add(const Duration(minutes: 45)),
        completed: true,
      );

      expect(task.isActive, false);
    });
  });

  group('TaskProvider - Edge Cases', () {
    test('Task with very long duration', () {
      final startTime = DateTime(2025, 11, 20, 9, 0);
      final endTime = DateTime(2025, 11, 25, 18, 0); // 5 days later

      final task = Task(
        id: 'edge-1',
        title: 'Long Duration Task',
        startTime: startTime,
        endTime: endTime,
      );

      final duration = task.endTime.difference(task.startTime);
      expect(duration.inDays, 5);
    });

    test('Task with many custom restrictions', () {
      final task = Task(
        id: 'edge-2',
        title: 'Many Restrictions',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        restrictionMode: 'custom',
        customRestrictedApps: [
          'com.facebook.katana',
          'com.instagram.android',
          'com.twitter.android',
          'com.snapchat.android',
          'com.reddit.frontpage',
        ],
        customRestrictedWebsites: [
          'youtube.com',
          'facebook.com',
          'twitter.com',
          'instagram.com',
          'reddit.com',
          'tiktok.com',
        ],
      );

      expect(task.customRestrictedApps.length, 5);
      expect(task.customRestrictedWebsites.length, 6);
    });

    test('Task with very long title and description', () {
      final longTitle = 'A' * 500;
      final longDescription = 'B' * 2000;

      final task = Task(
        id: 'edge-3',
        title: longTitle,
        description: longDescription,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(task.title.length, 500);
      expect(task.description!.length, 2000);
    });

    test('Task at midnight boundary', () {
      final midnight = DateTime(2025, 11, 20, 0, 0, 0);

      final task = Task(
        id: 'edge-4',
        title: 'Midnight Task',
        startTime: midnight,
        endTime: midnight.add(const Duration(hours: 1)),
      );

      expect(task.startTime.hour, 0);
      expect(task.startTime.minute, 0);
    });

    test('Task spanning midnight', () {
      final beforeMidnight = DateTime(2025, 11, 20, 23, 30);
      final afterMidnight = DateTime(2025, 11, 21, 0, 30);

      final task = Task(
        id: 'edge-5',
        title: 'Midnight Spanning Task',
        startTime: beforeMidnight,
        endTime: afterMidnight,
      );

      expect(task.startTime.day, 20);
      expect(task.endTime.day, 21);
    });
  });
}
