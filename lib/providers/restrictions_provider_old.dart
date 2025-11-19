import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/restriction_service.dart';

class RestrictionsProvider extends ChangeNotifier {
  List<String> _defaultRestrictedApps = [];
  List<String> _defaultRestrictedWebsites = [];
  final RestrictionService _restrictionService = RestrictionService();

  List<String> get defaultRestrictedApps => _defaultRestrictedApps;
  List<String> get defaultRestrictedWebsites => _defaultRestrictedWebsites;

  RestrictionsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final apps = prefs.getString('defaultRestrictedApps');
    final websites = prefs.getString('defaultRestrictedWebsites');

    if (apps != null) {
      _defaultRestrictedApps = List<String>.from(jsonDecode(apps));
    }
    if (websites != null) {
      _defaultRestrictedWebsites = List<String>.from(jsonDecode(websites));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'defaultRestrictedApps', jsonEncode(_defaultRestrictedApps));
    await prefs.setString(
        'defaultRestrictedWebsites', jsonEncode(_defaultRestrictedWebsites));
  }

  void addApp(String packageName) {
    if (!_defaultRestrictedApps.contains(packageName)) {
      _defaultRestrictedApps.add(packageName);
      _save();
      notifyListeners();
    }
  }

  void removeApp(String packageName) {
    _defaultRestrictedApps.remove(packageName);
    _save();
    notifyListeners();
  }

  void addWebsite(String domain) {
    final cleanDomain = extractDomain(domain);
    if (!_defaultRestrictedWebsites.contains(cleanDomain)) {
      _defaultRestrictedWebsites.add(cleanDomain);
      _save();
      notifyListeners();
    }
  }

  void removeWebsite(String domain) {
    _defaultRestrictedWebsites.remove(domain);
    _save();
    notifyListeners();
  }

  String extractDomain(String input) {
    try {
      if (!input.startsWith('http://') && !input.startsWith('https://')) {
        input = 'https://$input';
      }
      final uri = Uri.parse(input);
      return uri.host.replaceAll('www.', '');
    } catch (e) {
      return input
          .replaceAll('www.', '')
          .replaceAll('https://', '')
          .replaceAll('http://', '')
          .split('/')[0];
    }
  }

  Future<List<Map<String, String>>> getInstalledApps() async {
    return await _restrictionService.getInstalledApps();
  }
}
