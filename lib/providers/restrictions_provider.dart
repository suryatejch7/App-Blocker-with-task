import 'package:flutter/foundation.dart';
import '../services/restriction_service.dart';
import '../services/offline_cache_service.dart';

class RestrictionsProvider extends ChangeNotifier {
  // Default restrictions (used when task has 'default' mode)
  List<String> _defaultRestrictedApps = [];
  List<String> _defaultRestrictedWebsites = [];

  // Permanently blocked apps/websites (always blocked, no task needed)
  List<String> _permanentlyBlockedApps = [];
  List<String> _permanentlyBlockedWebsites = [];

  final RestrictionService _restrictionService = RestrictionService();
  final _offlineCacheService = OfflineCacheService();
  bool _isLoading = false;

  // Track pending operations to prevent race conditions
  final Set<String> _pendingOperations = {};

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
    debugPrint('🟢 RestrictionsProvider._load - Loading local restrictions...');
    _isLoading = true;
    notifyListeners();

    try {
      if (!_offlineCacheService.isInitialized) {
        await _offlineCacheService.initialize();
      }

      _defaultRestrictedApps = _offlineCacheService.getCachedDefaultApps();
      _defaultRestrictedWebsites =
          _offlineCacheService.getCachedDefaultWebsites();
      _permanentlyBlockedApps = _offlineCacheService.getCachedPermanentApps();
      _permanentlyBlockedWebsites =
          _offlineCacheService.getCachedPermanentWebsites();

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

  Future<void> _persistAllRestrictions() async {
    await _offlineCacheService.saveRestrictions(
      defaultApps: _defaultRestrictedApps,
      defaultWebsites: _defaultRestrictedWebsites,
      permanentApps: _permanentlyBlockedApps,
      permanentWebsites: _permanentlyBlockedWebsites,
    );
  }

  Future<void> refresh() async {
    await _load();
  }

  /// Adds an app to default restrictions with optimistic update.
  /// Returns true if successful, false if already exists or operation pending.
  Future<bool> addApp(String packageName) async {
    // Prevent duplicate operations
    final operationKey = 'addApp_$packageName';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ RestrictionsProvider.addApp - Operation already pending for $packageName');
      return false;
    }

    debugPrint(
        '🟢 RestrictionsProvider.addApp - ========== ADDING APP ==========');
    debugPrint('🟢 Package name: $packageName');

    if (_defaultRestrictedApps.contains(packageName)) {
      debugPrint(
          '⚠️ RestrictionsProvider.addApp - App already in list: $packageName');
      return false;
    }

    _pendingOperations.add(operationKey);
    _defaultRestrictedApps.add(packageName);
    notifyListeners();
    debugPrint(
        '🟢 App added to local list, count: ${_defaultRestrictedApps.length}');

    try {
      debugPrint('🟢 Saving default restrictions locally...');
      await _persistAllRestrictions();
      debugPrint('✅ RestrictionsProvider.addApp - App saved locally!');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();

      debugPrint('✅ ========== APP ADD COMPLETE ==========');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ RestrictionsProvider.addApp - ERROR SAVING ❌❌❌');
      debugPrint('❌ Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _defaultRestrictedApps.remove(packageName);
      notifyListeners();
      debugPrint(
          '❌ App rolled back from local list, count: ${_defaultRestrictedApps.length}');
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  /// Removes an app from default restrictions with optimistic update.
  /// Returns true if successful, false if not found or operation pending.
  Future<bool> removeApp(String packageName) async {
    // Prevent duplicate operations
    final operationKey = 'removeApp_$packageName';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ RestrictionsProvider.removeApp - Operation already pending for $packageName');
      return false;
    }

    if (!_defaultRestrictedApps.contains(packageName)) {
      debugPrint(
          '⚠️ RestrictionsProvider.removeApp - App not in list: $packageName');
      return false;
    }

    _pendingOperations.add(operationKey);
    debugPrint(
        '🟢 RestrictionsProvider.removeApp - Removing app: $packageName');
    _defaultRestrictedApps.remove(packageName);
    notifyListeners();
    debugPrint(
        '🟢 App removed from local list, count: ${_defaultRestrictedApps.length}');

    try {
      await _persistAllRestrictions();
      debugPrint('✅ RestrictionsProvider.removeApp - Removed locally');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.removeApp - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _defaultRestrictedApps.add(packageName);
      notifyListeners();
      debugPrint('❌ App removal rolled back');
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  /// Adds a website to default restrictions with optimistic update.
  /// Returns true if successful, false if already exists or operation pending.
  Future<bool> addWebsite(String domain) async {
    final cleanDomain = extractDomain(domain);

    // Prevent duplicate operations
    final operationKey = 'addWebsite_$cleanDomain';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ RestrictionsProvider.addWebsite - Operation already pending for $cleanDomain');
      return false;
    }

    debugPrint('🟢 RestrictionsProvider.addWebsite - Adding website: $domain');
    debugPrint('🟢 Clean domain: $cleanDomain');

    if (_defaultRestrictedWebsites.contains(cleanDomain)) {
      debugPrint(
          '⚠️ RestrictionsProvider.addWebsite - Already in list: $cleanDomain');
      return false;
    }

    _pendingOperations.add(operationKey);
    _defaultRestrictedWebsites.add(cleanDomain);
    notifyListeners();
    debugPrint(
        '🟢 Website added to local list, count: ${_defaultRestrictedWebsites.length}');

    try {
      await _persistAllRestrictions();
      debugPrint('✅ RestrictionsProvider.addWebsite - Saved locally');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.addWebsite - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _defaultRestrictedWebsites.remove(cleanDomain);
      notifyListeners();
      debugPrint('❌ Website rolled back');
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  /// Removes a website from default restrictions with optimistic update.
  /// Returns true if successful, false if not found or operation pending.
  Future<bool> removeWebsite(String domain) async {
    // Prevent duplicate operations
    final operationKey = 'removeWebsite_$domain';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ RestrictionsProvider.removeWebsite - Operation already pending for $domain');
      return false;
    }

    if (!_defaultRestrictedWebsites.contains(domain)) {
      debugPrint(
          '⚠️ RestrictionsProvider.removeWebsite - Website not in list: $domain');
      return false;
    }

    _pendingOperations.add(operationKey);
    debugPrint('🟢 RestrictionsProvider.removeWebsite - Removing: $domain');
    _defaultRestrictedWebsites.remove(domain);
    notifyListeners();
    debugPrint(
        '🟢 Website removed from local list, count: ${_defaultRestrictedWebsites.length}');

    try {
      await _persistAllRestrictions();
      debugPrint('✅ RestrictionsProvider.removeWebsite - Removed locally');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.removeWebsite - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _defaultRestrictedWebsites.add(domain);
      notifyListeners();
      debugPrint('❌ Website removal rolled back');
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
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

  /// Adds an app to permanent block list with optimistic update.
  /// Returns true if successful, false if already exists or operation pending.
  Future<bool> addPermanentApp(String packageName) async {
    // Prevent duplicate operations
    final operationKey = 'addPermanentApp_$packageName';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ RestrictionsProvider.addPermanentApp - Operation already pending for $packageName');
      return false;
    }

    debugPrint(
        '🔒 RestrictionsProvider.addPermanentApp - ========== ADDING PERMANENT APP ==========');
    debugPrint('🔒 Package name: $packageName');

    if (_permanentlyBlockedApps.contains(packageName)) {
      debugPrint(
          '⚠️ RestrictionsProvider.addPermanentApp - Already in list: $packageName');
      return false;
    }

    _pendingOperations.add(operationKey);
    _permanentlyBlockedApps.add(packageName);
    notifyListeners();
    debugPrint(
        '🔒 App added to permanent list, count: ${_permanentlyBlockedApps.length}');

    try {
      debugPrint('🔒 Saving permanent restrictions locally...');
      await _persistAllRestrictions();
      debugPrint('✅ RestrictionsProvider.addPermanentApp - Saved locally!');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();

      debugPrint('✅ ========== PERMANENT APP ADD COMPLETE ==========');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ RestrictionsProvider.addPermanentApp - ERROR ❌❌❌');
      debugPrint('❌ Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _permanentlyBlockedApps.remove(packageName);
      notifyListeners();
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  /// Removes an app from permanent block list with optimistic update.
  /// Returns true if successful, false if not found or operation pending.
  Future<bool> removePermanentApp(String packageName) async {
    // Prevent duplicate operations
    final operationKey = 'removePermanentApp_$packageName';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ RestrictionsProvider.removePermanentApp - Operation already pending for $packageName');
      return false;
    }

    if (!_permanentlyBlockedApps.contains(packageName)) {
      debugPrint(
          '⚠️ RestrictionsProvider.removePermanentApp - App not in list: $packageName');
      return false;
    }

    _pendingOperations.add(operationKey);
    debugPrint(
        '🔒 RestrictionsProvider.removePermanentApp - Removing: $packageName');
    _permanentlyBlockedApps.remove(packageName);
    notifyListeners();
    debugPrint(
        '🔒 App removed from permanent list, count: ${_permanentlyBlockedApps.length}');

    try {
      await _persistAllRestrictions();
      debugPrint('✅ RestrictionsProvider.removePermanentApp - Removed locally');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.removePermanentApp - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _permanentlyBlockedApps.add(packageName);
      notifyListeners();
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  /// Adds a website to permanent block list with optimistic update.
  /// Returns true if successful, false if already exists or operation pending.
  Future<bool> addPermanentWebsite(String domain) async {
    final cleanDomain = extractDomain(domain);

    // Prevent duplicate operations
    final operationKey = 'addPermanentWebsite_$cleanDomain';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ RestrictionsProvider.addPermanentWebsite - Operation already pending for $cleanDomain');
      return false;
    }

    debugPrint('🔒 RestrictionsProvider.addPermanentWebsite - Adding: $domain');
    debugPrint('🔒 Clean domain: $cleanDomain');

    if (_permanentlyBlockedWebsites.contains(cleanDomain)) {
      debugPrint(
          '⚠️ RestrictionsProvider.addPermanentWebsite - Already in list: $cleanDomain');
      return false;
    }

    _pendingOperations.add(operationKey);
    _permanentlyBlockedWebsites.add(cleanDomain);
    notifyListeners();
    debugPrint(
        '🔒 Website added to permanent list, count: ${_permanentlyBlockedWebsites.length}');

    try {
      await _persistAllRestrictions();
      debugPrint('✅ RestrictionsProvider.addPermanentWebsite - Saved locally');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.addPermanentWebsite - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _permanentlyBlockedWebsites.remove(cleanDomain);
      notifyListeners();
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
    }
  }

  /// Removes a website from permanent block list with optimistic update.
  /// Returns true if successful, false if not found or operation pending.
  Future<bool> removePermanentWebsite(String domain) async {
    // Prevent duplicate operations
    final operationKey = 'removePermanentWebsite_$domain';
    if (_pendingOperations.contains(operationKey)) {
      debugPrint(
          '⚠️ RestrictionsProvider.removePermanentWebsite - Operation already pending for $domain');
      return false;
    }

    if (!_permanentlyBlockedWebsites.contains(domain)) {
      debugPrint(
          '⚠️ RestrictionsProvider.removePermanentWebsite - Website not in list: $domain');
      return false;
    }

    _pendingOperations.add(operationKey);
    debugPrint(
        '🔒 RestrictionsProvider.removePermanentWebsite - Removing: $domain');
    _permanentlyBlockedWebsites.remove(domain);
    notifyListeners();
    debugPrint(
        '🔒 Website removed from permanent list, count: ${_permanentlyBlockedWebsites.length}');

    try {
      await _persistAllRestrictions();
      debugPrint(
          '✅ RestrictionsProvider.removePermanentWebsite - Removed locally');

      // Notify callback to sync restrictions to native
      _notifyRestrictionsChanged();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionsProvider.removePermanentWebsite - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // Rollback on error
      _permanentlyBlockedWebsites.add(domain);
      notifyListeners();
      return false;
    } finally {
      _pendingOperations.remove(operationKey);
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
