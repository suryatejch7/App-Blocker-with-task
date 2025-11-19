import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/website_entry.dart';

class WebsitesProvider extends ChangeNotifier {
  List<WebsiteEntry> _sites = [];

  List<WebsiteEntry> get sites => _sites;

  WebsitesProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('websites');
    if (s != null) {
      final List decoded = jsonDecode(s);
      _sites = decoded
          .map((e) => WebsiteEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'websites', jsonEncode(_sites.map((a) => a.toJson()).toList()));
  }

  void add(WebsiteEntry a) {
    _sites.add(a);
    _save();
    notifyListeners();
  }

  void update(WebsiteEntry a) {
    final i = _sites.indexWhere((x) => x.id == a.id);
    if (i != -1) {
      _sites[i] = a;
      _save();
      notifyListeners();
    }
  }

  void remove(String id) {
    _sites.removeWhere((a) => a.id == id);
    _save();
    notifyListeners();
  }
}
