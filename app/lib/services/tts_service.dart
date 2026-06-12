import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
          if (name.contains('siri') || name.contains('enhanced') || name.contains('premium') || name.contains('neural')) {
            bestVoice = v as Map<dynamic, dynamic>;
            break;
          }
        }
        // Fallback to first en-US voice if no enhanced one found
        bestVoice ??= enVoices.isNotEmpty ? enVoices.first as Map<dynamic, dynamic> : null;
        
        if (bestVoice != null) {
          await _flutterTts.setVoice({"name": bestVoice['name']?.toString() ?? "", "locale": bestVoice['locale']?.toString() ?? ""});
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
    
    // Clean up Markdown before speaking
    final cleanText = text
        .replaceAll(RegExp(r'\*+'), '') // Remove bold asterisks
        .replaceAll(RegExp(r'#+'), '')  // Remove heading hashes
        .replaceAll(RegExp(r'🏥|📍|⏰|📞|🧠|🚨|📝|🏨'), ''); // Remove emojis

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
