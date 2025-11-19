import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_entry.dart';

class AppsProvider extends ChangeNotifier {
  List<AppEntry> _apps = [];

  List<AppEntry> get apps => _apps;

  AppsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('apps');
    if (s != null) {
      final List decoded = jsonDecode(s);
      _apps = decoded
          .map((e) => AppEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'apps', jsonEncode(_apps.map((a) => a.toJson()).toList()));
  }

  void add(AppEntry a) {
    _apps.add(a);
    _save();
    notifyListeners();
  }

  void update(AppEntry a) {
    final i = _apps.indexWhere((x) => x.id == a.id);
    if (i != -1) {
      _apps[i] = a;
      _save();
      notifyListeners();
    }
  }

  void remove(String id) {
    _apps.removeWhere((a) => a.id == id);
    _save();
    notifyListeners();
  }
}
