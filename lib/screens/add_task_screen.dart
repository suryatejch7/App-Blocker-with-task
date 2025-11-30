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
      builder: (context, child) {
        // Use the current app theme for the picker
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
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
      builder: (context, child) {
        // Use the current app theme for the picker
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
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
      debugPrint('💾 AddTaskScreen._saveTask - Saving task');
      debugPrint('   📅 Start time: $_startTime (${_startTime.timeZoneName})');
      debugPrint('   📅 End time: $_endTime (${_endTime.timeZoneName})');
      debugPrint(
          '   🔢 Start time millis: ${_startTime.millisecondsSinceEpoch}');
      debugPrint('   🔢 End time millis: ${_endTime.millisecondsSinceEpoch}');

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;
    final accentColor = isDark ? AppTheme.yellow : AppTheme.orange;
    final subtextColor =
        isDark ? AppTheme.white.withOpacity(0.7) : AppTheme.lightTextSecondary;
    final cardColor = isDark ? AppTheme.darkGray : AppTheme.lightCard;
    final borderColor = isDark ? AppTheme.lightGray : AppTheme.lightBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            pinned: true,
            expandedHeight: 140,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.arrow_back_ios_new,
                                  size: 18, color: textColor),
                            ),
                          ),
                          const Spacer(),
                          _buildSaveButton(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_note : Icons.add_task,
                              color: isDark ? AppTheme.black : AppTheme.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isEditing ? 'Edit Task' : 'Create Task',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task Details Section
                    _buildSectionCard(
                      context,
                      icon: Icons.task_alt,
                      iconColor: AppTheme.blue,
                      title: 'Task Details',
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      child: Column(
                        children: [
                          // Task Name
                          _buildModernTextField(
                            controller: _titleController,
                            label: 'Task Name',
                            hint: 'What do you need to do?',
                            icon: Icons.title,
                            isRequired: true,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            subtextColor: subtextColor,
                          ),
                          const SizedBox(height: 16),
                          // Description
                          _buildModernTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'Add more details (optional)',
                            icon: Icons.notes,
                            maxLines: 3,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            subtextColor: subtextColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Schedule Section
                    _buildSectionCard(
                      context,
                      icon: Icons.schedule,
                      iconColor: accentColor,
                      title: 'Schedule',
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Picker
                          GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: accentColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.calendar_today,
                                        color: accentColor, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('EEEE').format(_startTime),
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('MMMM d, yyyy')
                                              .format(_startTime),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      color: subtextColor),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Time Selection
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimeSelector(
                                  context,
                                  label: 'Start',
                                  time: _startTime,
                                  isStart: true,
                                  cardColor: cardColor,
                                  borderColor: borderColor,
                                  textColor: textColor,
                                  subtextColor: subtextColor,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(Icons.arrow_forward,
                                    color: subtextColor, size: 20),
                              ),
                              Expanded(
                                child: _buildTimeSelector(
                                  context,
                                  label: 'End',
                                  time: _endTime,
                                  isStart: false,
                                  cardColor: cardColor,
                                  borderColor: borderColor,
                                  textColor: textColor,
                                  subtextColor: subtextColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Duration info
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timelapse,
                                    size: 18, color: AppTheme.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Duration: ${_formatDuration(_endTime.difference(_startTime))}',
                                  style: const TextStyle(
                                    color: AppTheme.blue,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Repeat Section
                    _buildSectionCard(
                      context,
                      icon: Icons.repeat,
                      iconColor: Colors.purple,
                      title: 'Repeat',
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildRepeatChip('none', 'Once', Icons.looks_one),
                          _buildRepeatChip('daily', 'Daily', Icons.today),
                          _buildRepeatChip(
                              'weekly', 'Weekly', Icons.date_range),
                          _buildRepeatChip('custom', 'Custom', Icons.tune),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Restrictions Section
                    _buildSectionCard(
                      context,
                      icon: Icons.block,
                      iconColor: Colors.redAccent,
                      title: 'App Blocking',
                      subtitle:
                          'Block distracting apps while working on this task',
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Restriction mode toggle
                          Row(
                            children: [
                              Expanded(
                                child: _buildRestrictionToggle(
                                  'default',
                                  'Default List',
                                  Icons.list_alt,
                                  'Use your preset blocked apps',
                                  cardColor,
                                  borderColor,
                                  textColor,
                                  subtextColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildRestrictionToggle(
                                  'custom',
                                  'Custom',
                                  Icons.tune,
                                  'Choose specific apps',
                                  cardColor,
                                  borderColor,
                                  textColor,
                                  subtextColor,
                                ),
                              ),
                            ],
                          ),

                          // Custom apps/websites selection
                          if (_restrictionMode == 'custom') ...[
                            const SizedBox(height: 20),
                            _buildCustomRestrictionSection(
                              context,
                              title: 'Blocked Apps',
                              items: _customRestrictedApps,
                              emptyMessage: 'No apps blocked yet',
                              icon: Icons.android,
                              onAdd: _selectCustomApps,
                              onRemove: (item) {
                                setState(() {
                                  _customRestrictedApps.remove(item);
                                });
                              },
                              cardColor: cardColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),
                            const SizedBox(height: 16),
                            _buildCustomRestrictionSection(
                              context,
                              title: 'Blocked Websites',
                              items: _customRestrictedWebsites,
                              emptyMessage: 'No websites blocked yet',
                              icon: Icons.language,
                              onAdd: _showAddCustomWebsiteDialog,
                              onRemove: (item) {
                                setState(() {
                                  _customRestrictedWebsites.remove(item);
                                });
                              },
                              cardColor: cardColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _saveTask,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.blue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: AppTheme.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Save',
              style: TextStyle(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget child,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? AppTheme.mediumGray.withOpacity(0.5)
        : AppTheme.lightBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: subtextColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: subtextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: textColor, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: subtextColor.withOpacity(0.6)),
            filled: true,
            fillColor: fillColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.blue, width: 2),
            ),
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildTimeSelector(
    BuildContext context, {
    required String label,
    required DateTime time,
    required bool isStart,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return GestureDetector(
      onTap: () => _selectTime(isStart),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: subtextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, size: 20, color: AppTheme.blue),
                const SizedBox(width: 8),
                Text(
                  DateFormat('HH:mm').format(time),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  Widget _buildRepeatChip(String value, String label, IconData icon) {
    final selected = _repeatSettings == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark ? AppTheme.mediumGray : AppTheme.lightSurface;
    final unselectedBorder = isDark ? AppTheme.lightGray : AppTheme.lightBorder;
    final textColor = isDark ? AppTheme.white : AppTheme.lightText;

    return GestureDetector(
      onTap: () => setState(() => _repeatSettings = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.purple : unselectedBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.purple : unselectedBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppTheme.white : textColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.white : textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictionToggle(
    String value,
    String label,
    IconData icon,
    String description,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    final selected = _restrictionMode == value;

    return GestureDetector(
      onTap: () => setState(() => _restrictionMode = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0x26FF5252) : cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.redAccent : borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.redAccent : subtextColor,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.redAccent : textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtextColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomRestrictionSection(
    BuildContext context, {
    required String title,
    required List<String> items,
    required String emptyMessage,
    required IconData icon,
    required VoidCallback onAdd,
    required Function(String) onRemove,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? AppTheme.mediumGray.withOpacity(0.3)
        : AppTheme.lightBackground;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: subtextColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: AppTheme.blue),
                      SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: AppTheme.blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  emptyMessage,
                  style: TextStyle(
                    color: subtextColor,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                // Shorten package names for display
                final displayName =
                    item.contains('.') ? item.split('.').last : item;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onRemove(item),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor =
        isDark ? AppTheme.white.withOpacity(0.6) : AppTheme.lightTextSecondary;
    final accentColor = isDark ? AppTheme.yellow : AppTheme.orange;

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
                Icon(Icons.apps, color: accentColor),
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
                        color: subtextColor,
                      ),
                    ),
                    secondary: const Icon(Icons.android, color: AppTheme.blue),
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
