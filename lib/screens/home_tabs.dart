import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../providers/restrictions_provider.dart';
import '../models/task.dart';
import '../services/overlay_toast_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

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
      isDark ? AppTheme.white.withValues(alpha: 0.6) : AppTheme.lightTextSecondary;
    final scale = context.responsiveScale;
    final isCompact = context.isCompactWidth;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: isCompact ? 92 : 104,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              scale * 20,
              scale * 12,
              scale * 20,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _selectedIndex == 0
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'My Tasks',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: scale * 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: scale * 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                DateFormat('EEEE, MMMM d, yyyy')
                                    .format(DateTime.now()),
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: scale * 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Restrictions',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: scale * 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: scale * 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Default restriction list',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: scale * 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                if (_selectedIndex == 0)
                  Padding(
                    padding: EdgeInsets.only(top: scale * 8),
                    child: IconButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: textColor,
                        size: scale * 26,
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
                ? AppTheme.lightGray.withValues(alpha: 0.65)
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

class _TasksTab extends StatefulWidget {
  const _TasksTab();

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  String? _activeStripTab;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final allTasks = taskProvider.tasks;
        final rawTodayTasks = taskProvider.todayTasks;
        final rawFutureTasks = taskProvider.futureTasks;

        final todayTasks =
            rawTodayTasks.where((task) => !task.completed).toList()
              ..sort((a, b) {
                // Keep overdue and still-incomplete tasks at the top.
                if (a.isOverdue != b.isOverdue) {
                  return a.isOverdue ? -1 : 1;
                }
                return a.startTime.compareTo(b.startTime);
              });

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

        // Check for empty state once - always use RefreshIndicator for pull-to-refresh
        final isEmpty = todayTasks.isEmpty &&
            futureTaskEntries.isEmpty &&
            completedTasks.isEmpty;

        if (isEmpty) {
          return RefreshIndicator(
            onRefresh: () => taskProvider.refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: _EmptyTasksState(),
                ),
              ],
            ),
          );
        }

        final listView = ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            if (todayTasks.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'Today',
                todayTasks.length,
                isExpanded: true,
                isCollapsible: false,
              ),
              const SizedBox(height: 12),
              ...todayTasks.map((task) => _TaskCard(task: task)),
              const SizedBox(height: 14),
            ],
            if (completedTasks.isNotEmpty || futureTaskEntries.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (completedTasks.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildStripItem(
                            context: context,
                            icon: Icons.check_circle_outline,
                            label: 'Completed',
                            isSelected: _activeStripTab == 'completed',
                            onTap: () {
                              setState(() {
                                _activeStripTab = _activeStripTab == 'completed'
                                    ? null
                                    : 'completed';
                              });
                            },
                          ),
                        ),
                      ...futureTaskEntries.map((entry) {
                        final date = entry.key;
                        final sectionKey = _dateKey(date);
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final subtextColor = isDark
                          ? AppTheme.white.withValues(alpha: 0.6)
                            : AppTheme.lightTextSecondary;
                        final accentColor =
                            isDark ? AppTheme.yellow : AppTheme.orange;
                        final activeColor = _activeStripTab == sectionKey
                            ? accentColor
                            : subtextColor;

                        final calendarIcon = Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 20, color: activeColor),
                            Positioned(
                              top: 7,
                              child: Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: activeColor,
                                ),
                              ),
                            ),
                          ],
                        );

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildStripItem(
                            context: context,
                            customIcon: calendarIcon,
                            label: DateFormat('MMM d').format(date),
                            isSelected: _activeStripTab == sectionKey,
                            onTap: () {
                              setState(() {
                                _activeStripTab = _activeStripTab == sectionKey
                                    ? null
                                    : sectionKey;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            // Dropdown tasks view
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_activeStripTab == 'completed' &&
                      completedTasks.isNotEmpty)
                    ...completedTasks.map((task) => _TaskCard(task: task)),
                  if (_activeStripTab != null && _activeStripTab != 'completed')
                    ...futureTaskEntries
                        .where((e) => _dateKey(e.key) == _activeStripTab)
                        .expand((e) => e.value)
                        .map((task) => _TaskCard(task: task)),
                ],
              ),
            ),
          ],
        );

        return RefreshIndicator(
            onRefresh: () => taskProvider.refresh(), child: listView);
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count, {
    bool isCompleted = false,
    bool isExpanded = false,
    bool isCollapsible = true,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final subtextColor =
      isDark ? AppTheme.white.withValues(alpha: 0.6) : AppTheme.lightTextSecondary;
    final accentColor = isDark ? AppTheme.yellow : AppTheme.orange;

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.15)
                  : accentColor.withValues(alpha: 0.15),
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
              color: subtextColor.withValues(alpha: 0.15),
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
          if (isCollapsible) ...[
            const SizedBox(width: 10),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: subtextColor,
              size: 20,
            ),
          ],
        ],
      ),
    );

    if (!isCollapsible || onTap == null) return header;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: header,
    );
  }

  Widget _buildStripItem({
    required BuildContext context,
    IconData? icon,
    Widget? customIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppTheme.yellow : AppTheme.orange;
    final subtextColor =
      isDark ? AppTheme.white.withValues(alpha: 0.6) : AppTheme.lightTextSecondary;
    final activeColor = isSelected ? accentColor : subtextColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.3)
                : subtextColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (customIcon != null)
              customIcon
            else if (icon != null)
              Icon(icon, size: 20, color: activeColor),
            if (customIcon != null || icon != null) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: activeColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
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
    final isOverdue = task.isOverdue;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkGray : AppTheme.lightCard;
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final subtextColor =
      isDark ? AppTheme.white.withValues(alpha: 0.6) : AppTheme.lightTextSecondary;
    final accentColor = isDark ? AppTheme.yellow : AppTheme.orange;

    final borderColor = isOverdue
        ? Colors.red
        : (isDark ? AppTheme.lightGray : AppTheme.lightBorder);
    final borderWidth = isOverdue ? 1.6 : 1.0;

    final hasBottomChips = task.repeatSettings != 'none';

    return Opacity(
        opacity: task.completed ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
                              color:
                                  task.completed ? AppTheme.blue : subtextColor,
                              width: 2,
                            ),
                            color: task.completed
                                ? AppTheme.blue
                                : Colors.transparent,
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color:
                                    task.completed ? subtextColor : textColor,
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
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0, left: 4.0),
                        child: Icon(
                          Icons.access_time,
                          size: 14,
                          color: isOverdue ? Colors.red : subtextColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            'Due ${timeFormat.format(task.endTime)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: isOverdue ? Colors.red : subtextColor,
                                ),
                          ),
                        ),
                      ),
                      _TaskChip(
                        label: task.restrictionMode == 'default'
                            ? 'Default'
                            : 'Custom',
                        color: AppTheme.blue,
                        icon: Icons.lock,
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
                  if (hasBottomChips) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (task.repeatSettings != 'none')
                          _TaskChip(
                            label: task.repeatSettings,
                            color: accentColor,
                            icon: Icons.repeat,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ));
  }
}

