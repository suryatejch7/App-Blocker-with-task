enum TaskRepeatMode {
  none,
  daily,
  weekly,
  custom;

  // Handles 'none', 'daily', 'weekly', 'custom', and 'custom:mon,tue...'
  static TaskRepeatMode fromString(String value) {
    if (value.startsWith('custom:')) return TaskRepeatMode.custom;
    switch (value) {
      case 'daily':
        return TaskRepeatMode.daily;
      case 'weekly':
        return TaskRepeatMode.weekly;
      case 'custom':
        return TaskRepeatMode.custom;
      case 'none':
      default:
        return TaskRepeatMode.none;
    }
  }

  String toJsonString() {
    switch (this) {
      case TaskRepeatMode.daily:
        return 'daily';
      case TaskRepeatMode.weekly:
        return 'weekly';
      case TaskRepeatMode.custom:
        return 'custom';
      case TaskRepeatMode.none:
      default:
        return 'none';
    }
  }
}

enum TaskRestrictionMode {
  defaultMode,
  custom;

  static TaskRestrictionMode fromString(String value) {
    if (value == 'custom') {
      return TaskRestrictionMode.custom;
    }
    return TaskRestrictionMode.defaultMode;
  }

  String toJsonString() {
    if (this == TaskRestrictionMode.custom) {
      return 'custom';
    }
    return 'default';
  }
}