import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/restriction_service.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';

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

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppTheme.yellow : AppTheme.orange;

    final cardBorderShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: isDark
            ? AppTheme.lightGray.withValues(alpha: 0.2)
            : AppTheme.lightBorder,
      ),
    );

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
              padding: const EdgeInsets.all(16),
              children: [
                // Appearance Section
                _buildSectionHeader('APPEARANCE', accentColor),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: cardBorderShape,
                  child: SwitchListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: AppTheme.blue,
                        size: 24,
                      ),
                    ),
                    title: const Text('Dark Mode',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      isDark
                          ? 'Currently using dark theme'
                          : 'Currently using light theme',
                      style: const TextStyle(fontSize: 13),
                    ),
                    value: isDark,
                    onChanged: (value) => themeProvider.toggleTheme(),
                    activeTrackColor: AppTheme.blue.withValues(alpha: 0.5),
                    activeThumbColor: AppTheme.blue,
                  ),
                ),
                const SizedBox(height: 24),

                // Permissions Section
                _buildSectionHeader('PERMISSIONS', accentColor),
                _PermissionCard(
                  title: 'Accessibility Service',
                  description:
                      'Required to monitor and block apps when restrictions are active',
                  icon: Icons.accessibility_new,
                  isGranted: _accessibilityGranted,
                  onRequest: _requestPermissions,
                  cardBorderShape: cardBorderShape,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _PermissionCard(
                  title: 'Display Over Other Apps',
                  description:
                      'Required to block floating windows and picture-in-picture mode',
                  icon: Icons.picture_in_picture_alt,
                  isGranted: _overlayGranted,
                  onRequest: _requestOverlayPermission,
                  cardBorderShape: cardBorderShape,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // Data Backup Section
                _buildSectionHeader('DATA BACKUP', accentColor),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: cardBorderShape,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.backup,
                              color: AppTheme.blue, size: 24),
                        ),
                        title: const Text('Backup Data',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Save your tasks to device storage',
                            style: TextStyle(fontSize: 13)),
                        trailing: ElevatedButton(
                          onPressed: _backupData,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            backgroundColor:
                                AppTheme.blue.withValues(alpha: 0.1),
                            foregroundColor: AppTheme.blue,
                          ),
                          child: const Text('Backup'),
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: isDark
                              ? AppTheme.lightGray.withValues(alpha: 0.2)
                              : AppTheme.lightBorder),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.restore,
                              color: AppTheme.orange, size: 24),
                        ),
                        title: const Text('Restore Data',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Restore tasks from a backup file',
                            style: TextStyle(fontSize: 13)),
                        trailing: ElevatedButton(
                          onPressed: _restoreData,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            backgroundColor:
                                AppTheme.orange.withValues(alpha: 0.1),
                            foregroundColor: AppTheme.orange,
                          ),
                          child: const Text('Restore'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // About Section
                _buildSectionHeader('ABOUT', AppTheme.blue),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: cardBorderShape,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.yellow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.block,
                                color: AppTheme.yellow,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
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
                                const SizedBox(height: 4),
                                Text(
                                  'Version 2.0.1',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Block distracting apps and websites during your focus time. Create time-bound tasks and let the app enforce your restrictions automatically.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.8),
                                    height: 1.5,
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
  final RoundedRectangleBorder cardBorderShape;
  final bool isDark;

  const _PermissionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isGranted,
    required this.onRequest,
    required this.cardBorderShape,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final subtextColor = isDark
        ? AppTheme.white.withValues(alpha: 0.6)
        : AppTheme.lightTextSecondary;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: cardBorderShape.borderRadius,
        side: BorderSide(
          color: isGranted
              ? AppTheme.blue.withValues(alpha: 0.3)
              : cardBorderShape.side.color,
          width: isGranted ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: isGranted
                        ? AppTheme.blue.withValues(alpha: 0.1)
                        : (isDark ? AppTheme.mediumGray : AppTheme.lightBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isGranted
                        ? AppTheme.blue
                        : (isDark
                            ? AppTheme.white
                            : AppTheme.lightTextSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isGranted ? AppTheme.blue : Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isGranted ? 'GRANTED' : 'REQUIRED',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                            color: subtextColor, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isGranted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRequest,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppTheme.blue.withValues(alpha: 0.1),
                    foregroundColor: AppTheme.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Grant Permission',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
