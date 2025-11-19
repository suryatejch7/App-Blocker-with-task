import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/restriction_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _restrictionService = RestrictionService();
  bool _accessibilityGranted = false;
  bool _usageStatsGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _restrictionService.checkPermissions();
      setState(() {
        _accessibilityGranted = granted;
        _usageStatsGranted = granted; // Simplified for now
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

  @override
  Widget build(BuildContext context) {
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
                // Permissions Section
                Text(
                  'PERMISSIONS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.yellow,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
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
                  title: 'Usage Stats',
                  description:
                      'Required to detect which app is currently running',
                  icon: Icons.analytics,
                  isGranted: _usageStatsGranted,
                  onRequest: _requestPermissions,
                ),
                const SizedBox(height: 32),

                // App Info
                Text(
                  'ABOUT',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.blue,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.block,
                              color: AppTheme.yellow,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Productivity Blocker',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Version 1.0.0',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.white
                                              .withValues(alpha: 0.6),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Block distracting apps and websites during your focus time. Create time-bound tasks and let the app enforce your restrictions automatically.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppTheme.white.withValues(alpha: 0.8),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Restrictions Management
                Text(
                  'RESTRICTIONS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.blue,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.apps, color: AppTheme.yellow),
                        title: const Text('Manage Default Apps'),
                        subtitle:
                            const Text('Set which apps are blocked by default'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.push('/restrictions'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading:
                            const Icon(Icons.language, color: AppTheme.yellow),
                        title: const Text('Manage Default Websites'),
                        subtitle: const Text(
                            'Set which websites are blocked by default'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.push('/restrictions'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Danger Zone
                Text(
                  'DANGER ZONE',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning, color: Colors.red),
                    title: const Text('Clear All Data'),
                    subtitle: const Text('Remove all tasks and reset settings'),
                    trailing: const Icon(Icons.delete_forever, size: 24),
                    onTap: () => _showClearDataDialog(context),
                  ),
                ),
              ],
            ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your tasks and restrictions. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Clear all data
              Navigator.pop(context);
              try {
                // TODO: Add proper data clearing logic when provider supports it
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data clearing not yet implemented'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error clearing data: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear Data'),
          ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted
                    ? AppTheme.blue.withValues(alpha: 0.2)
                    : AppTheme.mediumGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isGranted ? AppTheme.blue : AppTheme.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isGranted ? AppTheme.blue : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isGranted ? 'GRANTED' : 'REQUIRED',
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.white.withValues(alpha: 0.6),
                        ),
                  ),
                  if (!isGranted) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: onRequest,
                      child: const Text('Grant Permission'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
