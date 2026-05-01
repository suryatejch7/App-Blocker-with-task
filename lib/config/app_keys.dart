/// Central place for string constants used across storage, widgets, and
/// platform channels.
///
/// Keeping these keys in one place prevents subtle bugs from typos and makes
/// refactors safer.
class PrefsKeys {
  // SharedPreferences (Flutter-side)
  static const String apps = 'apps';
  static const String websites = 'websites';
  static const String themeMode = 'theme_mode';

  // Widget toggle queue (SharedPreferences)
  static const String lastWidgetToggleAtMs = 'last_widget_toggle_at_ms';
  static const String pendingWidgetToggles = 'pending_widget_toggles';

  // Legacy export keys (kept for backward compatibility)
  static const String legacyTasks = 'ls_tasks';
  static const String legacyDefaultApps = 'ls_default_apps';
  static const String legacyDefaultWebsites = 'ls_default_websites';
  static const String legacyPermanentApps = 'ls_permanent_apps';
  static const String legacyPermanentWebsites = 'ls_permanent_websites';
}

class HiveBoxKeys {
  static const String tasks = 'tasks_cache';
  static const String archivedTasks = 'archived_tasks_cache';
  static const String restrictions = 'restrictions_cache';
  static const String pendingOperations = 'pending_operations';
  static const String metadata = 'cache_metadata';
}

class HiveRestrictionsKeys {
  static const String defaultApps = 'default_apps';
  static const String defaultWebsites = 'default_websites';
  static const String permanentApps = 'permanent_apps';
  static const String permanentWebsites = 'permanent_websites';
}

class WidgetKeys {
  static const String appGroupId = 'group.habit_tracker_flutter';
  static const String androidWidgetName = 'TaskWidgetProvider';

  static const String tasksData = 'tasks_data';
  static const String taskCount = 'task_count';
  static const String nextTask = 'next_task';
  static const String lastUpdate = 'last_update';
  static const String widgetIsDark = 'widget_is_dark';
}

class PlatformChannelNames {
  static const String widgetActions = 'com.android.krama/widget_actions';
}
