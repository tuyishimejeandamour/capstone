import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/speech_service.dart';
import '../widgets/audio_wave_visualizer.dart';

class SpeechScreen extends StatefulWidget {
  final SpeechService speechService;

  const SpeechScreen({
    super.key,
    required this.speechService,
  });

  @override
  State<SpeechScreen> createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> {
  String _liveTranscript = 'Listening... Speak now';
  bool _isListening = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    widget.speechService.stopListening();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _hasError = false;
      _liveTranscript = 'Initializing...';
    });

    final success = await widget.speechService.initializeSpeech();
    if (!success) {
      setState(() {
        _hasError = true;
        final error = widget.speechService.errorMsg;
        _liveTranscript = error.isNotEmpty ? error : 'Microphone permission denied or speech engine unavailable.';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _liveTranscript = 'Listening... Start speaking';
    });

    await widget.speechService.startListening(
      onResult: (text) {
        setState(() {
          if (text.isNotEmpty) {
            _liveTranscript = text;
          }
        });
      },
      onComplete: () {
        // Automatically close and submit when user pauses speaking
        if (mounted && widget.speechService.lastWords.isNotEmpty) {
          Navigator.pop(context, widget.speechService.lastWords);
        }
      },
    );
  }

  void _finishRecording() {
    widget.speechService.stopListening();
    final finalWords = widget.speechService.lastWords;
    Navigator.pop(context, finalWords.isNotEmpty ? finalWords : null);
  }

  void _cancelRecording() {
    widget.speechService.stopListening();
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E141D).withValues(alpha: 0.96), // Calming Deep Ocean overlay
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Top Bar with Cancel Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 28, color: Colors.white70),
                    onPressed: _cancelRecording,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3BE2B0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF3BE2B0).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3BE2B0),
                            shape: BoxShape.circle,
                          ),
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                         .scale(end: const Offset(1.5, 1.5), duration: 600.ms),
                        const SizedBox(width: 8),
                        const Text(
                          'ON-DEVICE AUDIO',
                          style: TextStyle(
                            color: Color(0xFF3BE2B0),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const Spacer(),

              // Dynamic Speech Output Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF17202C).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF222F3E),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  _liveTranscript,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _liveTranscript.startsWith('Listening') || _liveTranscript.startsWith('Initializing')
                        ? Colors.white38
                        : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    letterSpacing: -0.2,
                  ),
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0.0, curve: Curves.easeOutCubic),

              const Spacer(),

              // Beautiful Custom-Painted Waveform
              AudioWaveVisualizer(isListening: _isListening),

              const SizedBox(height: 32),

              // Central Pulse Recording Button
              GestureDetector(
                onTap: _isListening ? _finishRecording : _startRecording,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _hasError ? const Color(0xFFE56B6B) : const Color(0xFF3BE2B0),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_hasError ? const Color(0xFFE56B6B) : const Color(0xFF3BE2B0)).withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 42,
                      color: const Color(0xFF0E141D),
                    ),
                  ),
                )
                .animate(target: _isListening ? 1.0 : 0.0)
                .custom(
                  duration: 1000.ms,
                  builder: (context, value, child) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF3BE2B0).withValues(alpha: 0.4 * (1.0 - value)),
                        width: 4 * value,
                      ),
                    ),
                    child: child,
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 800.ms),
              ),

              const SizedBox(height: 16),

              Text(
                _isListening ? 'TAP TO SUBMIT' : (_hasError ? 'ERROR OCCURRED' : 'TAP TO RESTART'),
                style: TextStyle(
                  color: _hasError ? const Color(0xFFE56B6B) : const Color(0xFF8FA0B5),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
