import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

String sanitizeTextForSpeech(String text) {
  final cleanText = text
      .replaceAll('\u{FE0F}', '')
      .replaceAll('\u{1F3E5}', '')
      .replaceAll('\u{1F4CD}', '')
      .replaceAll('\u{23F0}', '')
      .replaceAll('\u{1F4DE}', '')
      .replaceAll('\u{1F9E0}', '')
      .replaceAll('\u{1F6A8}', '')
      .replaceAll('\u{1F4DD}', '')
      .replaceAll('\u{1F3E8}', '')
      .replaceAll('\u{1F48A}', '')
      .replaceAll('\u{1F5D1}', '')
      .replaceAll('\u{2139}', '')
      .replaceAll('\u{26A0}', '')
      .replaceAll('\u{2705}', '')
      .replaceAll('\u{1F4E1}', '')
      .replaceAll('\u{1F527}', '')
      .replaceAll(RegExp(r'\*+'), '')
      .replaceAll(RegExp(r'#+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return cleanText;
}

class TtsService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  bool _isEnabled = true; // Enabled by default as requested

  bool get isPlaying => _isPlaying;
  bool get isEnabled => _isEnabled;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage('en-US');

    // Attempt to find a high-quality voice
    try {
      final List<dynamic>? voices = await _flutterTts.getVoices;
      if (voices != null) {
        final enVoices = voices.where((v) {
          final locale = v['locale']?.toString() ?? '';
          return locale.startsWith('en-US') || locale == 'en_US';
        }).toList();

        Map<dynamic, dynamic>? bestVoice;
        for (var v in enVoices) {
          final name = v['name']?.toString().toLowerCase() ?? '';
          if (name.contains('siri') ||
              name.contains('enhanced') ||
              name.contains('premium') ||
              name.contains('neural')) {
            bestVoice = v as Map<dynamic, dynamic>;
            break;
          }
        }
        // Fallback to first en-US voice if no enhanced one found
        bestVoice ??= enVoices.isNotEmpty
            ? enVoices.first as Map<dynamic, dynamic>
            : null;

        if (bestVoice != null) {
          await _flutterTts.setVoice({
            "name": bestVoice['name']?.toString() ?? "",
            "locale": bestVoice['locale']?.toString() ?? "",
          });
        }
      }
    } catch (e) {
      debugPrint("Error setting voice: $e");
    }

    // Comfortable, reassuring, warm voice profile settings
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.1);
    await _flutterTts.setVolume(1.0);

    _flutterTts.setStartHandler(() {
      _isPlaying = true;
      notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      notifyListeners();
    });

    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      notifyListeners();
    });

    _flutterTts.setErrorHandler((msg) {
      _isPlaying = false;
      notifyListeners();
    });
  }

  /// Toggle whether automatic TTS narration is active
  void setEnabled(bool value) {
    _isEnabled = value;
    if (!_isEnabled) {
      stop();
    }
    notifyListeners();
  }

  /// Narrates a text block aloud if TTS is enabled
  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;

    final cleanText = sanitizeTextForSpeech(text);

    await _flutterTts.stop();
    await _flutterTts.speak(cleanText);
  }

  /// Cancel current narration
  Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
    notifyListeners();
  }
}
