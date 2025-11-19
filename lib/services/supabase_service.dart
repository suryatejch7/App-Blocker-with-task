import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'https://cwupmrfxwdqagvhyqnen.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dXBtcmZ4d2RxYWd2aHlxbmVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1NTUzNjQsImV4cCI6MjA3OTEzMTM2NH0.OOdNix-zFdPFyALRkasCC8X60x0J2fkM6I1drRYpC5c';

  SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Tasks table operations
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      debugPrint(
          '🔵 SupabaseService.getTasks - Fetching tasks from database...');
      final response = await client
          .from('tasks')
          .select()
          .order('start_time', ascending: true);
      debugPrint(
          '✅ SupabaseService.getTasks - Fetched ${response.length} tasks');
      debugPrint('📊 Response data: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.getTasks - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> insertTask(Map<String, dynamic> task) async {
    try {
      debugPrint('🔵 SupabaseService.insertTask - Attempting to insert task');
      debugPrint('🔵 Task ID: ${task['id']}');
      debugPrint('🔵 Task title: ${task['title']}');
      debugPrint('🔵 Full task data: $task');
      debugPrint('🌐 Supabase URL: $supabaseUrl');
      debugPrint('🔑 Has anon key: ${supabaseAnonKey.isNotEmpty}');

      final response = await client.from('tasks').insert(task).select();

      debugPrint(
          '✅ SupabaseService.insertTask - SUCCESS! Task saved to database');
      debugPrint('📊 Response: $response');
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ SupabaseService.insertTask - FAILED! ❌❌❌');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error message: $e');
      debugPrint('❌ Task data that failed: $task');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateTask(String id, Map<String, dynamic> task) async {
    try {
      debugPrint('🔵 SupabaseService.updateTask - Updating task ID: $id');
      debugPrint('🔵 Update data: $task');
      await client.from('tasks').update(task).eq('id', id);
      debugPrint('✅ SupabaseService.updateTask - Task updated successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.updateTask - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      debugPrint('🔵 SupabaseService.deleteTask - Deleting task ID: $id');
      await client.from('tasks').delete().eq('id', id);
      debugPrint('✅ SupabaseService.deleteTask - Task deleted successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.deleteTask - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Restrictions table operations
  Future<List<String>> getDefaultRestrictedApps() async {
    try {
      debugPrint('🔵 SupabaseService.getDefaultRestrictedApps - Fetching...');
      final response = await client
          .from('default_restrictions')
          .select('package_name')
          .eq('type', 'app');
      final apps =
          (response as List).map((e) => e['package_name'] as String).toList();
      debugPrint(
          '✅ SupabaseService.getDefaultRestrictedApps - Fetched ${apps.length} apps');
      debugPrint('📊 Apps: $apps');
      return apps;
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.getDefaultRestrictedApps - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<String>> getDefaultRestrictedWebsites() async {
    try {
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
      debugPrint('📊 Websites: $websites');
      return websites;
    } catch (e, stackTrace) {
      debugPrint('❌ SupabaseService.getDefaultRestrictedWebsites - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> addDefaultRestriction(String type, String value) async {
    try {
      debugPrint(
          '🔵 SupabaseService.addDefaultRestriction - Type: $type, Value: $value');

      final data = {
        'type': type,
        if (type == 'app') 'package_name': value,
        if (type == 'website') 'domain': value,
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('🔵 Restriction data to insert: $data');
      debugPrint('🌐 Target URL: $supabaseUrl/rest/v1/default_restrictions');

      final response =
          await client.from('default_restrictions').insert(data).select();

      debugPrint('✅ SupabaseService.addDefaultRestriction - SUCCESS!');
      debugPrint('📊 Response: $response');
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ SupabaseService.addDefaultRestriction - FAILED! ❌❌❌');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error message: $e');
      debugPrint('❌ Restriction data that failed: $value');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> removeDefaultRestriction(String type, String value) async {
    try {
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
}
