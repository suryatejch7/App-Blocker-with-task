import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';
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
import 'services/home_widget_service.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'utils/responsive.dart';

void main() async {
  debugPrint = (String? message, {int? wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Home Widget Service
  try {
    await HomeWidgetService().initialize();
  } catch (_) {}

  runApp(const HabitApp());
}

class HabitApp extends StatefulWidget {
  const HabitApp({super.key});

  @override
  State<HabitApp> createState() => _HabitAppState();
}

class _HabitAppState extends State<HabitApp> {
  late final GoRouter _router;
  StreamSubscription<Uri?>? _sub;
  static const _widgetChannel =
      MethodChannel('com.android.krama/widget_actions');

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
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

    // Handle cold start URI
    HomeWidgetService().getWidgetClickUri().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Handle resume URI
    _sub = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingWidgetPayload();
    });
  }

  void _checkPendingWidgetPayload() async {
    try {
      final payload =
          await _widgetChannel.invokeMethod('consumePendingWidgetPayload');
      if (payload != null && payload is Map) {
        final uriString = payload['uri'] as String?;
        if (uriString != null) {
          _handleDeepLink(Uri.parse(uriString));
        }
      }
    } catch (e) {
      debugPrint('Error getting pending payload: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    // Delay routing to ensure GoRouter has settled its initial navigation stack
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      debugPrint('🔔 _handleDeepLink: ${uri.toString()}');
      debugPrint('🔔 uri.scheme = ${uri.scheme}, uri.host = ${uri.host}');
      if (uri.host == 'add-task') {
        debugPrint('👉 Action is add-task, pushing /add');
        _router.push('/add');
      } else if (uri.host == 'open-app') {
        debugPrint('👉 Action is open-app, just bring to foreground');
        // Just bringing app to foreground is enough
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            title: 'Krama',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
            builder: (context, child) {
              final scale = context.responsiveScale;
              final mediaQuery = MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              );
              return MediaQuery(
                data: mediaQuery,
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
