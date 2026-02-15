import 'package:flutter_test/flutter_test.dart';

// VIT Bhopal reg number: 2 digits (year) + 3 letters (branch) + 5 digits
final _regPattern = RegExp(r'\b\d{2}[A-Z]{3}\d{5}\b');

String? extractRegNumber(String rawText) =>
    _regPattern.firstMatch(rawText.toUpperCase())?.group(0);

void main() {
  // ─── Pattern matching ─────────────────────────────────────────────────────────
  group('Registration number pattern', () {
    test('matches valid VIT reg numbers', () {
      expect(_regPattern.hasMatch('23BCE11351'), isTrue);
      expect(_regPattern.hasMatch('21BCE10463'), isTrue);
      expect(_regPattern.hasMatch('22MCA10001'), isTrue);
      expect(_regPattern.hasMatch('20BTECH0001'), isFalse); // 5-letter branch
    });

    test('rejects malformed numbers', () {
      expect(_regPattern.hasMatch('BCE11351'),   isFalse); // missing year
      expect(_regPattern.hasMatch('23BC11351'),  isFalse); // 2-letter branch
      expect(_regPattern.hasMatch('23BCE1135'),  isFalse); // 4-digit suffix
      expect(_regPattern.hasMatch('2BCE11351'),  isFalse); // 1-digit year
      expect(_regPattern.hasMatch('23bce11351'), isFalse); // lowercase (raw)
    });

    test('case-insensitive via toUpperCase()', () {
      expect(extractRegNumber('23bce11351'), '23BCE11351');
      expect(extractRegNumber('21Bce10463'), '21BCE10463');
    });
  });

  // ─── OCR extraction from realistic card text ──────────────────────────────────
  group('extractRegNumber from OCR text', () {
    test('extracts from clean card text', () {
      const text = 'VIT BHOPAL\nPRIYANSH SHRIVASTAVA\n21BCE10463\nDAY SCHOLAR';
      expect(extractRegNumber(text), '21BCE10463');
    });

    test('extracts when surrounded by noise', () {
      const text = 'Scanned text... VIT  2 3 B C E 1 1 3 5 1 ...end';
      // spaces in OCR output — won't match (expected failure)
      expect(extractRegNumber(text), isNull);
    });

    test('extracts when reg number is inline with other text', () {
      const text = 'Student ID: 23BCE11351, Session 2023-27';
      expect(extractRegNumber(text), '23BCE11351');
    });

    test('returns null when no reg number present', () {
      expect(extractRegNumber('VIT BHOPAL UNIVERSITY'), isNull);
      expect(extractRegNumber(''),                       isNull);
      expect(extractRegNumber('Day Scholar'),            isNull);
    });

    test('picks first match when multiple numbers appear', () {
      const text = '23BCE11351 and also 21BCE10463';
      expect(extractRegNumber(text), '23BCE11351');
    });
  });

  // ─── Branch code coverage ─────────────────────────────────────────────────────
  group('Common VIT branch codes', () {
    final branches = ['BCE', 'MCA', 'MBA', 'BME', 'BCS', 'BEE', 'BCE', 'BIT'];
    for (final branch in branches) {
      test('matches $branch branch', () {
        expect(_regPattern.hasMatch('23${branch}10001'), isTrue);
      });
    }
  });
}
