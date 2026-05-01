import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/website_entry.dart';
import '../config/app_keys.dart';

class WebsitesProvider extends ChangeNotifier {
  List<WebsiteEntry> _sites = [];

  List<WebsiteEntry> get sites => _sites;

  WebsitesProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(PrefsKeys.websites);
      if (s == null) return;

      final decoded = jsonDecode(s);
      if (decoded is! List) {
        debugPrint('⚠️ WebsitesProvider: Invalid stored websites format');
        return;
      }

        _sites = decoded
            .whereType<Map>()
            .map((e) => WebsiteEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('⚠️ WebsitesProvider: Failed to load websites: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsKeys.websites, jsonEncode(_sites.map((a) => a.toJson()).toList()));
  }

  Future<void> add(WebsiteEntry a) async {
    _sites.add(a);
    notifyListeners();

    try {
      await _save();
    } catch (e, stackTrace) {
      debugPrint('❌ WebsitesProvider: Failed to save after add: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      _sites.removeWhere((x) => x.id == a.id);
      notifyListeners();
    }
  }

  Future<void> update(WebsiteEntry a) async {
    final i = _sites.indexWhere((x) => x.id == a.id);
    if (i != -1) {
      final previous = _sites[i];
      _sites[i] = a;
      notifyListeners();

      try {
        await _save();
      } catch (e, stackTrace) {
        debugPrint('❌ WebsitesProvider: Failed to save after update: $e');
        debugPrint('📍 Stack trace: $stackTrace');
        _sites[i] = previous;
        notifyListeners();
      }
    }
  }

  Future<void> remove(String id) async {
    final i = _sites.indexWhere((a) => a.id == id);
    if (i == -1) return;

    final removed = _sites.removeAt(i);
    notifyListeners();

    try {
      await _save();
    } catch (e, stackTrace) {
      debugPrint('❌ WebsitesProvider: Failed to save after remove: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      _sites.insert(i, removed);
      notifyListeners();
    }
  }
}
