// redundant code, will be removed in future updates


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../providers/restrictions_provider.dart';
import '../services/restriction_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class RestrictionsScreen extends StatefulWidget {
  const RestrictionsScreen({super.key});

  @override
  State<RestrictionsScreen> createState() => _RestrictionsScreenState();
}

class _RestrictionsScreenState extends State<RestrictionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompactWidth;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Default Restrictions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: compact,
          indicatorColor: AppTheme.yellow,
          labelColor: AppTheme.yellow,
          unselectedLabelColor: AppTheme.white,
          tabs: const [
            Tab(text: 'APPS', icon: Icon(Icons.apps)),
            Tab(text: 'WEBSITES', icon: Icon(Icons.language)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AppsTab(),
          _WebsitesTab(),
        ],
      ),
    );
  }
}

class _AppsTab extends StatelessWidget {
  const _AppsTab();

  @override
  Widget build(BuildContext context) {
    final scale = context.responsiveScale;
    final compact = context.isCompactWidth;
    return Consumer<RestrictionsProvider>(
      builder: (context, provider, child) {
        final restrictedApps = provider.defaultRestrictedApps;

        return Column(
          children: [
            // Header with count
            Container(
              padding: EdgeInsets.all(scale * 16),
              color: AppTheme.darkGray,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeader = constraints.maxWidth < 360 || compact;
                  final content = Row(
                    children: [
                      Icon(Icons.block,
                          color: AppTheme.yellow, size: scale * 20),
                      SizedBox(width: scale * 12),
                      Expanded(
                        child: Text(
                          '${restrictedApps.length} Blocked Apps',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  );

                  final addButton = ElevatedButton.icon(
                    onPressed: () => _showAddAppsDialog(context, provider),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: scale * 16,
                        vertical: scale * 8,
                      ),
                    ),
                  );

                  if (compactHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        content,
                        SizedBox(height: scale * 12),
                        Align(
                            alignment: Alignment.centerRight, child: addButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: content),
                      addButton,
                    ],
                  );
                },
              ),
            ),

            // List of restricted apps
            Expanded(
              child: restrictedApps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.apps,
                            size: 80,
                            color: AppTheme.blue.withAlpha(76),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No apps blocked',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Add" to block apps',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.white.withAlpha(153),
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: restrictedApps.length,
                      itemBuilder: (context, index) {
                        final appPackage = restrictedApps[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: Icon(Icons.android, color: AppTheme.blue),
                            title: Text(appPackage),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                provider.removeApp(appPackage);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Removed $appPackage'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddAppsDialog(
      BuildContext context, RestrictionsProvider provider) async {
    final restrictionService = RestrictionService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final installedApps = await restrictionService.getInstalledApps();
      if (!context.mounted) return;

      Navigator.pop(context); // Close loading dialog

      final selectedApps = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => MediaQuery.removeViewInsets(
          context: dialogContext,
          removeBottom: true,
          child: _AppSelectorDialog(
            installedApps: installedApps,
            alreadyRestricted: provider.defaultRestrictedApps,
          ),
        ),
      );

      if (selectedApps != null && selectedApps.isNotEmpty) {
        for (final app in selectedApps) {
          provider.addApp(app);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${selectedApps.length} app(s)'),
              backgroundColor: AppTheme.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading apps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _WebsitesTab extends StatelessWidget {
  const _WebsitesTab();

  @override
  Widget build(BuildContext context) {
    final scale = context.responsiveScale;
    final compact = context.isCompactWidth;
    return Consumer<RestrictionsProvider>(
      builder: (context, provider, child) {
        final restrictedWebsites = provider.defaultRestrictedWebsites;

        return Column(
          children: [
            // Header with count
            Container(
              padding: EdgeInsets.all(scale * 16),
              color: AppTheme.darkGray,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeader = constraints.maxWidth < 360 || compact;
                  final content = Row(
                    children: [
                      Icon(Icons.block,
                          color: AppTheme.yellow, size: scale * 20),
                      SizedBox(width: scale * 12),
                      Expanded(
                        child: Text(
                          '${restrictedWebsites.length} Blocked Websites',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  );

                  final addButton = ElevatedButton.icon(
                    onPressed: () => _showAddWebsiteDialog(context, provider),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: scale * 16,
                        vertical: scale * 8,
                      ),
                    ),
                  );

                  if (compactHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        content,
                        SizedBox(height: scale * 12),
                        Align(
                            alignment: Alignment.centerRight, child: addButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: content),
                      addButton,
                    ],
                  );
                },
              ),
            ),

            // List of restricted websites
            Expanded(
              child: restrictedWebsites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.language,
                            size: 80,
                            color: AppTheme.blue.withAlpha(76),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No websites blocked',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Add" to block websites',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.white.withAlpha(153),
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: restrictedWebsites.length,
                      itemBuilder: (context, index) {
                        final domain = restrictedWebsites[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: Icon(Icons.public, color: AppTheme.blue),
                            title: Text(domain),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                provider.removeWebsite(domain);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Removed $domain'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddWebsiteDialog(
      BuildContext context, RestrictionsProvider provider) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Website'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter domain or URL:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g., youtube.com or https://youtube.com',
                  prefixIcon: Icon(Icons.language),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a domain';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      provider.addWebsite(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${provider.extractDomain(result)}'),
            backgroundColor: AppTheme.blue,
          ),
        );
      }
    }
  }
}

class _AppSelectorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> installedApps;
  final List<String> alreadyRestricted;

  const _AppSelectorDialog({
    required this.installedApps,
    required this.alreadyRestricted,
  });

  @override
  State<_AppSelectorDialog> createState() => _AppSelectorDialogState();
}

class _AppSelectorDialogState extends State<_AppSelectorDialog> {
  final Set<String> _selectedApps = {};
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  late final List<Map<String, dynamic>> _allSelectableApps;
  List<Map<String, dynamic>> _filteredApps = const [];

  @override
  void initState() {
    super.initState();
    _allSelectableApps = widget.installedApps.where((app) {
      final packageName = app['packageName'] as String;
      return !widget.alreadyRestricted.contains(packageName);
    }).toList(growable: false);
    _filteredApps = _allSelectableApps;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final trimmed = query.trim().toLowerCase();
      if (trimmed.isEmpty) {
        setState(() => _filteredApps = _allSelectableApps);
        return;
      }

      final filtered = _allSelectableApps.where((app) {
        final packageName = (app['packageName'] as String).toLowerCase();
        final appName = (app['name'] as String).toLowerCase();
        return packageName.contains(trimmed) || appName.contains(trimmed);
      }).toList(growable: false);

      setState(() => _filteredApps = filtered);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetAnimationDuration: Duration.zero,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        height: MediaQuery.of(context).size.height * 0.78,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.apps, color: AppTheme.yellow),
                const SizedBox(width: 12),
                Text(
                  'Select Apps to Block',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredApps.length,
                itemBuilder: (context, index) {
                  final app = _filteredApps[index];
                  final packageName = app['packageName'] as String;
                  final appName = app['name'] as String;
                  final isSelected = _selectedApps.contains(packageName);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedApps.add(packageName);
                        } else {
                          _selectedApps.remove(packageName);
                        }
                      });
                    },
                    title: Text(appName),
                    subtitle: Text(
                      packageName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.white.withAlpha(153),
                      ),
                    ),
                    secondary: Icon(Icons.android, color: AppTheme.blue),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedApps.length} selected',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _selectedApps.isEmpty
                          ? null
                          : () =>
                              Navigator.pop(context, _selectedApps.toList()),
                      child: const Text('Add Selected'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
