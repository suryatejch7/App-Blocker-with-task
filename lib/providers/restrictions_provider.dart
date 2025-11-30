import 'package:flutter/foundation.dart';
import '../services/restriction_service.dart';
import '../services/supabase_service.dart';

class RestrictionsProvider extends ChangeNotifier {
  // Default restrictions (used when task has 'default' mode)
  List<String> _defaultRestrictedApps = [];
  List<String> _defaultRestrictedWebsites = [];

  // Permanently blocked apps/websites (always blocked, no task needed)
  List<String> _permanentlyBlockedApps = [];
  List<String> _permanentlyBlockedWebsites = [];

  final RestrictionService _restrictionService = RestrictionService();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  // Callback to notify when restrictions change (for TaskProvider to sync)
  // Now includes both default and permanent restrictions
  Function(
      List<String> defaultApps,
      List<String> defaultWebsites,
      List<String> permanentApps,
      List<String> permanentWebsites)? onRestrictionsChanged;

  List<String> get defaultRestrictedApps => _defaultRestrictedApps;
  List<String> get defaultRestrictedWebsites => _defaultRestrictedWebsites;
  List<String> get permanentlyBlockedApps => _permanentlyBlockedApps;
  List<String> get permanentlyBlockedWebsites => _permanentlyBlockedWebsites;
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
      // Load default restrictions
      _defaultRestrictedApps =
          await _supabaseService.getDefaultRestrictedApps();
      _defaultRestrictedWebsites =
          await _supabaseService.getDefaultRestrictedWebsites();

      // Load permanent blocks
      _permanentlyBlockedApps =
          await _supabaseService.getPermanentlyBlockedApps();
      _permanentlyBlockedWebsites =
          await _supabaseService.getPermanentlyBlockedWebsites();

      debugPrint('✅ RestrictionsProvider._load - Loaded successfully');
      debugPrint(
          '📋 Default Apps: ${_defaultRestrictedApps.length} items: $_defaultRestrictedApps');
      debugPrint(
          '📋 Default Websites: ${_defaultRestrictedWebsites.length} items: $_defaultRestrictedWebsites');
      debugPrint(
          '🔒 Permanent Apps: ${_permanentlyBlockedApps.length} items: $_permanentlyBlockedApps');
      debugPrint(
          '🔒 Permanent Websites: ${_permanentlyBlockedWebsites.length} items: $_permanentlyBlockedWebsites');

      // Notify callback that restrictions loaded
      _notifyRestrictionsChanged();
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

  void _notifyRestrictionsChanged() {
    onRestrictionsChanged?.call(
        _defaultRestrictedApps,
        _defaultRestrictedWebsites,
        _permanentlyBlockedApps,
        _permanentlyBlockedWebsites);
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
        _notifyRestrictionsChanged();

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
      _notifyRestrictionsChanged();
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
        _notifyRestrictionsChanged();
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
      _notifyRestrictionsChanged();
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

  // ==================== PERMANENT BLOCKING METHODS ====================

  void addPermanentApp(String packageName) async {
    debugPrint(
        '🔒 RestrictionsProvider.addPermanentApp - ========== ADDING PERMANENT APP ==========');
    debugPrint('🔒 Package name: $packageName');

    if (!_permanentlyBlockedApps.contains(packageName)) {
      _permanentlyBlockedApps.add(packageName);
      notifyListeners();
      debugPrint(
          '🔒 App added to permanent list, count: ${_permanentlyBlockedApps.length}');

      try {
        debugPrint('🔒 Calling SupabaseService.addPermanentBlock...');
        await _supabaseService.addPermanentBlock('app', packageName);
        debugPrint(
            '✅ RestrictionsProvider.addPermanentApp - Saved to Supabase!');

        // Notify callback to sync restrictions to native
        _notifyRestrictionsChanged();

        debugPrint('✅ ========== PERMANENT APP ADD COMPLETE ==========');
      } catch (e, stackTrace) {
        debugPrint('❌❌❌ RestrictionsProvider.addPermanentApp - ERROR ❌❌❌');
        debugPrint('❌ Error: $e');
        debugPrint('📍 Stack trace: $stackTrace');
        // Rollback on error
        _permanentlyBlockedApps.remove(packageName);
        notifyListeners();
        rethrow;
      }
    } else {
      debugPrint(
          '⚠️ RestrictionsProvider.addPermanentApp - Already in list: $packageName');
    }
  }

  void removePermanentApp(String packageName) async {
    debugPrint(
        '🔒 RestrictionsProvider.removePermanentApp - Removing: $packageName');
    _permanentlyBlockedApps.remove(packageName);
    notifyListeners();
    debugPrint(
        '🔒 App removed from permanent list, count: ${_permanentlyBlockedApps.length}');

    try {
      await _supabaseService.removePermanentBlock('app', packageName);
      debugPrint(
          '✅ RestrictionsProvider.removePermanentApp - Removed from Supabase');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.removePermanentApp - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _permanentlyBlockedApps.add(packageName);
      notifyListeners();
      rethrow;
    }
  }

  void addPermanentWebsite(String domain) async {
    debugPrint('🔒 RestrictionsProvider.addPermanentWebsite - Adding: $domain');
    final cleanDomain = extractDomain(domain);
    debugPrint('🔒 Clean domain: $cleanDomain');

    if (!_permanentlyBlockedWebsites.contains(cleanDomain)) {
      _permanentlyBlockedWebsites.add(cleanDomain);
      notifyListeners();
      debugPrint(
          '🔒 Website added to permanent list, count: ${_permanentlyBlockedWebsites.length}');

      try {
        await _supabaseService.addPermanentBlock('website', cleanDomain);
        debugPrint(
            '✅ RestrictionsProvider.addPermanentWebsite - Saved to Supabase');

        // Notify callback to sync restrictions to native
        _notifyRestrictionsChanged();
      } catch (e, stackTrace) {
        debugPrint('❌ RestrictionsProvider.addPermanentWebsite - Error: $e');
        debugPrint('📍 Stack trace: $stackTrace');
        // Rollback on error
        _permanentlyBlockedWebsites.remove(cleanDomain);
        notifyListeners();
        rethrow;
      }
    } else {
      debugPrint(
          '⚠️ RestrictionsProvider.addPermanentWebsite - Already in list: $cleanDomain');
    }
  }

  void removePermanentWebsite(String domain) async {
    debugPrint(
        '🔒 RestrictionsProvider.removePermanentWebsite - Removing: $domain');
    _permanentlyBlockedWebsites.remove(domain);
    notifyListeners();
    debugPrint(
        '🔒 Website removed from permanent list, count: ${_permanentlyBlockedWebsites.length}');

    try {
      await _supabaseService.removePermanentBlock('website', domain);
      debugPrint(
          '✅ RestrictionsProvider.removePermanentWebsite - Removed from Supabase');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.removePermanentWebsite - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _permanentlyBlockedWebsites.add(domain);
      notifyListeners();
      rethrow;
    }
  }

  /// Check if an app is permanently blocked
  bool isAppPermanentlyBlocked(String packageName) {
    return _permanentlyBlockedApps.contains(packageName);
  }

  /// Check if a website is permanently blocked
  bool isWebsitePermanentlyBlocked(String domain) {
    return _permanentlyBlockedWebsites.contains(domain);
  }
}
