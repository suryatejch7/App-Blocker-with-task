export 'task_enums.dart';

import 'task_enums.dart';

class Task {
  String id;
  String title;
  String? description;
  DateTime startTime;
  DateTime endTime;
  bool completed;
  TaskRepeatMode repeatMode; 
  String? customRepeatString; // to hold "mon,tue"
  TaskRestrictionMode restrictionMode;
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
    this.repeatMode = TaskRepeatMode.none,
    this.customRepeatString,
    this.restrictionMode = TaskRestrictionMode.defaultMode,
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

    return isAfterStart && isBeforeEnd;
  }

  Map<String, dynamic> toJson() {
    String repeatSettingsString = repeatMode.toJsonString();
    if (repeatMode == TaskRepeatMode.custom && customRepeatString != null) {
      repeatSettingsString = 'custom:$customRepeatString';
    }
    
    return {
      'id': id,
      'title': title,
      'description': description,
      // Store as UTC in Supabase to avoid timezone drift. The app always
      // converts back to local time (IST) on read in fromJson.
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'completed': completed,
      'repeat_settings': repeatSettingsString,
      'restriction_mode': restrictionMode.toJsonString(),
      'custom_restricted_apps': customRestrictedApps,
      'custom_restricted_websites': customRestrictedWebsites,
      'completed_at': completedAt?.toUtc().toIso8601String(),
    };
  }

  static Task fromJson(Map<String, dynamic> j) {
    final startTimeStr = j['start_time'] ?? j['startTime'];
    final endTimeStr = j['end_time'] ?? j['endTime'];

    final startTimeUtc = DateTime.parse(startTimeStr);
    final endTimeUtc = DateTime.parse(endTimeStr);
    final startTimeLocal = startTimeUtc.toLocal();
    final endTimeLocal = endTimeUtc.toLocal();
    
    String rawRepeat = j['repeat_settings'] ?? j['repeatSettings'] ?? 'none';
    String? customRepString;
    if (rawRepeat.startsWith('custom:')) {
      customRepString = rawRepeat.substring('custom:'.length);
    }

    return Task(
      id: j['id'] as String,
      title: j['title'] as String,
      description: j['description'] as String?,
      // Parse as local time (IST) - convert UTC from database to local
      startTime: startTimeLocal,
      endTime: endTimeLocal,
      completed: j['completed'] as bool? ?? false,
      repeatMode: TaskRepeatMode.fromString(rawRepeat),
      customRepeatString: customRepString,
      restrictionMode: TaskRestrictionMode.fromString(
          j['restriction_mode'] ?? j['restrictionMode'] ?? 'default'),
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
}
