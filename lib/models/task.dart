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
    List<String>? customRestrictedApps,
    List<String>? customRestrictedWebsites,
    this.completedAt,
  })  : customRestrictedApps = List<String>.from(customRestrictedApps ?? const []),
        customRestrictedWebsites =
            List<String>.from(customRestrictedWebsites ?? const []);

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
    return {
      'id': id,
      'title': title,
      'description': description,
      // Store as UTC in Supabase to avoid timezone drift. The app always
      // converts back to local time (IST) on read in fromJson.
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'completed': completed,
      'repeat_settings': repeatSettings,
      'restriction_mode': restrictionMode,
      'custom_restricted_apps': customRestrictedApps,
      'custom_restricted_websites': customRestrictedWebsites,
      'completed_at': completedAt?.toUtc().toIso8601String(),
    };
  }

  static Task fromJson(Map<String, dynamic> j) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    List<String> parseStringList(dynamic value) {
      if (value is! List) return const <String>[];
      return value.map((e) => e.toString()).toList();
    }

    final id = (j['id']?.toString() ?? '').trim();
    final title = (j['title']?.toString() ?? '').trim();
    final description = (j['description']?.toString() ?? '').trim();

    final startTimeRaw = j['start_time'] ?? j['startTime'];
    final endTimeRaw = j['end_time'] ?? j['endTime'];

    final startTimeParsed = parseDateTime(startTimeRaw);
    final endTimeParsed = parseDateTime(endTimeRaw);

    final now = DateTime.now();
    final startTimeUtc = (startTimeParsed ?? now.toUtc()).toUtc();
    final endTimeUtc = (endTimeParsed ?? startTimeUtc.add(const Duration(hours: 1))).toUtc();

    var startTimeLocal = startTimeUtc.toLocal();
    var endTimeLocal = endTimeUtc.toLocal();
    if (!endTimeLocal.isAfter(startTimeLocal)) {
      endTimeLocal = startTimeLocal.add(const Duration(hours: 1));
    }

    final completedAtRaw = j['completed_at'] ?? j['completedAt'];
    final completedAtParsed = parseDateTime(completedAtRaw)?.toLocal();

    return Task(
      id: id.isNotEmpty ? id : now.microsecondsSinceEpoch.toString(),
      title: title.isNotEmpty ? title : 'Untitled',
      description: description.isNotEmpty ? description : null,
      // Parse as local time (IST) - convert UTC from database to local
      startTime: startTimeLocal,
      endTime: endTimeLocal,
      completed: (j['completed'] is bool) ? (j['completed'] as bool) : false,
      repeatSettings: (j['repeat_settings'] ?? j['repeatSettings'] ?? 'none')
          .toString(),
      restrictionMode:
          (j['restriction_mode'] ?? j['restrictionMode'] ?? 'default').toString(),
      customRestrictedApps:
          parseStringList(j['custom_restricted_apps'] ?? j['customRestrictedApps']),
      customRestrictedWebsites: parseStringList(
          j['custom_restricted_websites'] ?? j['customRestrictedWebsites']),
      completedAt: completedAtParsed,
    );
  }
}

enum TaskRepeatMode {
  once,
  daily,
  weekly,
  custom,
}

enum TaskRestrictionMode {
  defaultMode('default'),
  custom('custom');

  const TaskRestrictionMode(this.storageValue);

  final String storageValue;

  static TaskRestrictionMode fromStorage(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'custom':
        return TaskRestrictionMode.custom;
      case 'default':
      default:
        return TaskRestrictionMode.defaultMode;
    }
  }
}
