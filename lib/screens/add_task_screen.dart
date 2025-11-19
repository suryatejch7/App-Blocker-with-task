import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? existingTask;

  const AddTaskScreen({super.key, this.existingTask});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _startTime;
  late DateTime _endTime;
  String _repeatSettings = 'none';
  String _restrictionMode = 'default';
  List<String> _customRestrictedApps = [];
  List<String> _customRestrictedWebsites = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      final task = widget.existingTask!;
      _titleController.text = task.title;
      _descriptionController.text = task.description ?? '';
      _startTime = task.startTime;
      _endTime = task.endTime;
      _repeatSettings = task.repeatSettings;
      _restrictionMode = task.restrictionMode;
      _customRestrictedApps = List.from(task.customRestrictedApps);
      _customRestrictedWebsites = List.from(task.customRestrictedWebsites);
    } else {
      // Default to current time rounded to next hour
      final now = DateTime.now();
      _startTime = DateTime(now.year, now.month, now.day, now.hour + 1);
      _endTime = _startTime.add(const Duration(hours: 2));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(bool isStartTime) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStartTime ? _startTime : _endTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime),
      );

      if (time != null) {
        setState(() {
          final newDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );

          if (isStartTime) {
            _startTime = newDateTime;
            // Ensure end time is after start time
            if (_endTime.isBefore(_startTime)) {
              _endTime = _startTime.add(const Duration(hours: 1));
            }
          } else {
            _endTime = newDateTime;
            // Ensure end time is after start time
            if (_endTime.isBefore(_startTime)) {
              _startTime = _endTime.subtract(const Duration(hours: 1));
            }
          }
        });
      }
    }
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<TaskProvider>(context, listen: false);
      final task = Task(
        id: widget.existingTask?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        completed: widget.existingTask?.completed ?? false,
        repeatSettings: _repeatSettings,
        restrictionMode: _restrictionMode,
        customRestrictedApps: _customRestrictedApps,
        customRestrictedWebsites: _customRestrictedWebsites,
        completedAt: widget.existingTask?.completedAt,
      );

      if (widget.existingTask != null) {
        provider.updateTask(task);
      } else {
        provider.addTask(task);
      }

      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTask != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveTask,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Complete project report',
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add details about this task',
                prefixIcon: Icon(Icons.description),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Time Section
            Text(
              'SCHEDULE',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.yellow,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.event, color: AppTheme.blue),
                    title: const Text('Start Time'),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy - h:mm a').format(_startTime),
                    ),
                    trailing: const Icon(Icons.edit, size: 20),
                    onTap: () => _selectDateTime(true),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        const Icon(Icons.event_available, color: AppTheme.blue),
                    title: const Text('End Time'),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy - h:mm a').format(_endTime),
                    ),
                    trailing: const Icon(Icons.edit, size: 20),
                    onTap: () => _selectDateTime(false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Repeat Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.repeat, color: AppTheme.blue),
                        const SizedBox(width: 12),
                        Text(
                          'Repeat',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _repeatSettings,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      dropdownColor: AppTheme.darkGray,
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                            value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(
                            value: 'monthly', child: Text('Monthly')),
                      ],
                      onChanged: (value) {
                        setState(() => _repeatSettings = value ?? 'none');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Restrictions Section
            Text(
              'RESTRICTIONS',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.yellow,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose which apps and websites to block during this task:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.white.withOpacity(0.8),
                          ),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<String>(
                      value: 'default',
                      groupValue: _restrictionMode,
                      onChanged: (value) {
                        setState(() => _restrictionMode = value!);
                      },
                      title: const Text('Use Default Restrictions'),
                      subtitle: const Text(
                          'Block the apps and websites configured in settings'),
                    ),
                    RadioListTile<String>(
                      value: 'custom',
                      groupValue: _restrictionMode,
                      onChanged: (value) {
                        setState(() => _restrictionMode = value!);
                      },
                      title: const Text('Custom Restrictions'),
                      subtitle: const Text(
                          'Choose specific apps and websites for this task'),
                    ),
                    if (_restrictionMode == 'custom') ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Custom Blocked Apps',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (_customRestrictedApps.isEmpty)
                        Text(
                          'No apps selected',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.white.withOpacity(0.5),
                                  ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _customRestrictedApps
                              .map((app) => Chip(
                                    label: Text(app),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () {
                                      setState(() {
                                        _customRestrictedApps.remove(app);
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/apps/add'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Apps'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Custom Blocked Websites',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (_customRestrictedWebsites.isEmpty)
                        Text(
                          'No websites selected',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.white.withOpacity(0.5),
                                  ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _customRestrictedWebsites
                              .map((site) => Chip(
                                    label: Text(site),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () {
                                      setState(() {
                                        _customRestrictedWebsites.remove(site);
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/websites/add'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Websites'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
