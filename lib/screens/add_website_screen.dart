import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/website_entry.dart';
import '../providers/websites_provider.dart';

class AddWebsiteScreen extends StatefulWidget {
  const AddWebsiteScreen({super.key});

  @override
  State<AddWebsiteScreen> createState() => _AddWebsiteScreenState();
}

class _AddWebsiteScreenState extends State<AddWebsiteScreen> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isEdit = false;
  String? _editId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      final provider = Provider.of<WebsitesProvider>(context, listen: false);
      final s = provider.sites.firstWhere((x) => x.id == args,
          orElse: () => WebsiteEntry(id: '', title: '', url: ''));
      if (s.id != '') {
        _isEdit = true;
        _editId = s.id;
        _titleCtrl.text = s.title;
        _urlCtrl.text = s.url;
        _notesCtrl.text = s.notes;
      }
    }
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (title.isEmpty || url.isEmpty) return;
    final provider = Provider.of<WebsitesProvider>(context, listen: false);
    if (_isEdit && _editId != null) {
      provider.update(WebsiteEntry(
          id: _editId!, title: title, url: url, notes: _notesCtrl.text.trim()));
    } else {
      provider.add(WebsiteEntry(
          id: Uuid().v4(),
          title: title,
          url: url,
          notes: _notesCtrl.text.trim()));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Website' : 'Add Website')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(labelText: 'URL')),
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
