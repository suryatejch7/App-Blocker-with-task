import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../providers/restrictions_provider.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: _selectedIndex == 0
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Tasks',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.white.withOpacity(0.6),
                        ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restrictions',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Default restriction list',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: AppTheme.white.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
        actions: _selectedIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/settings'),
                ),
                const SizedBox(width: 8),
              ]
            : const [],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _TasksTab(),
          _RestrictionsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.block),
            label: 'Restrictions',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () => context.push('/add'),
              backgroundColor: AppTheme.blue,
              child: const Icon(Icons.add, color: AppTheme.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final allTasks = taskProvider.tasks;
        final rawTodayTasks = taskProvider.todayTasks;
        final rawFutureTasks = taskProvider.futureTasks;

        final todayTasks =
            rawTodayTasks.where((task) => !task.completed).toList();

        final futureTaskEntries = rawFutureTasks.entries
            .map((entry) {
              final filtered =
                  entry.value.where((task) => !task.completed).toList();
              return MapEntry(entry.key, filtered);
            })
            .where((entry) => entry.value.isNotEmpty)
            .toList();

        final completedTasks = allTasks
            .where((task) => task.completed)
            .toList()
          ..sort((a, b) {
            final aTime = a.completedAt ?? a.endTime;
            final bTime = b.completedAt ?? b.endTime;
            return bTime.compareTo(aTime);
          });

        if (todayTasks.isEmpty && futureTaskEntries.isEmpty && completedTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.task_alt,
                  size: 100,
                  color: AppTheme.blue.withOpacity(0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Tasks Yet',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap + to create your first task',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.white.withOpacity(0.6),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            if (todayTasks.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '${todayTasks.length} ${todayTasks.length == 1 ? 'task' : 'tasks'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.white.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...todayTasks.map((task) => _TaskCard(task: task)),
              const SizedBox(height: 24),
            ],
            ...futureTaskEntries.expand((entry) {
              final date = entry.key;
              final tasks = entry.value;
              return [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(date),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.white.withOpacity(0.6),
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...tasks.map((task) => _TaskCard(task: task)),
                const SizedBox(height: 24),
              ];
            }),
            if (completedTasks.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Completed Tasks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '${completedTasks.length} ${completedTasks.length == 1 ? 'task' : 'tasks'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.white.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...completedTasks.map((task) => _TaskCard(task: task)),
            ],
          ],
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final timeFormat = DateFormat('h:mm a');
    final isActive = task.isActive;
    final isOverdue = task.isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: InkWell(
        onTap: () => context.push('/edit', extra: task),
        onLongPress: () => _confirmDelete(context, taskProvider, task),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => taskProvider.toggleComplete(task.id),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: task.completed
                              ? AppTheme.blue
                              : AppTheme.white.withOpacity(0.5),
                          width: 2,
                        ),
                        color: task.completed
                            ? AppTheme.blue
                            : Colors.transparent,
                      ),
                      child: task.completed
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: AppTheme.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.title,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.completed
                                    ? AppTheme.white.withOpacity(0.6)
                                    : AppTheme.white,
                              ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.white,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: isOverdue
                        ? Colors.red
                        : AppTheme.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${timeFormat.format(task.startTime)} - ${timeFormat.format(task.endTime)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isOverdue
                              ? Colors.red
                              : AppTheme.white.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
              if (task.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(
                  task.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.white.withOpacity(0.7),
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (task.repeatSettings != 'none')
                    _TaskChip(
                      label: task.repeatSettings,
                      color: AppTheme.yellow,
                      icon: Icons.repeat,
                    ),
                  if (task.repeatSettings != 'none') const SizedBox(width: 8),
                  _TaskChip(
                    label: task.restrictionMode == 'default'
                        ? 'Default'
                        : 'Custom',
                    color: AppTheme.blue,
                    icon: Icons.lock,
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    _TaskChip(
                      label: 'Active',
                      color: AppTheme.blue,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _confirmDelete(BuildContext context, TaskProvider provider, Task task) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Task'),
      content: Text('Are you sure you want to delete "${task.title}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            provider.removeTask(task.id);
            Navigator.pop(context);
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

class _TaskChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _TaskChip({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _RestrictionsTab extends StatefulWidget {
  const _RestrictionsTab();

  @override
  State<_RestrictionsTab> createState() => _RestrictionsTabState();
}

class _RestrictionsTabState extends State<_RestrictionsTab> {
  // 0 = Apps, 1 = Websites
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<RestrictionsProvider>(
      builder: (context, provider, child) {
        final apps = provider.defaultRestrictedApps;
        final websites = provider.defaultRestrictedWebsites;
        final isApps = _selectedIndex == 0;
        final items = isApps ? apps : websites;

        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.blue),
          );
        }

        return Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _RestrictionsToggleButton(
                      selected: isApps,
                      icon: Icons.smartphone,
                      label: 'Apps (${apps.length})',
                      onTap: () => setState(() => _selectedIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RestrictionsToggleButton(
                      selected: !isApps,
                      icon: Icons.language,
                      label: 'Websites (${websites.length})',
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        isApps
                            ? 'No apps in default list'
                            : 'No websites in default list',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: AppTheme.white.withOpacity(0.6),
                            ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final value = items[index];
                        return _RestrictionItemCard(
                          isApp: isApps,
                          value: value,
                          onRemove: () {
                            if (isApps) {
                              provider.removeApp(value);
                            } else {
                              provider.removeWebsite(value);
                            }
                          },
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _selectedIndex == 0
                      ? _showAddAppsDialog(context, provider)
                      : _showAddWebsiteDialog(context, provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.blue,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(
                    _selectedIndex == 0 ? 'Add Apps' : 'Add Websites',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddAppsDialog(
      BuildContext context, RestrictionsProvider provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.blue),
      ),
    );

    try {
      final installedApps = await provider.getInstalledApps();
      if (!mounted) return;

      Navigator.pop(context); // close loading

      final selectedApps = await showDialog<List<String>>(
        context: context,
        builder: (context) => _DefaultAppSelectorDialog(
          installedApps: installedApps,
          alreadyRestricted: provider.defaultRestrictedApps,
        ),
      );

      if (selectedApps != null && selectedApps.isNotEmpty) {
        for (final app in selectedApps) {
          provider.addApp(app);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${selectedApps.length} app(s)'),
              backgroundColor: AppTheme.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading apps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      if (mounted) {
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

class _RestrictionsToggleButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RestrictionsToggleButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? AppTheme.blue : AppTheme.lightGray.withOpacity(0.8);
    final bgColor =
        selected ? AppTheme.blue.withOpacity(0.12) : Colors.transparent;
    final textColor = selected ? AppTheme.blue : AppTheme.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestrictionItemCard extends StatelessWidget {
  final bool isApp;
  final String value;
  final VoidCallback onRemove;

  const _RestrictionItemCard({
    required this.isApp,
    required this.value,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isApp ? Icons.phone_android : Icons.public,
              color: AppTheme.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.white,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.white.withOpacity(0.6),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultAppSelectorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> installedApps;
  final List<String> alreadyRestricted;

  const _DefaultAppSelectorDialog({
    required this.installedApps,
    required this.alreadyRestricted,
  });

  @override
  State<_DefaultAppSelectorDialog> createState() =>
      _DefaultAppSelectorDialogState();
}

class _DefaultAppSelectorDialogState extends State<_DefaultAppSelectorDialog> {
  final Set<String> _selectedApps = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredApps = widget.installedApps.where((app) {
      final packageName = app['packageName'] as String;
      final appName = app['name'] as String;
      if (widget.alreadyRestricted.contains(packageName)) return false;
      if (_searchQuery.isEmpty) return true;
      return packageName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          appName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.apps, color: AppTheme.yellow),
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
              decoration: const InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredApps.length,
                itemBuilder: (context, index) {
                  final app = filteredApps[index];
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
                    secondary:
                        const Icon(Icons.android, color: AppTheme.blue),
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
                          : () => Navigator.pop(
                                context,
                                _selectedApps.toList(),
                              ),
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
