import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
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
      appBar: AppBar(
        title: const Text('Productivity Blocker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
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
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final todayTasks = taskProvider.todayTasks;
        final futureTasks = taskProvider.futureTasks;
        final overdueTasks = taskProvider.overdueTasks;

        if (todayTasks.isEmpty && futureTasks.isEmpty && overdueTasks.isEmpty) {
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
          padding: const EdgeInsets.all(16),
          children: [
            // Overdue tasks
            if (overdueTasks.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'OVERDUE (${overdueTasks.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...overdueTasks.map((task) => _TaskCard(task: task)),
              const SizedBox(height: 24),
            ],

            // Today's tasks
            if (todayTasks.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.today, color: AppTheme.yellow, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'TODAY',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.yellow,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...todayTasks.map((task) => _TaskCard(task: task)),
              const SizedBox(height: 24),
            ],

            // Future tasks
            if (futureTasks.isNotEmpty) ...[
              Text(
                'UPCOMING',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.blue,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ...futureTasks.entries.expand((entry) {
                final date = entry.key;
                final tasks = entry.value;
                return [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 12, bottom: 8),
                    child: Text(
                      DateFormat('EEEE, MMM d').format(date),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.white.withOpacity(0.7),
                          ),
                    ),
                  ),
                  ...tasks.map((task) => _TaskCard(task: task)),
                ];
              }),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/edit', extra: task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: task.completed,
                onChanged: (value) {
                  if (value != null) {
                    taskProvider.toggleComplete(task.id);
                  }
                },
              ),
              const SizedBox(width: 12),
              // Task info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  decoration: task.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.completed
                                      ? AppTheme.white.withOpacity(0.5)
                                      : AppTheme.white,
                                ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isOverdue
                              ? Colors.red
                              : AppTheme.white.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${timeFormat.format(task.startTime)} - ${timeFormat.format(task.endTime)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isOverdue
                                        ? Colors.red
                                        : AppTheme.white.withOpacity(0.6),
                                  ),
                        ),
                        if (task.repeatSettings != 'none') ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.repeat,
                            size: 14,
                            color: AppTheme.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.repeatSettings,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.white.withOpacity(0.6),
                                    ),
                          ),
                        ],
                      ],
                    ),
                    if (task.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.white.withOpacity(0.5),
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.block,
                          size: 14,
                          color: AppTheme.yellow.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.restrictionMode == 'default'
                              ? 'Default restrictions'
                              : 'Custom restrictions',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.yellow.withOpacity(0.8),
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestrictionsTab extends StatelessWidget {
  const _RestrictionsTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block,
            size: 100,
            color: AppTheme.yellow.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Default Restrictions',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Manage your default app and website restrictions',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.white.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/restrictions'),
            icon: const Icon(Icons.settings),
            label: const Text('Configure Restrictions'),
          ),
        ],
      ),
    );
  }
}
