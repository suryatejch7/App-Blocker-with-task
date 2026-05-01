import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_entry.dart';
import '../config/app_keys.dart';

class AppsProvider extends ChangeNotifier {
  List<AppEntry> _apps = [];

  List<AppEntry> get apps => _apps;

  AppsProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(PrefsKeys.apps);
      if (s == null) return;

      final decoded = jsonDecode(s);
      if (decoded is! List) {
        debugPrint('⚠️ AppsProvider: Invalid stored apps format');
        return;
      }

      _apps = decoded
          .whereType<Map>()
          .map((e) => AppEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('⚠️ AppsProvider: Failed to load apps: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsKeys.apps, jsonEncode(_apps.map((a) => a.toJson()).toList()));
  }

  Future<void> add(AppEntry a) async {
    _apps.add(a);
    notifyListeners();

    try {
      await _save();
    } catch (e, stackTrace) {
      debugPrint('❌ AppsProvider: Failed to save after add: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      _apps.removeWhere((x) => x.id == a.id);
      notifyListeners();
    }
  }

  Future<void> update(AppEntry a) async {
    final i = _apps.indexWhere((x) => x.id == a.id);
    if (i != -1) {
      final previous = _apps[i];
      _apps[i] = a;
      notifyListeners();

      try {
        await _save();
      } catch (e, stackTrace) {
        debugPrint('❌ AppsProvider: Failed to save after update: $e');
        debugPrint('📍 Stack trace: $stackTrace');
        _apps[i] = previous;
        notifyListeners();
      }
    }
  }

  Future<void> remove(String id) async {
    final i = _apps.indexWhere((a) => a.id == id);
    if (i == -1) return;

    final removed = _apps.removeAt(i);
    notifyListeners();

    try {
      await _save();
    } catch (e, stackTrace) {
      debugPrint('❌ AppsProvider: Failed to save after remove: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      _apps.insert(i, removed);
      notifyListeners();
    }
  }
}
