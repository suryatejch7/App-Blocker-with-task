import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'offline_cache_service.dart';

/// BackupService for manual backup and restore of all task/restriction data.
///
/// Backups are JSON snapshots of all Hive data saved to device storage.
/// User can manually trigger backup/restore via Settings UI.
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  static const String _backupFileName = 'habit_tracker_backup.json';

  final _cacheService = OfflineCacheService();

  /// Create a manual backup JSON file in app documents directory
  Future<bool> backupToFile() async {
    try {
      if (!_cacheService.isInitialized) {
        await _cacheService.initialize();
      }

      // Collect all data from Hive
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'tasks': _cacheService.getCachedTasks(),
        'archived_tasks': _cacheService.getArchivedTasks(),
        'default_apps': _cacheService.getCachedDefaultApps(),
        'default_websites': _cacheService.getCachedDefaultWebsites(),
        'permanent_apps': _cacheService.getCachedPermanentApps(),
        'permanent_websites': _cacheService.getCachedPermanentWebsites(),
      };

      // Serialize to JSON
      final jsonString = jsonEncode(backupData);

      // Get app documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupFile = File('${appDocDir.path}/$_backupFileName');

      // Write to file
      await backupFile.writeAsString(jsonString);

      debugPrint('✅ BackupService: Backup created at ${backupFile.path}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ BackupService: Error creating backup: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Restore data from a user-selected backup file
  /// Returns true if restoration was successful
  Future<bool> restoreFromFile() async {
    try {
      if (!_cacheService.isInitialized) {
        await _cacheService.initialize();
      }

      // Let user pick a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Backup File',
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('⚠️ BackupService: User cancelled file selection');
        return false;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        debugPrint('❌ BackupService: Invalid file path');
        return false;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ BackupService: File does not exist: $filePath');
        return false;
      }

      // Read and parse JSON
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      debugPrint(
          '📦 BackupService: Loaded backup with data: ${backupData.keys}');

      // Restore data from JSON
      final tasks = (backupData['tasks'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final archivedTasks = (backupData['archived_tasks'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final defaultApps = (backupData['default_apps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final defaultWebsites = (backupData['default_websites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final permanentApps = (backupData['permanent_apps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final permanentWebsites =
          (backupData['permanent_websites'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

      // Clear existing data
      await _cacheService.clearAll();

      // Restore tasks
      await _cacheService.cacheTasks(tasks);
      for (final task in archivedTasks) {
        await _cacheService.archiveTask(task);
      }

      // Restore restrictions
      await _cacheService.saveRestrictions(
        defaultApps: defaultApps,
        defaultWebsites: defaultWebsites,
        permanentApps: permanentApps,
        permanentWebsites: permanentWebsites,
      );

      debugPrint(
          '✅ BackupService: Restoration complete. ${tasks.length} tasks restored.');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ BackupService: Error restoring from file: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get the path to the default backup file (if it exists)
  /// Useful for showing user where backup is saved
  Future<String?> getDefaultBackupPath() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupFile = File('${appDocDir.path}/$_backupFileName');
      if (await backupFile.exists()) {
        return backupFile.path;
      }
      return null;
    } catch (e) {
      debugPrint('❌ BackupService: Error getting backup path: $e');
      return null;
    }
  }

  /// Check if a backup file exists in app documents
  Future<bool> hasBackupFile() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupFile = File('${appDocDir.path}/$_backupFileName');
      return await backupFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get backup file creation time
  Future<DateTime?> getBackupFileTime() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupFile = File('${appDocDir.path}/$_backupFileName');
      if (await backupFile.exists()) {
        final stat = await backupFile.stat();
        return stat.modified;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
