import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/task_provider.dart';
import 'providers/apps_provider.dart';
import 'providers/websites_provider.dart';
import 'providers/restrictions_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_tabs.dart';
import 'screens/add_task_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_apps_screen.dart';
import 'screens/add_website_screen.dart';
import 'screens/restrictions_screen.dart';
import 'screens/edit_task_screen.dart';
import 'models/task.dart';
import 'services/supabase_service.dart';
import 'services/offline_cache_service.dart';
import 'services/connectivity_service.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';

void main() async {
  debugPrint('🚀 ========== APP STARTING ==========');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ Flutter binding initialized');

  // Initialize offline cache service (Hive)
  try {
    debugPrint('🔵 Initializing offline cache...');
    await OfflineCacheService().initialize();
    debugPrint('✅ Offline cache initialized');
  } catch (e, stackTrace) {
    debugPrint('❌ Failed to initialize offline cache: $e');
    debugPrint('📍 Stack trace: $stackTrace');
  }

  // Initialize connectivity service
  try {
    debugPrint('🔵 Initializing connectivity service...');
    await ConnectivityService().initialize();
    debugPrint('✅ Connectivity service initialized');
  } catch (e, stackTrace) {
    debugPrint('❌ Failed to initialize connectivity service: $e');
    debugPrint('📍 Stack trace: $stackTrace');
  }

  // Initialize Supabase
  try {
    debugPrint('🔵 Initializing Supabase...');
    await SupabaseService.initialize();
    debugPrint('✅ Supabase initialized successfully');
    debugPrint('🌐 Supabase URL: ${SupabaseService.supabaseUrl}');
  } catch (e, stackTrace) {
    debugPrint('❌ Failed to initialize Supabase: $e');
    debugPrint('📍 Stack trace: $stackTrace');
  }

  debugPrint('🚀 Running app...');
  runApp(const HabitApp());
}

class HabitApp extends StatelessWidget {
  const HabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (c, s) => const HomeTabs()),
        GoRoute(path: '/add', builder: (c, s) => const AddTaskScreen()),
        GoRoute(
          path: '/edit',
          builder: (c, s) => EditTaskScreen(task: s.extra as Task?),
        ),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        GoRoute(path: '/apps/add', builder: (c, s) => const AddAppsScreen()),
        GoRoute(
            path: '/websites/add', builder: (c, s) => const AddWebsiteScreen()),
        GoRoute(
            path: '/restrictions',
            builder: (c, s) => const RestrictionsScreen()),
      ],
    );
    return MultiProvider(
      providers: [
        // Theme provider first
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Restrictions provider
        ChangeNotifierProvider(create: (_) => RestrictionsProvider()),
        // Task provider with access to RestrictionsProvider
        ChangeNotifierProxyProvider<RestrictionsProvider, TaskProvider>(
          create: (_) => TaskProvider(),
          update: (context, restrictionsProvider, taskProvider) {
            if (taskProvider != null) {
              // Set up the callback to sync restrictions when they change
              restrictionsProvider.onRestrictionsChanged = (
                defaultApps,
                defaultWebsites,
                permanentApps,
                permanentWebsites,
              ) {
                debugPrint(
                    '🔗 RestrictionsProvider notified TaskProvider of changes');
                taskProvider.syncRestrictions(
                  defaultApps,
                  defaultWebsites,
                  permanentApps,
                  permanentWebsites,
                );
              };
              // Do initial sync
              taskProvider.syncRestrictions(
                restrictionsProvider.defaultRestrictedApps,
                restrictionsProvider.defaultRestrictedWebsites,
                restrictionsProvider.permanentlyBlockedApps,
                restrictionsProvider.permanentlyBlockedWebsites,
              );
            }
            return taskProvider ?? TaskProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => AppsProvider()),
        ChangeNotifierProvider(create: (_) => WebsitesProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'Productivity Blocker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
