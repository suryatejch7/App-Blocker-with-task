import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ExportService handles CSV and JSON export for data portability
class ExportService {
  /// Export all tasks as CSV
  static Future<File?> exportTasksAsCSV() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('ls_tasks') ?? '[]';
      final tasks = jsonDecode(tasksJson) as List;

      final csvBuffer = StringBuffer();
      csvBuffer.writeln(
          'ID,Title,Description,StartTime,EndTime,Completed,RepeatSettings,RestrictionMode');

      for (final task in tasks) {
        final id = (task as Map<String, dynamic>)['id'] ?? '';
        final title = task['title'] ?? '';
        final desc =
            (task['description'] ?? '').toString().replaceAll(',', ';');
        final start = task['start_time'] ?? '';
        final end = task['end_time'] ?? '';
        final completed = task['completed'] ?? false;
        final repeat = task['repeat_settings'] ?? 'none';
        final mode = task['restriction_mode'] ?? 'default';

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
      final prefs = await SharedPreferences.getInstance();
      final export = {
        'default_apps': jsonDecode(prefs.getString('ls_default_apps') ?? '[]'),
        'default_websites':
            jsonDecode(prefs.getString('ls_default_websites') ?? '[]'),
        'permanent_apps':
            jsonDecode(prefs.getString('ls_permanent_apps') ?? '[]'),
        'permanent_websites':
            jsonDecode(prefs.getString('ls_permanent_websites') ?? '[]'),
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
