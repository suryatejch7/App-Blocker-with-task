import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_cache_service.dart';
import 'connectivity_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Load from environment variables (secure)
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  SupabaseClient get client => Supabase.instance.client;

  final _cacheService = OfflineCacheService();
  final _connectivityService = ConnectivityService();

  bool get isOnline => _connectivityService.isOnline;

  static Future<void> initialize() async {
    // Load environment variables
    await dotenv.load(fileName: '.env');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('Supabase credentials not found in .env file');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Tasks table operations
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      // If offline, return cached data
      if (!isOnline) {
        debugPrint('📴 Offline - returning cached tasks');
        return _cacheService.getCachedTasks();
      }

      debugPrint(
          '🔵 SupabaseService.getTasks - Fetching tasks from database...');
      final response = await client
          .from('tasks')
          .select()
          .order('start_time', ascending: true);
      debugPrint(
          '✅ SupabaseService.getTasks - Fetched ${response.length} tasks');
      
      final tasks = List<Map<String, dynamic>>.from(response);
      
      // Cache for offline use
      await _cacheService.cacheTasks(tasks);
      
      return tasks;
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.getTasks - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Fall back to cache on error
      debugPrint('📦 Falling back to cached tasks');
      return _cacheService.getCachedTasks();
    }
  }

  Future<void> insertTask(Map<String, dynamic> task) async {
    try {
      // Always cache locally first
      await _cacheService.cacheTask(task);

      if (!isOnline) {
        debugPrint('� Offline - task saved locally, will sync later');
        await _cacheService.addPendingOperation(
          type: 'create',
          entity: 'task',
          data: task,
        );
        return;
      }

      debugPrint('🔵 SupabaseService.insertTask - Attempting to insert task');
      debugPrint('🔵 Task ID: ${task['id']}');
      debugPrint('� Task title: ${task['title']}');

      await client.from('tasks').insert(task).select();

      debugPrint(
          '✅ SupabaseService.insertTask - SUCCESS! Task saved to database');
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ SupabaseService.insertTask - FAILED! ❌❌❌');
      debugPrint('❌ Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');

      // Save for later sync if network error
      await _cacheService.addPendingOperation(
        type: 'create',
        entity: 'task',
        data: task,
      );
      rethrow;
    }
  }

  Future<void> updateTask(String id, Map<String, dynamic> task) async {
    try {
      // Always update cache first
      await _cacheService.cacheTask(task);

      if (!isOnline) {
        debugPrint('� Offline - task updated locally, will sync later');
        await _cacheService.addPendingOperation(
          type: 'update',
          entity: 'task',
          data: task,
        );
        return;
      }

      debugPrint('🔵 SupabaseService.updateTask - Updating task ID: $id');
      await client.from('tasks').update(task).eq('id', id);
      debugPrint('✅ SupabaseService.updateTask - Task updated successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.updateTask - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');

      await _cacheService.addPendingOperation(
        type: 'update',
        entity: 'task',
        data: task,
      );
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      // Always remove from cache first
      await _cacheService.removeCachedTask(id);

      if (!isOnline) {
        debugPrint('📴 Offline - task deleted locally, will sync later');
        await _cacheService.addPendingOperation(
          type: 'delete',
          entity: 'task',
          data: {'id': id},
        );
        return;
      }

      debugPrint('🔵 SupabaseService.deleteTask - Deleting task ID: $id');
      await client.from('tasks').delete().eq('id', id);
      debugPrint('✅ SupabaseService.deleteTask - Task deleted successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.deleteTask - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');

      await _cacheService.addPendingOperation(
        type: 'delete',
        entity: 'task',
        data: {'id': id},
      );
      rethrow;
    }
  }

  // Restrictions table operations
  Future<List<String>> getDefaultRestrictedApps() async {
    try {
      if (!isOnline) {
        debugPrint('� Offline - returning cached default apps');
        return _cacheService.getCachedDefaultApps();
      }

      debugPrint('�🔵 SupabaseService.getDefaultRestrictedApps - Fetching...');
      final response = await client
          .from('default_restrictions')
          .select('package_name')
          .eq('type', 'app');
      final apps =
          (response as List).map((e) => e['package_name'] as String).toList();
      debugPrint(
          '✅ SupabaseService.getDefaultRestrictedApps - Fetched ${apps.length} apps');
      return apps;
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.getDefaultRestrictedApps - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return _cacheService.getCachedDefaultApps();
    }
  }

  Future<List<String>> getDefaultRestrictedWebsites() async {
    try {
      if (!isOnline) {
        debugPrint('📴 Offline - returning cached default websites');
        return _cacheService.getCachedDefaultWebsites();
      }

      debugPrint(
          '🔵 SupabaseService.getDefaultRestrictedWebsites - Fetching...');
      final response = await client
          .from('default_restrictions')
          .select('domain')
          .eq('type', 'website');
      final websites =
          (response as List).map((e) => e['domain'] as String).toList();
      debugPrint(
          '✅ SupabaseService.getDefaultRestrictedWebsites - Fetched ${websites.length} websites');
      return websites;
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.getDefaultRestrictedWebsites - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return _cacheService.getCachedDefaultWebsites();
    }
  }

  Future<void> addDefaultRestriction(String type, String value) async {
    final data = {
      'type': type,
      if (type == 'app') 'package_name': value,
      if (type == 'website') 'domain': value,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      if (!isOnline) {
        debugPrint('� Offline - restriction saved locally, will sync later');
        await _cacheService.addPendingOperation(
          type: 'create',
          entity: 'default_restriction',
          data: data,
        );
        return;
      }

      debugPrint(
          '🔵 SupabaseService.addDefaultRestriction - Type: $type, Value: $value');

      await client.from('default_restrictions').insert(data).select();

      debugPrint('✅ SupabaseService.addDefaultRestriction - SUCCESS!');
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.addDefaultRestriction - FAILED! $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> removeDefaultRestriction(String type, String value) async {
    try {
      if (!isOnline) {
        debugPrint('� Offline - restriction removal saved locally');
        await _cacheService.addPendingOperation(
          type: 'delete',
          entity: 'default_restriction',
          data: {
            'type': type,
            if (type == 'app') 'package_name': value,
            if (type == 'website') 'domain': value,
          },
        );
        return;
      }

      debugPrint(
          '🔵 SupabaseService.removeDefaultRestriction - Type: $type, Value: $value');
      if (type == 'app') {
        await client
            .from('default_restrictions')
            .delete()
            .eq('type', 'app')
            .eq('package_name', value);
      } else {
        await client
            .from('default_restrictions')
            .delete()
            .eq('type', 'website')
            .eq('domain', value);
      }
      debugPrint(
          '✅ SupabaseService.removeDefaultRestriction - Removed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.removeDefaultRestriction - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Permanently blocked apps operations
  Future<List<String>> getPermanentlyBlockedApps() async {
    try {
      if (!isOnline) {
        debugPrint('� Offline - returning cached permanent apps');
        return _cacheService.getCachedPermanentApps();
      }

      debugPrint('�🔵 SupabaseService.getPermanentlyBlockedApps - Fetching...');
      final response = await client
          .from('permanent_blocks')
          .select('package_name')
          .eq('type', 'app');
      final apps =
          (response as List).map((e) => e['package_name'] as String).toList();
      debugPrint(
          '✅ SupabaseService.getPermanentlyBlockedApps - Fetched ${apps.length} apps');
      return apps;
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.getPermanentlyBlockedApps - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return _cacheService.getCachedPermanentApps();
    }
  }

  Future<List<String>> getPermanentlyBlockedWebsites() async {
    try {
      if (!isOnline) {
        debugPrint('📴 Offline - returning cached permanent websites');
        return _cacheService.getCachedPermanentWebsites();
      }

      debugPrint(
          '🔵 SupabaseService.getPermanentlyBlockedWebsites - Fetching...');
      final response = await client
          .from('permanent_blocks')
          .select('domain')
          .eq('type', 'website');
      final websites =
          (response as List).map((e) => e['domain'] as String).toList();
      debugPrint(
          '✅ SupabaseService.getPermanentlyBlockedWebsites - Fetched ${websites.length} websites');
      return websites;
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.getPermanentlyBlockedWebsites - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return _cacheService.getCachedPermanentWebsites();
    }
  }

  Future<void> addPermanentBlock(String type, String value) async {
    final data = {
      'type': type,
      if (type == 'app') 'package_name': value,
      if (type == 'website') 'domain': value,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      if (!isOnline) {
        debugPrint('📴 Offline - permanent block saved locally');
        await _cacheService.addPendingOperation(
          type: 'create',
          entity: 'permanent_block',
          data: data,
        );
        return;
      }

      debugPrint(
          '🔵 SupabaseService.addPermanentBlock - Type: $type, Value: $value');

      await client.from('permanent_blocks').insert(data).select();

      debugPrint('✅ SupabaseService.addPermanentBlock - SUCCESS!');
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.addPermanentBlock - FAILED! $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> removePermanentBlock(String type, String value) async {
    try {
      if (!isOnline) {
        debugPrint('📴 Offline - permanent block removal saved locally');
        await _cacheService.addPendingOperation(
          type: 'delete',
          entity: 'permanent_block',
          data: {
            'type': type,
            if (type == 'app') 'package_name': value,
            if (type == 'website') 'domain': value,
          },
        );
        return;
      }

      debugPrint(
          '🔵 SupabaseService.removePermanentBlock - Type: $type, Value: $value');
      if (type == 'app') {
        await client
            .from('permanent_blocks')
            .delete()
            .eq('type', 'app')
            .eq('package_name', value);
      } else {
        await client
            .from('permanent_blocks')
            .delete()
            .eq('type', 'website')
            .eq('domain', value);
      }
      debugPrint(
          '✅ SupabaseService.removePermanentBlock - Removed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.removePermanentBlock - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Task history operations
  Future<void> archiveCompletedTask(Map<String, dynamic> task) async {
    try {
      debugPrint(
          '🔵 SupabaseService.archiveCompletedTask - Archiving task: ${task['id']}');
      await client.from('task_history').insert({
        ...task,
        'archived_at': DateTime.now().toIso8601String(),
      });
      debugPrint(
          '✅ SupabaseService.archiveCompletedTask - Archived successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.archiveCompletedTask - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    }
  }

  /// Sync pending operations when coming online
  Future<void> syncPendingOperations() async {
    if (!isOnline) return;

    final pending = _cacheService.getPendingOperations();
    if (pending.isEmpty) return;

    debugPrint('🔄 Syncing ${pending.length} pending operations...');

    for (var op in pending) {
      try {
        final type = op['type'] as String;
        final entity = op['entity'] as String;
        final data = Map<String, dynamic>.from(op['data']);
        final key = op['key'] as String;

        switch (entity) {
          case 'task':
            await _syncTaskOperation(type, data);
            break;
          case 'default_restriction':
            await _syncDefaultRestrictionOperation(type, data);
            break;
          case 'permanent_block':
            await _syncPermanentBlockOperation(type, data);
            break;
        }

        await _cacheService.removePendingOperation(key);
        debugPrint('✅ Synced operation: $type $entity');
      } catch (e) {
        debugPrint('❌ Failed to sync operation: $e');
        // Keep in pending queue for retry
      }
    }
  }

  Future<void> _syncTaskOperation(
      String type, Map<String, dynamic> data) async {
    switch (type) {
      case 'create':
        await client.from('tasks').insert(data);
        break;
      case 'update':
        await client.from('tasks').update(data).eq('id', data['id']);
        break;
      case 'delete':
        await client.from('tasks').delete().eq('id', data['id']);
        break;
    }
  }

  Future<void> _syncDefaultRestrictionOperation(
      String type, Map<String, dynamic> data) async {
    switch (type) {
      case 'create':
        await client.from('default_restrictions').insert(data);
        break;
      case 'delete':
        if (data['type'] == 'app') {
          await client
              .from('default_restrictions')
              .delete()
              .eq('type', 'app')
              .eq('package_name', data['package_name']);
        } else {
          await client
              .from('default_restrictions')
              .delete()
              .eq('type', 'website')
              .eq('domain', data['domain']);
        }
        break;
    }
  }

  Future<void> _syncPermanentBlockOperation(
      String type, Map<String, dynamic> data) async {
    switch (type) {
      case 'create':
        await client.from('permanent_blocks').insert(data);
        break;
      case 'delete':
        if (data['type'] == 'app') {
          await client
              .from('permanent_blocks')
              .delete()
              .eq('type', 'app')
              .eq('package_name', data['package_name']);
        } else {
          await client
              .from('permanent_blocks')
              .delete()
              .eq('type', 'website')
              .eq('domain', data['domain']);
        }
        break;
    }
  }

  /// Cache restrictions for offline use (call after loading)
  Future<void> cacheRestrictions({
    required List<String> defaultApps,
    required List<String> defaultWebsites,
    required List<String> permanentApps,
    required List<String> permanentWebsites,
  }) async {
    await _cacheService.cacheDefaultRestrictions(
      apps: defaultApps,
      websites: defaultWebsites,
    );
    await _cacheService.cachePermanentBlocks(
      apps: permanentApps,
      websites: permanentWebsites,
    );
  }

  /// Check if there are pending operations
  bool get hasPendingOperations => _cacheService.hasPendingOperations();
}
