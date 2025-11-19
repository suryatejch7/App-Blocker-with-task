import 'package:flutter/foundation.dart';
import '../services/restriction_service.dart';
import '../services/supabase_service.dart';

class RestrictionsProvider extends ChangeNotifier {
  List<String> _defaultRestrictedApps = [];
  List<String> _defaultRestrictedWebsites = [];
  final RestrictionService _restrictionService = RestrictionService();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  // Callback to notify when restrictions change (for TaskProvider to sync)
  Function(List<String> apps, List<String> websites)? onRestrictionsChanged;

  List<String> get defaultRestrictedApps => _defaultRestrictedApps;
  List<String> get defaultRestrictedWebsites => _defaultRestrictedWebsites;
  bool get isLoading => _isLoading;

  RestrictionsProvider() {
    _load();
  }

  Future<void> _load() async {
    debugPrint(
        '🟢 RestrictionsProvider._load - Loading restrictions from Supabase...');
    _isLoading = true;
    notifyListeners();

    try {
      _defaultRestrictedApps =
          await _supabaseService.getDefaultRestrictedApps();
      _defaultRestrictedWebsites =
          await _supabaseService.getDefaultRestrictedWebsites();

      debugPrint('✅ RestrictionsProvider._load - Loaded successfully');
      debugPrint(
          '📋 Apps: ${_defaultRestrictedApps.length} items: $_defaultRestrictedApps');
      debugPrint(
          '📋 Websites: ${_defaultRestrictedWebsites.length} items: $_defaultRestrictedWebsites');

      // Notify callback that restrictions loaded
      onRestrictionsChanged?.call(
          _defaultRestrictedApps, _defaultRestrictedWebsites);
    } catch (e, stackTrace) {
      debugPrint(
          '❌ RestrictionsProvider._load - Error loading restrictions: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint('🟢 RestrictionsProvider._load - Load complete');
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  void addApp(String packageName) async {
    debugPrint(
        '🟢 RestrictionsProvider.addApp - ========== ADDING APP ==========');
    debugPrint('🟢 Package name: $packageName');

    if (!_defaultRestrictedApps.contains(packageName)) {
      _defaultRestrictedApps.add(packageName);
      notifyListeners();
      debugPrint(
          '🟢 App added to local list, count: ${_defaultRestrictedApps.length}');

      try {
        debugPrint('🟢 Calling SupabaseService.addDefaultRestriction...');
        await _supabaseService.addDefaultRestriction('app', packageName);
        debugPrint(
            '✅ RestrictionsProvider.addApp - App saved to Supabase successfully!');

        // Notify callback to sync restrictions to native
        onRestrictionsChanged?.call(
            _defaultRestrictedApps, _defaultRestrictedWebsites);

        debugPrint('✅ ========== APP ADD COMPLETE ==========');
      } catch (e, stackTrace) {
        debugPrint('❌❌❌ RestrictionsProvider.addApp - ERROR SAVING ❌❌❌');
        debugPrint('❌ Error: $e');
        debugPrint('📍 Stack trace: $stackTrace');
        // Rollback on error
        _defaultRestrictedApps.remove(packageName);
        notifyListeners();
        debugPrint(
            '❌ App rolled back from local list, count: ${_defaultRestrictedApps.length}');
        rethrow;
      }
    } else {
      debugPrint(
          '⚠️ RestrictionsProvider.addApp - App already in list: $packageName');
    }
  }

  void removeApp(String packageName) async {
    debugPrint(
        '🟢 RestrictionsProvider.removeApp - Removing app: $packageName');
    _defaultRestrictedApps.remove(packageName);
    notifyListeners();
    debugPrint(
        '🟢 App removed from local list, count: ${_defaultRestrictedApps.length}');

    try {
      await _supabaseService.removeDefaultRestriction('app', packageName);
      debugPrint('✅ RestrictionsProvider.removeApp - Removed from Supabase');

      // Notify callback to sync restrictions to native
      onRestrictionsChanged?.call(
          _defaultRestrictedApps, _defaultRestrictedWebsites);
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.removeApp - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _defaultRestrictedApps.add(packageName);
      notifyListeners();
      debugPrint('❌ App removal rolled back');
      rethrow;
    }
  }

  void addWebsite(String domain) async {
    debugPrint('🟢 RestrictionsProvider.addWebsite - Adding website: $domain');
    final cleanDomain = extractDomain(domain);
    debugPrint('🟢 Clean domain: $cleanDomain');

    if (!_defaultRestrictedWebsites.contains(cleanDomain)) {
      _defaultRestrictedWebsites.add(cleanDomain);
      notifyListeners();
      debugPrint(
          '🟢 Website added to local list, count: ${_defaultRestrictedWebsites.length}');

      try {
        await _supabaseService.addDefaultRestriction('website', cleanDomain);
        debugPrint('✅ RestrictionsProvider.addWebsite - Saved to Supabase');

        // Notify callback to sync restrictions to native
        onRestrictionsChanged?.call(
            _defaultRestrictedApps, _defaultRestrictedWebsites);
      } catch (e, stackTrace) {
        debugPrint('❌ RestrictionsProvider.addWebsite - Error: $e');
        debugPrint('📍 Stack trace: $stackTrace');
        // Rollback on error
        _defaultRestrictedWebsites.remove(cleanDomain);
        notifyListeners();
        debugPrint('❌ Website rolled back');
        rethrow;
      }
    } else {
      debugPrint(
          '⚠️ RestrictionsProvider.addWebsite - Already in list: $cleanDomain');
    }
  }

  void removeWebsite(String domain) async {
    debugPrint('🟢 RestrictionsProvider.removeWebsite - Removing: $domain');
    _defaultRestrictedWebsites.remove(domain);
    notifyListeners();
    debugPrint(
        '🟢 Website removed from local list, count: ${_defaultRestrictedWebsites.length}');

    try {
      await _supabaseService.removeDefaultRestriction('website', domain);
      debugPrint(
          '✅ RestrictionsProvider.removeWebsite - Removed from Supabase');

      // Notify callback to sync restrictions to native
      onRestrictionsChanged?.call(
          _defaultRestrictedApps, _defaultRestrictedWebsites);
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.removeWebsite - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _defaultRestrictedWebsites.add(domain);
      notifyListeners();
      debugPrint('❌ Website removal rolled back');
      rethrow;
    }
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

  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    return await _restrictionService.getInstalledApps();
  }
}
