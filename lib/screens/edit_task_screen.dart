import 'package:flutter/material.dart';
import 'add_task_screen.dart';
import '../models/task.dart';

class EditTaskScreen extends StatelessWidget {
  final Task? task;

  const EditTaskScreen({super.key, this.task});

  @override
  Widget build(BuildContext context) {
    return AddTaskScreen(existingTask: task);
  }
}
