/// VIT Bhopal registration number: 2 digits (admission year) + 3 uppercase
/// letters (branch code) + 5 digits, e.g. `23BCE11351`.
final RegExp regNumberPattern = RegExp(r'\b\d{2}[A-Z]{3}\d{5}\b');

/// Extracts the first VIT registration number from raw OCR text
/// (case-insensitive), or null when none is present.
String? extractRegNumber(String rawText) =>
    regNumberPattern.firstMatch(rawText.toUpperCase())?.group(0);
