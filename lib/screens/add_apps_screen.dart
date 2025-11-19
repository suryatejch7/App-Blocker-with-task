import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/app_entry.dart';
import '../providers/apps_provider.dart';

class AddAppsScreen extends StatefulWidget {
  const AddAppsScreen({super.key});

  @override
  State<AddAppsScreen> createState() => _AddAppsScreenState();
}

class _AddAppsScreenState extends State<AddAppsScreen> {
  final _nameCtrl = TextEditingController();
  final _pkgCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isEdit = false;
  String? _editId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      final provider = Provider.of<AppsProvider>(context, listen: false);
      final a = provider.apps.firstWhere((x) => x.id == args,
          orElse: () => AppEntry(id: '', name: '', packageName: ''));
      if (a.id != '') {
        _isEdit = true;
        _editId = a.id;
        _nameCtrl.text = a.name;
        _pkgCtrl.text = a.packageName;
        _notesCtrl.text = a.notes;
      }
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final pkg = _pkgCtrl.text.trim();
    if (name.isEmpty || pkg.isEmpty) return;
    final provider = Provider.of<AppsProvider>(context, listen: false);
    if (_isEdit && _editId != null) {
      provider.update(AppEntry(
          id: _editId!,
          name: name,
          packageName: pkg,
          notes: _notesCtrl.text.trim()));
    } else {
      provider.add(AppEntry(
          id: Uuid().v4(),
          name: name,
          packageName: pkg,
          notes: _notesCtrl.text.trim()));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit App' : 'Add App')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'App name')),
            const SizedBox(height: 8),
            TextField(
                controller: _pkgCtrl,
                decoration: const InputDecoration(labelText: 'Package name')),
            const SizedBox(height: 8),
            TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
