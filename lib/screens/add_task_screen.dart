import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../providers/restrictions_provider.dart';
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

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      setState(() {
        _startTime = DateTime(
          date.year,
          date.month,
          date.day,
          _startTime.hour,
          _startTime.minute,
        );
        _endTime = DateTime(
          date.year,
          date.month,
          date.day,
          _endTime.hour,
          _endTime.minute,
        );

        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      });
    }
  }

  Future<void> _selectCustomApps() async {
    final restrictionsProvider =
        Provider.of<RestrictionsProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.blue),
      ),
    );

    try {
      final installedApps = await restrictionsProvider.getInstalledApps();
      if (!mounted) return;

      Navigator.pop(context); // close loading

      final selected = await showDialog<List<String>>(
        context: context,
        builder: (context) => _TaskAppSelectorDialog(
          installedApps: installedApps,
          initiallySelected: _customRestrictedApps,
        ),
      );

      if (selected != null) {
        setState(() {
          _customRestrictedApps = selected;
        });
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

  Future<void> _showAddCustomWebsiteDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Website'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Website URL or domain',
              hintText: 'e.g., youtube.com or https://youtube.com',
            ),
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a website';
              }
              return null;
            },
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
      final domain = _normalizeDomain(result);
      setState(() {
        if (!_customRestrictedWebsites.contains(domain)) {
          _customRestrictedWebsites.add(domain);
        }
      });
    }
  }

  String _normalizeDomain(String input) {
    try {
      var value = input.trim();
      if (!value.startsWith('http://') && !value.startsWith('https://')) {
        value = 'https://$value';
      }
      final uri = Uri.parse(value);
      return uri.host.replaceAll('www.', '');
    } catch (e) {
      return input
          .replaceAll('www.', '')
          .replaceAll('https://', '')
          .replaceAll('http://', '')
          .split('/')[0];
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final base = isStartTime ? _startTime : _endTime;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );

    if (time != null && mounted) {
      setState(() {
        final updated = DateTime(
          base.year,
          base.month,
          base.day,
          time.hour,
          time.minute,
        );
        if (isStartTime) {
          _startTime = updated;
          if (_endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(const Duration(hours: 1));
          }
        } else {
          _endTime = updated;
          if (_endTime.isBefore(_startTime)) {
            _startTime = _endTime.subtract(const Duration(hours: 1));
          }
        }
      });
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

  Widget _buildRepeatOption(String value, String label) {
    final selected = _repeatSettings == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _repeatSettings = value;
          });
        },
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.blue.withOpacity(0.15)
                : AppTheme.mediumGray,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.blue : AppTheme.lightGray,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? AppTheme.blue : AppTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestrictionOption(String value, String label) {
    final selected = _restrictionMode == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _restrictionMode = value;
        });
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.blue.withOpacity(0.15)
              : AppTheme.mediumGray,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.blue : AppTheme.lightGray,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? AppTheme.blue : AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(BuildContext context,
      {required bool isStart, required DateTime time}) {
    final label = DateFormat('HH:mm').format(time);
    return GestureDetector(
      onTap: () => _selectTime(isStart),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.mediumGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.lightGray),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.access_time,
              size: 18,
              color: AppTheme.blue,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictionCard({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _restrictionMode == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _restrictionMode = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.blue : AppTheme.lightGray,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: value,
              groupValue: _restrictionMode,
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _restrictionMode = val;
                });
              },
              activeColor: AppTheme.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: AppTheme.white.withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTask != null;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.white),
          onPressed: () => context.pop(),
        ),
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _saveTask,
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.blue,
                foregroundColor: AppTheme.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Task Name
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Name *',
                hintText: 'e.g., Complete Morning Workout',
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
                labelText: 'Description',
                hintText: 'Add details about this task',
                prefixIcon: Icon(Icons.description),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Date & Time Section
            Text(
              'Date',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.yellow,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.darkGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightGray),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: AppTheme.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_startTime),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const Icon(Icons.edit_calendar, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start Time',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.white.withOpacity(0.8),
                      ),
                ),
                Text(
                  'End Time',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.white.withOpacity(0.8),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTimeChip(
                    context,
                    isStart: true,
                    time: _startTime,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeChip(
                    context,
                    isStart: false,
                    time: _endTime,
                  ),
                ),
              ],
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
                    Row(
                      children: [
                        _buildRepeatOption('none', 'None'),
                        const SizedBox(width: 8),
                        _buildRepeatOption('daily', 'Daily'),
                        const SizedBox(width: 8),
                        _buildRepeatOption('weekly', 'Weekly'),
                        const SizedBox(width: 8),
                        _buildRepeatOption('custom', 'Custom'),
                      ],
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
            Row(
              children: [
                Expanded(
                  child: _buildRestrictionOption('default', 'Default'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRestrictionOption('custom', 'Custom'),
                ),
              ],
            ),
            if (_restrictionMode == 'custom') ...[
              const SizedBox(height: 16),
              Text(
                'Custom Blocked Apps',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_customRestrictedApps.isEmpty)
                Text(
                  'No apps selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                onPressed: _selectCustomApps,
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                onPressed: _showAddCustomWebsiteDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Websites'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskAppSelectorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> installedApps;
  final List<String> initiallySelected;

  const _TaskAppSelectorDialog({
    required this.installedApps,
    required this.initiallySelected,
  });

  @override
  State<_TaskAppSelectorDialog> createState() => _TaskAppSelectorDialogState();
}

class _TaskAppSelectorDialogState extends State<_TaskAppSelectorDialog> {
  late Set<String> _selectedApps;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedApps = {...widget.initiallySelected};
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = widget.installedApps.where((app) {
      final packageName = (app['packageName'] ?? '') as String;
      final appName = (app['name'] ?? '') as String;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return packageName.toLowerCase().contains(q) ||
          appName.toLowerCase().contains(q);
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
                  final packageName = (app['packageName'] ?? '') as String;
                  final appName = (app['name'] ?? '') as String;
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
                    title: Text(appName.isEmpty ? packageName : appName),
                    subtitle: Text(
                      packageName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.white.withOpacity(0.6),
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

