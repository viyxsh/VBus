import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  static final Map<String, OnDeviceTranslator> _translators = {};

  /// Returns true if [text] contains Devanagari script characters (Hindi).
  static bool isHindi(String text) {
    return text.contains(RegExp(r'[\u0900-\u097F]'));
  }

  static TranslateLanguage _targetFor(String text) =>
      isHindi(text) ? TranslateLanguage.english : TranslateLanguage.hindi;

  static TranslateLanguage _sourceFor(String text) =>
      isHindi(text) ? TranslateLanguage.hindi : TranslateLanguage.english;

  static String _modelKey(TranslateLanguage a, TranslateLanguage b) =>
      '${a.name}_${b.name}';

  static OnDeviceTranslator _translator(
      TranslateLanguage source, TranslateLanguage target) {
    final key = _modelKey(source, target);
    return _translators.putIfAbsent(
        key, () => OnDeviceTranslator(sourceLanguage: source, targetLanguage: target));
  }

  /// Translates [text] between Hindi and English.
  /// Downloads the model if not already on-device.
  static Future<String> translate(String text) async {
    final source = _sourceFor(text);
    final target = _targetFor(text);
    final t = _translator(source, target);
    return t.translateText(text);
  }

  /// Pre-downloads the Hindi and English language models so the first
  /// translation is instant. Call once at app start or when the user first
  /// opens chat.
  static Future<void> warmUp() async {
    final codes = ['hi', 'en'];
    final manager = OnDeviceTranslatorModelManager();
    for (final code in codes) {
      final isDownloaded = await manager.isModelDownloaded(code);
      if (!isDownloaded) {
        await manager.downloadModel(code);
      }
    }
  }
}