/// Reusable empty state widget for tasks tab
class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor =
      isDark ? AppTheme.white.withValues(alpha: 0.6) : AppTheme.lightTextSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 100,
            color: AppTheme.blue.withValues(alpha: 0.3),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
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
  final OverlayToastService _toastService = OverlayToastService();

  @override
  void dispose() {
    _toastService.dispose();
    super.dispose();
  }

  void _showTopRightToast(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    _toastService.showTopRightToast(
      context: context,
      duration: duration,
      child: _PillToast(
        message: message,
        backgroundColor: backgroundColor ?? AppTheme.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor =
      isDark ? AppTheme.white.withValues(alpha: 0.6) : AppTheme.lightTextSecondary;

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
      if (!ctx.mounted) return;

      Navigator.of(ctx).pop(); // close loading

      // Exclude already blocked apps based on mode
      final alreadyBlocked = isPermanent
          ? provider.permanentlyBlockedApps
          : provider.defaultRestrictedApps;

      if (!ctx.mounted) return;
      final selectedApps = await showModalBottomSheet<List<String>>(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: _DefaultAppSelectorDialog(
              installedApps: installedApps,
              alreadyRestricted: alreadyBlocked,
              isPermanent: isPermanent,
            ),
          ),
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
        _showTopRightToast(
          isPermanent
              ? 'Permanently blocked ${selectedApps.length} app(s)'
              : 'Added ${selectedApps.length} app(s)',
          backgroundColor: isPermanent ? Colors.red : AppTheme.blue,
        );
      }
    } catch (e) {
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop(); // close loading
      _showTopRightToast('Error loading apps: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _showAddWebsiteDialog(
      RestrictionsProvider provider, bool isPermanent) async {
    final ctx = context;

    final result = await showModalBottomSheet<String>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
        ),
        child: _AddWebsiteBottomSheet(isPermanent: isPermanent),
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (isPermanent) {
        provider.addPermanentWebsite(result);
      } else {
        provider.addWebsite(result);
      }
      if (!mounted) return;
      _showTopRightToast(
        isPermanent
            ? 'Permanently blocked ${provider.extractDomain(result)}'
            : 'Added ${provider.extractDomain(result)}',
        backgroundColor: isPermanent ? Colors.red : AppTheme.blue,
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
      isDark ? AppTheme.lightGray.withValues(alpha: 0.8) : AppTheme.lightBorder;
    final defaultTextColor = isDark ? AppTheme.white : AppTheme.lightText;

    final borderColor = selected ? AppTheme.blue : defaultBorder;
    final bgColor =
      selected ? AppTheme.blue.withValues(alpha: 0.12) : Colors.transparent;
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
      ? Colors.red.withValues(alpha: 0.5)
        : (isDark ? AppTheme.lightGray : AppTheme.lightBorder);
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final subtextColor =
      isDark ? AppTheme.white.withValues(alpha: 0.6) : AppTheme.lightTextSecondary;
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
              color: accentColor.withValues(alpha: 0.12),
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
                          color: Colors.red.withValues(alpha: 0.15),
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  late final List<Map<String, dynamic>> _allSelectableApps;
  List<Map<String, dynamic>> _filteredApps = const [];
  bool _isSearchVisible = false;

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
    _searchFocusNode.dispose();
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

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
    });

    if (_isSearchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
      if (_searchController.text.isNotEmpty) {
        _searchController.clear();
        _onSearchChanged('');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor =
      isDark ? AppTheme.white.withValues(alpha: 0.6) : AppTheme.lightTextSecondary;
    final accentColor = widget.isPermanent ? Colors.red : AppTheme.blue;
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final bgColor = isDark ? AppTheme.darkGray : AppTheme.lightCard;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.lightGray : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isPermanent
                            ? 'Block Apps Forever'
                            : 'Select Apps to Block',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_filteredApps.length} available • ${_selectedApps.length} selected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: subtextColor,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap apps to multi-select',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: subtextColor.withValues(alpha: 0.85),
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _isSearchVisible ? 'Hide search' : 'Search apps',
                  onPressed: _toggleSearch,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns:
                          Tween<double>(begin: 0.85, end: 1).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      _isSearchVisible ? Icons.search_off : Icons.search,
                      key: ValueKey(_isSearchVisible),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedApps.isEmpty
                      ? null
                      : () => Navigator.pop(
                            context,
                            _selectedApps.toList(),
                          ),
                  style: widget.isPermanent
                      ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                      : null,
                  icon: Icon(widget.isPermanent ? Icons.block : Icons.add,
                      size: 18),
                  label: Text(widget.isPermanent ? 'Block Forever' : 'Add'),
                ),
              ],
            ),
          ),
          if (widget.isPermanent) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 20),
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _isSearchVisible
                ? Padding(
                    key: const ValueKey('search-visible'),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    child: TextField(
                      focusNode: _searchFocusNode,
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search apps or package...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                          ? AppTheme.black.withValues(alpha: 0.30)
                            : AppTheme.lightBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                      ),
                      onChanged: (value) {
                        _onSearchChanged(value);
                        setState(() {});
                      },
                    ),
                  )
                : const SizedBox(key: ValueKey('search-hidden')),
          ),
          Expanded(
            child: _filteredApps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 44,
                            color: isDark
                            ? AppTheme.white.withValues(alpha: 0.45)
                                : AppTheme.lightTextSecondary),
                        const SizedBox(height: 10),
                        Text(
                          'No apps found',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: textColor,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try a different app name or package',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: subtextColor,
                                  ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    itemCount: _filteredApps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final packageName = app['packageName'] as String;
                      final appName = app['name'] as String;
                      final isSelected = _selectedApps.contains(packageName);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedApps.remove(packageName);
                              } else {
                                _selectedApps.add(packageName);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                ? accentColor.withValues(alpha: 0.10)
                                  : (isDark
                                  ? AppTheme.black.withValues(alpha: 0.15)
                                      : AppTheme.lightBackground),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? accentColor.withValues(alpha: 0.7)
                                    : (isDark
                                        ? AppTheme.lightGray.withValues(alpha: 0.35)
                                        : AppTheme.lightBorder),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    widget.isPermanent
                                        ? Icons.block
                                        : Icons.android,
                                    color: accentColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        appName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: textColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        packageName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: subtextColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Checkbox(
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PillToast extends StatelessWidget {
  final String message;
  final Color backgroundColor;

  const _PillToast({required this.message, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AddWebsiteBottomSheet extends StatefulWidget {
  final bool isPermanent;

  const _AddWebsiteBottomSheet({required this.isPermanent});

  @override
  State<_AddWebsiteBottomSheet> createState() => _AddWebsiteBottomSheetState();
}

class _AddWebsiteBottomSheetState extends State<_AddWebsiteBottomSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(
        const Duration(milliseconds: 100), () => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _insertText(String text) {
    if (_controller.selection.baseOffset >= 0 &&
        _controller.selection.extentOffset >= 0) {
      final start = _controller.selection.baseOffset;
      final end = _controller.selection.extentOffset;
      final newText = _controller.text.replaceRange(start, end, text);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + text.length),
      );
    } else {
      _controller.text += text;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
    _focusNode.requestFocus();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.isPermanent ? Colors.red : AppTheme.blue;
    final bgColor = isDark ? AppTheme.darkGray : AppTheme.lightCard;
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final subtextColor =
      isDark ? AppTheme.white.withValues(alpha: 0.6) : AppTheme.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.lightGray : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isPermanent
                        ? 'Block Website Forever'
                        : 'Add Website',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter domain or URL to restrict',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: subtextColor,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'e.g., youtube.com',
                            prefixIcon: const Icon(Icons.language),
                            filled: true,
                            fillColor: isDark
                              ? AppTheme.black.withValues(alpha: 0.30)
                                : AppTheme.lightBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: _submit,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child:
                              Icon(Icons.check, color: accentColor, size: 24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPill('.com', accentColor, isDark),
                        const SizedBox(width: 8),
                        _buildPill('.net', accentColor, isDark),
                        const SizedBox(width: 8),
                        _buildPill('.io', accentColor, isDark),
                        const SizedBox(width: 8),
                        _buildPill('.co', accentColor, isDark),
                        const SizedBox(width: 8),
                        _buildPill('.org', accentColor, isDark),
                        const SizedBox(width: 8),
                        _buildPill('.in', accentColor, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String text, Color accentColor, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _insertText(text),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                isDark ? AppTheme.black.withValues(alpha: 0.2) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppTheme.lightGray.withValues(alpha: 0.2)
                  : Colors.grey.shade300,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.white : AppTheme.lightText,
            ),
          ),
        ),
      ),
    );
  }
}
