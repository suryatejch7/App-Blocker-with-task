import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker_flutter/providers/restrictions_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestrictionsProvider Tests', () {
    late RestrictionsProvider provider;

    setUp(() {
      provider = RestrictionsProvider();
    });

    test('extractDomain should handle various URL formats', () {
      expect(provider.extractDomain('https://www.youtube.com/watch?v=123'),
          'youtube.com');
      expect(provider.extractDomain('http://facebook.com/profile'),
          'facebook.com');
      expect(provider.extractDomain('www.instagram.com'), 'instagram.com');
      expect(provider.extractDomain('twitter.com'), 'twitter.com');
      expect(
          provider.extractDomain('https://reddit.com/r/flutter'), 'reddit.com');
      expect(provider.extractDomain('https://www.google.com/search'),
          'google.com');
    });

    test('extractDomain should handle complex URLs', () {
      expect(provider.extractDomain('https://sub.example.com/path'),
          'sub.example.com');
      expect(provider.extractDomain('http://www.test.co.uk'), 'test.co.uk');
      expect(provider.extractDomain('example.org'), 'example.org');
    });

    test('extractDomain should handle edge cases', () {
      expect(provider.extractDomain(''), '');
      expect(provider.extractDomain('https://'), '');
      expect(provider.extractDomain('www.'), '');
    });

    test('Provider should initialize and attempt to load', () {
      final newProvider = RestrictionsProvider();

      // Provider starts loading immediately from Supabase
      // Empty initially because it's loading
      expect(newProvider.defaultRestrictedApps, isEmpty);
      expect(newProvider.defaultRestrictedWebsites, isEmpty);
    });
  });

  group('Domain Extraction Edge Cases', () {
    late RestrictionsProvider provider;

    setUp(() {
      provider = RestrictionsProvider();
    });

    test('Should handle URLs with ports', () {
      // Port numbers are stripped by the implementation
      expect(provider.extractDomain('http://localhost:3000'), 'localhost');
      expect(provider.extractDomain('https://example.com:8080/api'),
          'example.com');
    });

    test('Should handle URLs with subdomains', () {
      expect(
          provider.extractDomain('https://api.github.com'), 'api.github.com');
      expect(provider.extractDomain('mail.google.com'), 'mail.google.com');
      expect(
          provider.extractDomain('www.blog.example.com'), 'blog.example.com');
    });

    test('Should handle URLs with query parameters', () {
      expect(provider.extractDomain('https://youtube.com/watch?v=abc123&t=10'),
          'youtube.com');
      expect(provider.extractDomain('https://www.google.com/search?q=flutter'),
          'google.com');
    });

    test('Should handle URLs with fragments', () {
      expect(provider.extractDomain('https://example.com/page#section'),
          'example.com');
      expect(
          provider.extractDomain('www.reddit.com/r/flutter#top'), 'reddit.com');
    });
  });
}
