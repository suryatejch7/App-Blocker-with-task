import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_keys.dart';

/// Offline cache service using Hive for local storage
/// Provides offline-first architecture with sync capabilities
class OfflineCacheService {
  late Box<Map> _tasksBox;
  late Box<Map> _archivedTasksBox;
  late Box<Map> _restrictionsBox;
  late Box<Map> _pendingOperationsBox;
  late Box _metadataBox;

  bool _isInitialized = false;

  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  bool get isInitialized => _isInitialized;

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  /// Initialize Hive and open boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

        _tasksBox = await Hive.openBox<Map>(HiveBoxKeys.tasks);
        _archivedTasksBox = await Hive.openBox<Map>(HiveBoxKeys.archivedTasks);
        _restrictionsBox = await Hive.openBox<Map>(HiveBoxKeys.restrictions);
      _pendingOperationsBox =
          await Hive.openBox<Map>(HiveBoxKeys.pendingOperations);
        _metadataBox = await Hive.openBox(HiveBoxKeys.metadata);

      // Ensure default restriction keys exist
      if (_restrictionsBox.get(HiveRestrictionsKeys.defaultApps) == null) {
        await _restrictionsBox
            .put(HiveRestrictionsKeys.defaultApps, {'items': <String>[]});
      }
      if (_restrictionsBox.get(HiveRestrictionsKeys.defaultWebsites) == null) {
        await _restrictionsBox
            .put(HiveRestrictionsKeys.defaultWebsites, {'items': <String>[]});
      }
      if (_restrictionsBox.get(HiveRestrictionsKeys.permanentApps) == null) {
        await _restrictionsBox
            .put(HiveRestrictionsKeys.permanentApps, {'items': <String>[]});
      }
      if (_restrictionsBox.get(HiveRestrictionsKeys.permanentWebsites) == null) {
        await _restrictionsBox.put(
            HiveRestrictionsKeys.permanentWebsites, {'items': <String>[]});
      }

      // Legacy remote-sync queue is no longer used in local-only flow.
      if (_pendingOperationsBox.isNotEmpty) {
        await _pendingOperationsBox.clear();
      }

