import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';
  String _errorMsg = '';

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String get errorMsg => _errorMsg;

  /// Check permissions and initialize speech engine.
  Future<bool> initializeSpeech() async {
    if (_isInitialized) return true;
    _errorMsg = '';

    // Request microphone and speech permissions explicitly
    final status = await Permission.microphone.request();
    await Permission.speech.request(); // Requested but not strictly gated for Android
    
    if (status != PermissionStatus.granted) {
      _errorMsg = 'Microphone permission denied.';
      _isInitialized = false;
      return false;
    }

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'listening') {
            _isListening = true;
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
          notifyListeners();
        },
        onError: (errorNotification) {
          _isListening = false;
          _errorMsg = 'Error: ${errorNotification.errorMsg}';
          debugPrint('Speech engine error: ${errorNotification.errorMsg}');
          notifyListeners();
        },
      );
      if (!_isInitialized) {
        _errorMsg = 'Speech engine unavailable on this device.';
      }
    } catch (e) {
      _isInitialized = false;
      _errorMsg = 'Initialization failed: $e';
      debugPrint('Speech init exception: $e');
    }
    
    notifyListeners();
    return _isInitialized;
  }

  /// Start recording voice and run the callback on recognition.
  Future<void> startListening({
    required Function(String) onResult,
    required VoidCallback onComplete,
  }) async {
    if (!_isInitialized) {
      final ok = await initializeSpeech();
      if (!ok) return;
    }

    _lastWords = '';
    _isListening = true;
    notifyListeners();

    try {
      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          onResult(_lastWords);
          
          if (result.finalResult) {
            _isListening = false;
            notifyListeners();
            onComplete();
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 2),
          cancelOnError: true,
        ),
      );
    } catch (e) {
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop active listening.
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    }
  }
}
