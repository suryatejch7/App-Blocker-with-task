import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/restriction_service.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _restrictionService = RestrictionService();
  final _backupService = BackupService();
  bool _accessibilityGranted = false;
  bool _overlayGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _restrictionService.checkPermissions();
      final overlayGranted = await _restrictionService.checkOverlayPermission();
      setState(() {
        _accessibilityGranted = granted;
        _overlayGranted = overlayGranted;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      await _restrictionService.requestPermissions();
      // Wait a bit for user to grant permissions
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting permissions: $e')),
        );
      }
    }
  }

  Future<void> _requestOverlayPermission() async {
    try {
      await _restrictionService.requestOverlayPermission();
      // Wait a bit for user to grant permissions
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting overlay permission: $e')),
        );
      }
    }
  }

  Future<void> _backupData() async {
    try {
      final success = await _backupService.backupToFile();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup created successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to create backup'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Backup error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _restoreData() async {
    try {
      final success = await _backupService.restoreFromFile();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data restored successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Restore cancelled or no file selected'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Restore error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppTheme.yellow : AppTheme.orange;
    final scale = context.responsiveScale;
    final compact = context.isCompactWidth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(scale * 16),
              children: [
                // Appearance Section
                Text(
                  'APPEARANCE',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: scale * 16),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(scale * 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compactCard =
                            constraints.maxWidth < 360 || compact;
                        final appearanceInfo = Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(scale * 12),
                              decoration: BoxDecoration(
                                color: AppTheme.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(scale * 8),
                              ),
                              child: Icon(
                                isDark ? Icons.dark_mode : Icons.light_mode,
                                color: AppTheme.blue,
                                size: scale * 28,
                              ),
                            ),
                            SizedBox(width: scale * 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dark Mode',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  SizedBox(height: scale * 4),
                                  Text(
                                    isDark
                                        ? 'Currently using dark theme'
                                        : 'Currently using light theme',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withOpacity(0.6),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        if (compactCard) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              appearanceInfo,
                              SizedBox(height: scale * 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Switch(
                                  value: isDark,
                                  onChanged: (value) =>
                                      themeProvider.toggleTheme(),
                                  activeThumbColor: AppTheme.blue,
                                  activeTrackColor:
                                      AppTheme.blue.withOpacity(0.5),
                                  inactiveThumbColor: isDark
                                      ? AppTheme.white
                                      : AppTheme.lightTextSecondary,
                                  inactiveTrackColor: isDark
                                      ? AppTheme.lightGray
                                      : AppTheme.lightBorder,
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: appearanceInfo),
                            Switch(
                              value: isDark,
                              onChanged: (value) => themeProvider.toggleTheme(),
                              activeThumbColor: AppTheme.blue,
                              activeTrackColor: AppTheme.blue.withOpacity(0.5),
                              inactiveThumbColor: isDark
                                  ? AppTheme.white
                                  : AppTheme.lightTextSecondary,
                              inactiveTrackColor: isDark
                                  ? AppTheme.lightGray
                                  : AppTheme.lightBorder,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: scale * 32),

                // Permissions Section
                Text(
                  'PERMISSIONS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: scale * 16),
                _PermissionCard(
                  title: 'Accessibility Service',
                  description:
                      'Required to monitor and block apps when restrictions are active',
                  icon: Icons.accessibility_new,
                  isGranted: _accessibilityGranted,
                  onRequest: _requestPermissions,
                ),
                const SizedBox(height: 12),
                _PermissionCard(
                  title: 'Display Over Other Apps',
                  description:
                      'Required to block floating windows and picture-in-picture mode',
                  icon: Icons.picture_in_picture_alt,
                  isGranted: _overlayGranted,
                  onRequest: _requestOverlayPermission,
                ),
                const SizedBox(height: 32),

                // Data Backup Section
                Text(
                  'DATA BACKUP',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: scale * 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backup Your Data',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a backup of all your tasks and settings to save them to your device storage.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(0.6),
                                  ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _backupData(),
                          icon: const Icon(Icons.backup),
                          label: const Text('Create Backup'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: scale * 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Restore from Backup',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Restore all your tasks and settings from a previously saved backup file.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(0.6),
                                  ),
                        ),
                        SizedBox(height: scale * 12),
                        ElevatedButton.icon(
                          onPressed: () => _restoreData(),
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore Backup'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: scale * 32),
                Text(
                  'ABOUT',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.blue,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: scale * 16),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(scale * 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compactAbout =
                                constraints.maxWidth < 360 || compact;
                            final icon = Icon(
                              Icons.block,
                              color: AppTheme.yellow,
                              size: scale * 32,
                            );
                            final details = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Krama',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                SizedBox(height: scale * 4),
                                Text(
                                  'Version 2.0.0',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withOpacity(0.6),
                                      ),
                                ),
                              ],
                            );

                            if (compactAbout) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  icon,
                                  SizedBox(height: scale * 12),
                                  details,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                icon,
                                SizedBox(width: scale * 16),
                                Expanded(child: details),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: scale * 16),
                        Text(
                          'Block distracting apps and websites during your focus time. Create time-bound tasks and let the app enforce your restrictions automatically.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withOpacity(0.8),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isGranted;
  final VoidCallback onRequest;

  const _PermissionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isGranted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor =
        isDark ? AppTheme.white.withOpacity(0.6) : AppTheme.lightTextSecondary;
    final scale = context.responsiveScale;
    final compact = context.isCompactWidth;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(scale * 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactCard = compact || constraints.maxWidth < 360;

            final leading = Container(
              padding: EdgeInsets.all(scale * 12),
              decoration: BoxDecoration(
                color: isGranted
                    ? AppTheme.blue.withOpacity(0.2)
                    : (isDark ? AppTheme.mediumGray : AppTheme.lightBorder),
                borderRadius: BorderRadius.circular(scale * 8),
              ),
              child: Icon(
                icon,
                color: isGranted
                    ? AppTheme.blue
                    : (isDark ? AppTheme.white : AppTheme.lightTextSecondary),
                size: scale * 28,
              ),
            );

            final titleRow = Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: scale * 8,
                    vertical: scale * 4,
                  ),
                  decoration: BoxDecoration(
                    color: isGranted ? AppTheme.blue : Colors.red,
                    borderRadius: BorderRadius.circular(scale * 4),
                  ),
                  child: Text(
                    isGranted ? 'GRANTED' : 'REQUIRED',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: scale * 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleRow,
                SizedBox(height: scale * 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtextColor,
                      ),
                ),
                if (!isGranted) ...[
                  SizedBox(height: scale * 12),
                  ElevatedButton(
                    onPressed: onRequest,
                    child: const Text('Grant Permission'),
                  ),
                ],
              ],
            );

            if (compactCard) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  SizedBox(height: scale * 12),
                  details,
                ],
              );
            }

            return Row(
              children: [
                leading,
                SizedBox(width: scale * 16),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}
