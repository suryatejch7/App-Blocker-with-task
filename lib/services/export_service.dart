import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'offline_cache_service.dart';

/// ExportService handles CSV and JSON export for data portability
class ExportService {
  /// Export all tasks as CSV
  static Future<File?> exportTasksAsCSV() async {
    try {
      final offlineCacheService = OfflineCacheService();
      if (!offlineCacheService.isInitialized) {
        await offlineCacheService.initialize();
      }

      final tasks = offlineCacheService.getCachedTasks();

      final csvBuffer = StringBuffer();
      csvBuffer.writeln(
          'ID,Title,Description,StartTime,EndTime,Completed,RepeatSettings,RestrictionMode');

      for (final task in tasks) {
        final id = (task['id']?.toString() ?? '').trim();
        final title = (task['title']?.toString() ?? '').trim();
        final desc = (task['description']?.toString() ?? '')
            .replaceAll('"', '""')
            .replaceAll(',', ';');
        final start = task['start_time']?.toString() ?? '';
        final end = task['end_time']?.toString() ?? '';
        final completed = (task['completed'] is bool) ? task['completed'] : false;
        final repeat = task['repeat_settings']?.toString() ?? 'none';
        final mode = task['restriction_mode']?.toString() ?? 'default';

        csvBuffer.writeln(
            '$id,"$title","$desc","$start","$end",$completed,$repeat,$mode');
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${dir.path}/tasks_export_$timestamp.csv');
      await file.writeAsString(csvBuffer.toString(), flush: true);

      debugPrint('✅ ExportService.exportTasksAsCSV - Exported to ${file.path}');
      return file;
    } catch (e, stackTrace) {
      debugPrint('❌ ExportService.exportTasksAsCSV - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Export restrictions as JSON
  static Future<File?> exportRestrictionsAsJSON() async {
    try {
      final offlineCacheService = OfflineCacheService();
      if (!offlineCacheService.isInitialized) {
        await offlineCacheService.initialize();
      }

      final export = <String, dynamic>{
        'default_apps': offlineCacheService.getCachedDefaultApps(),
        'default_websites': offlineCacheService.getCachedDefaultWebsites(),
        'permanent_apps': offlineCacheService.getCachedPermanentApps(),
        'permanent_websites': offlineCacheService.getCachedPermanentWebsites(),
      };

      final dir = await getApplicationDocumentsDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${dir.path}/restrictions_export_$timestamp.json');
      await file.writeAsString(jsonEncode(export), flush: true);

      debugPrint(
          '✅ ExportService.exportRestrictionsAsJSON - Exported to ${file.path}');
      return file;
    } catch (e, stackTrace) {
      debugPrint('❌ ExportService.exportRestrictionsAsJSON - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return null;
    }
  }
}
