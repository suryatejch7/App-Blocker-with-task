import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker_flutter/services/offline_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineCacheService - Basic Tests', () {
    test('OfflineCacheService should be a singleton', () {
      final service1 = OfflineCacheService();
      final service2 = OfflineCacheService();
      expect(service1, same(service2));
    });

    test('OfflineCacheService should have cache methods', () {
      final service = OfflineCacheService();
      expect(service.getCachedTasks, isA<Function>());
      expect(service.cacheTasks, isA<Function>());
      expect(service.upsertTask, isA<Function>());
    });
  });
}
