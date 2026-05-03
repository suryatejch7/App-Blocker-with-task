import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RestrictionService {
  static const platform = MethodChannel('com.habittracker/restrictions');

  // Request necessary permissions
  Future<bool> requestPermissions() async {
    try {
      final bool result = await platform.invokeMethod('requestPermissions');
      return result;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  // Check if permissions are granted
  Future<bool> checkPermissions() async {
    try {
      final bool result = await platform.invokeMethod('checkPermissions');
      return result;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  // Check if overlay permission is granted (needed for floating window blocking)
  Future<bool> checkOverlayPermission() async {
    try {
      final bool result = await platform.invokeMethod('checkOverlayPermission');
      return result;
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
      return false;
    }
  }

  // Request overlay permission
  Future<bool> requestOverlayPermission() async {
    try {
      final bool result =
          await platform.invokeMethod('requestOverlayPermission');
      return result;
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
      return false;
    }
  }

  // Update restriction list on native side
  // Now includes task details and permanent block info for enhanced blocking screen
  Future<bool> updateRestrictions(
    List<String> apps,
    List<String> websites,
    bool restrictionsActive, {
    List<Map<String, dynamic>> pendingTasks = const [],
    List<String> permanentlyBlockedApps = const [],
    List<String> permanentlyBlockedWebsites = const [],
  }) async {
    try {
      debugPrint(
          '📡 RestrictionService.updateRestrictions - Sending to native:');
      debugPrint('   Apps (${apps.length}): $apps');
      debugPrint('   Websites (${websites.length}): $websites');
      debugPrint('   Active: $restrictionsActive');
      debugPrint('   Pending tasks: ${pendingTasks.length}');
      debugPrint(
          '   Permanently blocked apps: ${permanentlyBlockedApps.length}');

      final result = await platform.invokeMethod<bool>('updateRestrictions', {
        'apps': apps,
        'websites': websites,
        'active': restrictionsActive,
        'pendingTasks': pendingTasks,
        'permanentlyBlockedApps': permanentlyBlockedApps,
        'permanentlyBlockedWebsites': permanentlyBlockedWebsites,
      });

      final isServiceConnected = result ?? false;
      if (isServiceConnected) {
        debugPrint(
            '✅ RestrictionService.updateRestrictions - Synced to running native service');
      } else {
        debugPrint(
            '⚠️ RestrictionService.updateRestrictions - Native service not connected yet; restrictions saved and will apply when service connects');
      }
      return isServiceConnected;
    } catch (e, stackTrace) {
      debugPrint('❌ RestrictionService.updateRestrictions - Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Start monitoring service
  Future<void> startMonitoring() async {
    try {
      await platform.invokeMethod('startMonitoring');
    } catch (e) {
      debugPrint('Error starting monitoring: $e');
    }
  }

  // Stop monitoring service
  Future<void> stopMonitoring() async {
    try {
      await platform.invokeMethod('stopMonitoring');
    } catch (e) {
      debugPrint('Error stopping monitoring: $e');
    }
  }

  // Show blocking screen when app is blocked
  Future<void> showBlockingScreen(
      List<Map<String, dynamic>> pendingTasks) async {
    try {
      await platform.invokeMethod('showBlockingScreen', {
        'tasks': pendingTasks,
      });
    } catch (e) {
      debugPrint('Error showing blocking screen: $e');
    }
  }
}
