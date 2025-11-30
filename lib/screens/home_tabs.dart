import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final subtextColor =
        isDark ? AppTheme.white.withOpacity(0.6) : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 100, // Increased height for better spacing
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _selectedIndex == 0
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'My Tasks',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy')
                                  .format(DateTime.now()),
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Restrictions',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Default restriction list',
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                ),
                if (_selectedIndex == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: textColor,
                        size: 26,
                      ),
                      onPressed: () => context.push('/settings'),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Thin divider under the app header to visually separate it from content
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 1.5,
            color: isDark
                ? AppTheme.lightGray.withOpacity(0.65)
                : AppTheme.lightBorder,
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _TasksTab(),
          _RestrictionsTab(),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
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

        final completedTasks = allTasks.where((task) => task.completed).toList()
          ..sort((a, b) {
            final aTime = a.completedAt ?? a.endTime;
            final bTime = b.completedAt ?? b.endTime;
            return bTime.compareTo(aTime);
          });

        if (todayTasks.isEmpty &&
            futureTaskEntries.isEmpty &&
            completedTasks.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final subtextColor = isDark
              ? AppTheme.white.withOpacity(0.6)
              : AppTheme.lightTextSecondary;

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
                        color: subtextColor,
                      ),
                ),
              ],
            ),
          );
        }

        final listView = ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            if (todayTasks.isNotEmpty) ...[
              _buildSectionHeader(context, 'Today', todayTasks.length),
              const SizedBox(height: 12),
              ...todayTasks.map((task) => _TaskCard(task: task)),
              const SizedBox(height: 24),
            ],
            ...futureTaskEntries.expand((entry) {
              final date = entry.key;
              final tasks = entry.value;
              return [
                _buildSectionHeader(context,
                    DateFormat('EEEE, MMM d').format(date), tasks.length),
                const SizedBox(height: 12),
                ...tasks.map((task) => _TaskCard(task: task)),
                const SizedBox(height: 24),
              ];
            }),
            if (completedTasks.isNotEmpty) ...[
              _buildSectionHeader(context, 'Completed', completedTasks.length,
                  isCompleted: true),
              const SizedBox(height: 12),
              ...completedTasks.map((task) => _TaskCard(task: task)),
            ],
          ],
        );

        if (todayTasks.isEmpty &&
            futureTaskEntries.isEmpty &&
            completedTasks.isEmpty) {
          final isDark2 = Theme.of(context).brightness == Brightness.dark;
          final subtextColor2 = isDark2
              ? AppTheme.white.withOpacity(0.6)
              : AppTheme.lightTextSecondary;

          return RefreshIndicator(
            onRefresh: () => taskProvider.refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: subtextColor2),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        }

        return RefreshIndicator(
            onRefresh: () => taskProvider.refresh(), child: listView);
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count,
      {bool isCompleted = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final subtextColor =
        isDark ? AppTheme.white.withOpacity(0.6) : AppTheme.lightTextSecondary;
    final accentColor = isDark ? AppTheme.yellow : AppTheme.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withOpacity(0.15)
                  : accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.calendar_today,
              size: 18,
              color: isCompleted ? Colors.green : accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: subtextColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count ${count == 1 ? 'task' : 'tasks'}',
              style: TextStyle(
                color: subtextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkGray : AppTheme.lightCard;
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final subtextColor =
        isDark ? AppTheme.white.withOpacity(0.6) : AppTheme.lightTextSecondary;
    final accentColor = isDark ? AppTheme.yellow : AppTheme.orange;

    final borderColor = isOverdue
        ? Colors.red
        : (isDark ? AppTheme.lightGray : AppTheme.lightBorder);
    final borderWidth = isOverdue ? 1.6 : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
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
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      taskProvider.toggleComplete(task.id);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: task.completed ? AppTheme.blue : subtextColor,
                          width: 2,
                        ),
                        color:
                            task.completed ? AppTheme.blue : Colors.transparent,
                      ),
                      child: task.completed
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: AppTheme.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.completed ? subtextColor : textColor,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: textColor,
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
                    color: isOverdue ? Colors.red : subtextColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${timeFormat.format(task.startTime)} - ${timeFormat.format(task.endTime)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isOverdue ? Colors.red : subtextColor,
                        ),
                  ),
                ],
              ),
              if (task.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(
                  task.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtextColor,
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
                      color: accentColor,
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
                      color: accentColor,
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
  // false = Default (task-based), true = Permanent (always blocked)
  bool _showPermanent = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor =
        isDark ? AppTheme.white.withOpacity(0.6) : AppTheme.lightTextSecondary;

    return Consumer<RestrictionsProvider>(
      builder: (context, provider, child) {
        final defaultApps = provider.defaultRestrictedApps;
        final defaultWebsites = provider.defaultRestrictedWebsites;
        final permanentApps = provider.permanentlyBlockedApps;
        final permanentWebsites = provider.permanentlyBlockedWebsites;

        final isApps = _selectedIndex == 0;

        // Select the appropriate list based on mode
        final apps = _showPermanent ? permanentApps : defaultApps;
        final websites = _showPermanent ? permanentWebsites : defaultWebsites;
        final items = isApps ? apps : websites;

        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.blue),
          );
        }

        return Column(
          children: [
            const SizedBox(height: 8),
            // Mode selector: Default vs Permanent
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkGray : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.lightGray : AppTheme.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showPermanent = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_showPermanent
                                ? AppTheme.blue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: !_showPermanent
                                    ? AppTheme.white
                                    : subtextColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Task-Based',
                                style: TextStyle(
                                  color: !_showPermanent
                                      ? AppTheme.white
                                      : subtextColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showPermanent = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _showPermanent
                                ? Colors.red
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.block,
                                size: 16,
                                color: _showPermanent
                                    ? AppTheme.white
                                    : subtextColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Always Block',
                                style: TextStyle(
                                  color: _showPermanent
                                      ? AppTheme.white
                                      : subtextColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Apps/Websites toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  ? RefreshIndicator(
                      onRefresh: () => provider.refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height - 280,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _showPermanent
                                        ? Icons.block
                                        : Icons.timer_outlined,
                                    size: 48,
                                    color: subtextColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _showPermanent
                                        ? (isApps
                                            ? 'No permanently blocked apps'
                                            : 'No permanently blocked websites')
                                        : (isApps
                                            ? 'No apps in default list'
                                            : 'No websites in default list'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: subtextColor),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _showPermanent
                                        ? 'These will be blocked 24/7'
                                        : 'These are blocked during active tasks',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: subtextColor),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => provider.refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final value = items[index];
                          return _RestrictionItemCard(
                            isApp: isApps,
                            value: value,
                            isPermanent: _showPermanent,
                            onRemove: () {
                              if (_showPermanent) {
                                if (isApps) {
                                  provider.removePermanentApp(value);
                                } else {
                                  provider.removePermanentWebsite(value);
                                }
                              } else {
                                if (isApps) {
                                  provider.removeApp(value);
                                } else {
                                  provider.removeWebsite(value);
                                }
                              }
                            },
                          );
                        },
                      ),
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
                      ? _showAddAppsDialog(provider, _showPermanent)
                      : _showAddWebsiteDialog(provider, _showPermanent),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _showPermanent ? Colors.red : AppTheme.blue,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(_showPermanent ? Icons.block : Icons.add),
                  label: Text(
                    _showPermanent
                        ? (_selectedIndex == 0
                            ? 'Block App Forever'
                            : 'Block Website Forever')
                        : (_selectedIndex == 0 ? 'Add Apps' : 'Add Websites'),
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
      RestrictionsProvider provider, bool isPermanent) async {
    final ctx = context;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.blue),
      ),
    );

    try {
      final installedApps = await provider.getInstalledApps();
      if (!mounted) return;

      Navigator.of(ctx).pop(); // close loading

      // Exclude already blocked apps based on mode
      final alreadyBlocked = isPermanent
          ? provider.permanentlyBlockedApps
          : provider.defaultRestrictedApps;

      if (!mounted) return;
      final selectedApps = await showDialog<List<String>>(
        context: ctx,
        builder: (dialogContext) => _DefaultAppSelectorDialog(
          installedApps: installedApps,
          alreadyRestricted: alreadyBlocked,
          isPermanent: isPermanent,
        ),
      );

      if (selectedApps != null && selectedApps.isNotEmpty) {
        for (final app in selectedApps) {
          if (isPermanent) {
            provider.addPermanentApp(app);
          } else {
            provider.addApp(app);
          }
        }
        if (!mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(isPermanent
                ? 'Permanently blocked ${selectedApps.length} app(s)'
                : 'Added ${selectedApps.length} app(s)'),
            backgroundColor: isPermanent ? Colors.red : AppTheme.blue,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(ctx).pop(); // close loading
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Error loading apps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddWebsiteDialog(
      RestrictionsProvider provider, bool isPermanent) async {
    final ctx = context;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: Text(isPermanent ? 'Block Website Forever' : 'Add Website'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter domain or URL:',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            style: isPermanent
                ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(isPermanent ? 'Block Forever' : 'Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (isPermanent) {
        provider.addPermanentWebsite(result);
      } else {
        provider.addWebsite(result);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(isPermanent
              ? 'Permanently blocked ${provider.extractDomain(result)}'
              : 'Added ${provider.extractDomain(result)}'),
          backgroundColor: isPermanent ? Colors.red : AppTheme.blue,
        ),
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorder =
        isDark ? AppTheme.lightGray.withOpacity(0.8) : AppTheme.lightBorder;
    final defaultTextColor = isDark ? AppTheme.white : AppTheme.lightText;

    final borderColor = selected ? AppTheme.blue : defaultBorder;
    final bgColor =
        selected ? AppTheme.blue.withOpacity(0.12) : Colors.transparent;
    final textColor = selected ? AppTheme.blue : defaultTextColor;

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
  final bool isPermanent;
  final VoidCallback onRemove;

  const _RestrictionItemCard({
    required this.isApp,
    required this.value,
    this.isPermanent = false,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkGray : AppTheme.lightCard;
    final borderColor = isPermanent
        ? Colors.red.withOpacity(0.5)
        : (isDark ? AppTheme.lightGray : AppTheme.lightBorder);
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final subtextColor =
        isDark ? AppTheme.white.withOpacity(0.6) : AppTheme.lightTextSecondary;
    final accentColor = isPermanent ? Colors.red : AppTheme.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isPermanent ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPermanent
                  ? Icons.block
                  : (isApp ? Icons.phone_android : Icons.public),
              color: accentColor,
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
                        value,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPermanent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '24/7',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isPermanent ? 'Always blocked' : value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtextColor,
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
  final bool isPermanent;

  const _DefaultAppSelectorDialog({
    required this.installedApps,
    required this.alreadyRestricted,
    this.isPermanent = false,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor =
        isDark ? AppTheme.white.withOpacity(0.6) : AppTheme.lightTextSecondary;
    final accentColor = widget.isPermanent ? Colors.red : AppTheme.blue;

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
                Icon(
                  widget.isPermanent ? Icons.block : Icons.apps,
                  color: accentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isPermanent
                        ? 'Block Apps Forever'
                        : 'Select Apps to Block',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (widget.isPermanent) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These apps will be blocked 24/7, regardless of tasks',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    activeColor: accentColor,
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
                        color: subtextColor,
                      ),
                    ),
                    secondary: Icon(Icons.android, color: accentColor),
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
                      style: widget.isPermanent
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Colors.red)
                          : null,
                      child: Text(widget.isPermanent
                          ? 'Block Forever'
                          : 'Add Selected'),
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
