import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Offline cache service using Hive for local storage
/// Provides offline-first architecture with sync capabilities
class OfflineCacheService {
  static const String _tasksBoxName = 'tasks_cache';
  static const String _restrictionsBoxName = 'restrictions_cache';
  static const String _pendingOperationsBoxName = 'pending_operations';
  static const String _metadataBoxName = 'cache_metadata';

  late Box<Map> _tasksBox;
  late Box<Map> _restrictionsBox;
  late Box<Map> _pendingOperationsBox;
  late Box _metadataBox;

  bool _isInitialized = false;

  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  bool get isInitialized => _isInitialized;

  /// Initialize Hive and open boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      _tasksBox = await Hive.openBox<Map>(_tasksBoxName);
      _restrictionsBox = await Hive.openBox<Map>(_restrictionsBoxName);
      _pendingOperationsBox = await Hive.openBox<Map>(_pendingOperationsBoxName);
      _metadataBox = await Hive.openBox(_metadataBoxName);

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
      await _tasksBox.clear();
      for (var task in tasks) {
        final id = task['id'] as String;
        await _tasksBox.put(id, Map<String, dynamic>.from(task));
      }
      await _metadataBox.put('tasks_last_sync', DateTime.now().toIso8601String());
      debugPrint('✅ Cached ${tasks.length} tasks locally');
    } catch (e) {
      debugPrint('❌ Error caching tasks: $e');
    }
  }

  /// Get all cached tasks
  List<Map<String, dynamic>> getCachedTasks() {
    try {
      final tasks = _tasksBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
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
      debugPrint('✅ Cached task: $id');
    } catch (e) {
      debugPrint('❌ Error caching task: $e');
    }
  }

  /// Remove a task from cache
  Future<void> removeCachedTask(String id) async {
    try {
      await _tasksBox.delete(id);
      debugPrint('✅ Removed task from cache: $id');
    } catch (e) {
      debugPrint('❌ Error removing task from cache: $e');
    }
  }

  /// Get a single cached task
  Map<String, dynamic>? getCachedTask(String id) {
    try {
      final task = _tasksBox.get(id);
      return task != null ? Map<String, dynamic>.from(task) : null;
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
      await _restrictionsBox.put('default_apps', {'items': apps});
      await _restrictionsBox.put('default_websites', {'items': websites});
      await _metadataBox.put('restrictions_last_sync', DateTime.now().toIso8601String());
      debugPrint('✅ Cached default restrictions: ${apps.length} apps, ${websites.length} websites');
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
      await _restrictionsBox.put('permanent_apps', {'items': apps});
      await _restrictionsBox.put('permanent_websites', {'items': websites});
      debugPrint('✅ Cached permanent blocks: ${apps.length} apps, ${websites.length} websites');
    } catch (e) {
      debugPrint('❌ Error caching permanent blocks: $e');
    }
  }

  /// Get cached default restricted apps
  List<String> getCachedDefaultApps() {
    try {
      final data = _restrictionsBox.get('default_apps');
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
      final data = _restrictionsBox.get('default_websites');
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
      final data = _restrictionsBox.get('permanent_apps');
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
      final data = _restrictionsBox.get('permanent_websites');
      if (data != null && data['items'] != null) {
        return List<String>.from(data['items']);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting cached permanent websites: $e');
      return [];
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

  /// Check if cache is stale (older than given duration)
  bool isCacheStale(Duration maxAge) {
    final lastSync = getTasksLastSync();
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > maxAge;
  }

  /// Clear all cached data
  Future<void> clearAll() async {
    try {
      await _tasksBox.clear();
      await _restrictionsBox.clear();
      await _pendingOperationsBox.clear();
      await _metadataBox.clear();
      debugPrint('✅ Cleared all cached data');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }
}