      _isInitialized = true;
      debugPrint('✅ OfflineCacheService initialized');
    } catch (e, stackTrace) {
      debugPrint('❌ OfflineCacheService initialization failed: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ==================== TASKS ====================

  /// Cache all tasks locally
  Future<void> cacheTasks(List<Map<String, dynamic>> tasks) async {
    try {
      final incoming = <String, Map>{
        for (final task in tasks)
          (task['id']?.toString() ?? ''): Map<String, dynamic>.from(task),
      };

      incoming.removeWhere((key, value) => key.trim().isEmpty);

      final toDelete = _tasksBox.keys
          .where((key) => !incoming.containsKey(key))
          .toList(growable: false);
      if (toDelete.isNotEmpty) {
        await _tasksBox.deleteAll(toDelete);
      }

      if (incoming.isNotEmpty) {
        await _tasksBox.putAll(incoming);
      }

      await _tasksBox.flush();
      await _metadataBox.put(
          'tasks_last_sync', DateTime.now().toIso8601String());
      debugPrint('✅ Cached ${tasks.length} tasks locally');
    } catch (e) {
      debugPrint('❌ Error caching tasks: $e');
    }
  }

  /// Get all cached tasks
  List<Map<String, dynamic>> getCachedTasks() {
    try {
      final tasks = _tasksBox.values.map(_safeMap).toList();
      debugPrint('📦 Retrieved ${tasks.length} tasks from cache');
      return tasks;
    } catch (e) {
      debugPrint('❌ Error getting cached tasks: $e');
      return [];
    }
  }

  /// Cache a single task (for offline create/update)
  Future<void> cacheTask(Map<String, dynamic> task) async {
    try {
      final id = task['id'] as String;
      await _tasksBox.put(id, Map<String, dynamic>.from(task));
      await _tasksBox.flush();
      debugPrint('✅ Cached task: $id');
    } catch (e) {
      debugPrint('❌ Error caching task: $e');
    }
  }

  /// Upsert task and persist immediately
  Future<void> upsertTask(Map<String, dynamic> task) async {
    await cacheTask(task);
    await _tasksBox.flush();
    await _metadataBox.put('tasks_last_sync', DateTime.now().toIso8601String());
  }

  /// Remove a task from cache
  Future<void> removeCachedTask(String id) async {
    try {
      await _tasksBox.delete(id);
      await _tasksBox.flush();
      debugPrint('✅ Removed task from cache: $id');
    } catch (e) {
      debugPrint('❌ Error removing task from cache: $e');
    }
  }

  /// Archive a task locally for history/analytics
  Future<void> archiveTask(Map<String, dynamic> task) async {
    try {
      final id = task['id'] as String;
      await _archivedTasksBox.put(id, Map<String, dynamic>.from(task));
      await _metadataBox.put(
          'archive_last_update', DateTime.now().toIso8601String());
      debugPrint('✅ Archived task locally: $id');
    } catch (e) {
      debugPrint('❌ Error archiving task locally: $e');
    }
  }

  /// Return archived tasks
  List<Map<String, dynamic>> getArchivedTasks() {
    try {
      return _archivedTasksBox.values.map(_safeMap).toList();
    } catch (e) {
      debugPrint('❌ Error getting archived tasks: $e');
      return [];
    }
  }

  /// Get a single cached task
  Map<String, dynamic>? getCachedTask(String id) {
    try {
      final task = _tasksBox.get(id);
      return task != null ? _safeMap(task) : null;
    } catch (e) {
      debugPrint('❌ Error getting cached task: $e');
      return null;
    }
  }

  // ==================== RESTRICTIONS ====================

  /// Cache default restrictions
  Future<void> cacheDefaultRestrictions({
    required List<String> apps,
    required List<String> websites,
  }) async {
    try {
      await _restrictionsBox
          .put(HiveRestrictionsKeys.defaultApps, {'items': apps});
      await _restrictionsBox
          .put(HiveRestrictionsKeys.defaultWebsites, {'items': websites});
      await _metadataBox.put(
          'restrictions_last_sync', DateTime.now().toIso8601String());
      debugPrint(
          '✅ Cached default restrictions: ${apps.length} apps, ${websites.length} websites');
    } catch (e) {
      debugPrint('❌ Error caching default restrictions: $e');
    }
  }

  /// Cache permanent blocks
  Future<void> cachePermanentBlocks({
    required List<String> apps,
    required List<String> websites,
  }) async {
    try {
      await _restrictionsBox
          .put(HiveRestrictionsKeys.permanentApps, {'items': apps});
      await _restrictionsBox
          .put(HiveRestrictionsKeys.permanentWebsites, {'items': websites});
      debugPrint(
          '✅ Cached permanent blocks: ${apps.length} apps, ${websites.length} websites');
    } catch (e) {
      debugPrint('❌ Error caching permanent blocks: $e');
    }
  }

  /// Get cached default restricted apps
  List<String> getCachedDefaultApps() {
    try {
      final data = _restrictionsBox.get(HiveRestrictionsKeys.defaultApps);
      if (data != null && data['items'] != null) {
        return List<String>.from(data['items']);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting cached default apps: $e');
      return [];
    }
  }

  /// Get cached default restricted websites
  List<String> getCachedDefaultWebsites() {
    try {
      final data = _restrictionsBox.get(HiveRestrictionsKeys.defaultWebsites);
      if (data != null && data['items'] != null) {
        return List<String>.from(data['items']);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting cached default websites: $e');
      return [];
    }
  }

  /// Get cached permanent blocked apps
  List<String> getCachedPermanentApps() {
    try {
      final data = _restrictionsBox.get(HiveRestrictionsKeys.permanentApps);
      if (data != null && data['items'] != null) {
        return List<String>.from(data['items']);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting cached permanent apps: $e');
      return [];
    }
  }

  /// Get cached permanent blocked websites
  List<String> getCachedPermanentWebsites() {
    try {
      final data =
          _restrictionsBox.get(HiveRestrictionsKeys.permanentWebsites);
      if (data != null && data['items'] != null) {
        return List<String>.from(data['items']);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting cached permanent websites: $e');
      return [];
    }
  }

  /// Persist all restriction collections in one call
  Future<void> saveRestrictions({
    required List<String> defaultApps,
    required List<String> defaultWebsites,
    required List<String> permanentApps,
    required List<String> permanentWebsites,
  }) async {
    try {
      await cacheDefaultRestrictions(
          apps: defaultApps, websites: defaultWebsites);
      await cachePermanentBlocks(
          apps: permanentApps, websites: permanentWebsites);
      await _metadataBox.put(
          'restrictions_last_sync', DateTime.now().toIso8601String());
      debugPrint('✅ Saved restrictions locally');
    } catch (e) {
      debugPrint('❌ Error saving restrictions locally: $e');
    }
  }

  // ==================== PENDING OPERATIONS ====================
  // For operations made while offline that need to sync when online

  /// Add a pending operation to sync later
  Future<void> addPendingOperation({
    required String type, // 'create', 'update', 'delete'
    required String entity, // 'task', 'restriction', 'permanent_block'
    required Map<String, dynamic> data,
  }) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await _pendingOperationsBox.put(id, {
        'type': type,
        'entity': entity,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Added pending operation: $type $entity');
    } catch (e) {
      debugPrint('❌ Error adding pending operation: $e');
    }
  }

  /// Get all pending operations
  List<Map<String, dynamic>> getPendingOperations() {
    try {
      return _pendingOperationsBox.keys.map((key) {
        final op = _pendingOperationsBox.get(key);
        return {
          'key': key,
          ...Map<String, dynamic>.from(op!),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting pending operations: $e');
      return [];
    }
  }

  /// Remove a pending operation after successful sync
  Future<void> removePendingOperation(String key) async {
    try {
      await _pendingOperationsBox.delete(key);
      debugPrint('✅ Removed pending operation: $key');
    } catch (e) {
      debugPrint('❌ Error removing pending operation: $e');
    }
  }

  /// Check if there are pending operations
  bool hasPendingOperations() {
    return _pendingOperationsBox.isNotEmpty;
  }

  /// Get count of pending operations
  int get pendingOperationsCount => _pendingOperationsBox.length;

  // ==================== METADATA ====================

  /// Get last sync time for tasks
  DateTime? getTasksLastSync() {
    try {
      final timestamp = _metadataBox.get('tasks_last_sync');
      return timestamp != null ? DateTime.parse(timestamp) : null;
    } catch (e) {
      return null;
    }
  }

  /// Get last sync time for restrictions
  DateTime? getRestrictionsLastSync() {
    try {
      final timestamp = _metadataBox.get('restrictions_last_sync');
      return timestamp != null ? DateTime.parse(timestamp) : null;
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached data
  Future<void> clearAll() async {
    try {
      await _tasksBox.clear();
      await _archivedTasksBox.clear();
      await _restrictionsBox.clear();
      await _pendingOperationsBox.clear();
      await _metadataBox.clear();
      debugPrint('✅ Cleared all cached data');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }
}
