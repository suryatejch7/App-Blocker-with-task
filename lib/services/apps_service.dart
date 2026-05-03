import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AppsService {
  static const platform = MethodChannel('com.habittracker/restrictions');

  Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final List<dynamic> result =
          await platform.invokeMethod('getInstalledApps');
      return result.map((app) => Map<String, String>.from(app)).toList();
    } catch (e) {
      debugPrint('Error getting installed apps: $e');
      return [];
    }
  }
}
