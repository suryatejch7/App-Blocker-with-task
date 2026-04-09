import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker_flutter/services/backup_service.dart';

/// Tests for backup and restore functionality
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService Tests', () {
    late BackupService backupService;

    setUpAll(() {
      backupService = BackupService();
    });

    test('BackupService should be a singleton', () {
      final service1 = BackupService();
      final service2 = BackupService();
      expect(service1, same(service2));
    });

    test('BackupService should have backup methods', () {
      expect(backupService.backupToFile, isA<Function>());
      expect(backupService.restoreFromFile, isA<Function>());
      expect(backupService.hasBackupFile, isA<Function>());
      expect(backupService.getBackupFileTime, isA<Function>());
    });
  });
}
