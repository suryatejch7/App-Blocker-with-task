import 'package:flutter/foundation.dart';

class Task {
  String id;
  String title;
  String? description;
  DateTime startTime;
  DateTime endTime;
  bool completed;
  String repeatSettings; // 'none', 'daily', 'weekly', 'custom'
  String restrictionMode; // 'default' or 'custom'
  List<String> customRestrictedApps;
  List<String> customRestrictedWebsites;
  DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.completed = false,
    this.repeatSettings = 'none',
    this.restrictionMode = 'default',
    this.customRestrictedApps = const [],
    this.customRestrictedWebsites = const [],
    this.completedAt,
  });

  bool get isOverdue {
    if (completed) return false;
    final now = DateTime.now();
    return now.isAfter(endTime);
  }

  bool get isActive {
    if (completed) return false;
    final now = DateTime.now();
    final isAfterStart =
        now.isAfter(startTime) || now.isAtSameMomentAs(startTime);
    final isBeforeEnd = now.isBefore(endTime);

    // Debug timezone comparison
    debugPrint('🕐 Task "$title" time check:');
    debugPrint('   Now (IST): $now');
    debugPrint('   Start (IST): $startTime');
    debugPrint('   End (IST): $endTime');
    debugPrint(
        '   Is after start? $isAfterStart | Is before end? $isBeforeEnd');
    debugPrint('   Active? ${isAfterStart && isBeforeEnd}');

    return isAfterStart && isBeforeEnd;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'completed': completed,
        'repeat_settings': repeatSettings,
        'restriction_mode': restrictionMode,
        'custom_restricted_apps': customRestrictedApps,
        'custom_restricted_websites': customRestrictedWebsites,
        'completed_at': completedAt?.toIso8601String(),
      };

  static Task fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        // Parse as local time (IST) - convert UTC from database to local
        startTime: DateTime.parse(j['start_time'] ?? j['startTime']).toLocal(),
        endTime: DateTime.parse(j['end_time'] ?? j['endTime']).toLocal(),
        completed: j['completed'] as bool? ?? false,
        repeatSettings: j['repeat_settings'] ?? j['repeatSettings'] ?? 'none',
        restrictionMode:
            j['restriction_mode'] ?? j['restrictionMode'] ?? 'default',
        customRestrictedApps: List<String>.from(
            j['custom_restricted_apps'] ?? j['customRestrictedApps'] ?? []),
        customRestrictedWebsites: List<String>.from(
            j['custom_restricted_websites'] ??
                j['customRestrictedWebsites'] ??
                []),
        completedAt: (j['completed_at'] ?? j['completedAt']) != null
            ? DateTime.parse(j['completed_at'] ?? j['completedAt']).toLocal()
            : null,
      );
}
