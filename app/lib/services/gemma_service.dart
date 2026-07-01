import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'clinic_insurance_tool.dart';
import 'curated_hospitals.dart';

/// Manages Gemma model lifecycle: download, initialization, inference.
///
/// Platform-aware model selection:
/// - Android: Gemma 4 E2B (.litertlm, 2.4 GB) via LiteRT-LM
/// - iOS: Gemma 3 1B IT (.task, 0.5 GB) via MediaPipe
///   (.litertlm crashes on iOS — Metal GPU delegate not supported yet)
class GemmaService extends ChangeNotifier {
  // Gemma 4 E2B via LiteRT-LM — public, no HuggingFace auth needed.
  // Android only. iOS support pending Google's LiteRT-LM Swift API.
  static const String _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  static const int _maxTokens = 2048;
  static const int _maxGenerationTokens = 512;

  InferenceModel? _model;
  InferenceChat? _chat;

  GemmaService();

  GemmaServiceState _state = GemmaServiceState.uninitialized;
  double _downloadProgress = 0.0;
  String? _error;
  bool _frameworkInitialized = false;
  Future<void>? _downloadFuture;

  // Performance tracking
  int _tokensGenerated = 0;
  final Stopwatch _generationStopwatch = Stopwatch();
  bool _lastGenerationTruncated = false;

  GemmaServiceState get state => _state;
  double get downloadProgress => _downloadProgress;
  String? get error => _error;
  bool get isReady => _state == GemmaServiceState.ready;
  bool get isGenerating => _state == GemmaServiceState.generating;
  int get tokensGenerated => _tokensGenerated;

  /// True if the most recent generation hit [_maxGenerationTokens] before
  /// the model emitted EOS. Consumers can surface a truncation hint to the
  /// user. Reset at the start of each [sendMessage].
  bool get wasLastGenerationTruncated => _lastGenerationTruncated;

  /// Initialize the FlutterGemma framework. Idempotent — safe to call from
  /// the setup flow so a failure surfaces through the normal retry path.
  Future<void> initFramework({String? huggingFaceToken}) async {
    if (_frameworkInitialized) return;
    await FlutterGemma.initialize(
      huggingFaceToken: huggingFaceToken,
      maxDownloadRetries: 10,
    );
    _frameworkInitialized = true;
  }

  /// Check if the model is already installed locally.
  /// Requires the file to be at least 2.3 GB — anything smaller is an incomplete/corrupt download.
  Future<bool> isModelInstalled() async {
    if (FlutterGemma.hasActiveModel()) {
      return true;
    }
    
    // Check if the model file is already present on disk in applicationDocumentsDirectory.
    // Minimum size = 2.3 GB. The full Gemma 4 E2B is ~2.59 GB.
    // Anything below this threshold is a partial or corrupted download.
    const int minimumValidSizeBytes = 2300 * 1024 * 1024; // 2.3 GB
    final docsDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${docsDir.path}/gemma-model.litertlm');
    
    if (await modelFile.exists()) {
      final fileSize = await modelFile.length();
      if (fileSize < minimumValidSizeBytes) {
        debugPrint('⚠️ GemmaService: Model file too small (${ (fileSize / 1e9).toStringAsFixed(2)} GB < 2.3 GB minimum). Treating as incomplete.');
        return false;
      }
      debugPrint('📡 GemmaService: Model file found on disk (${(fileSize / 1e9).toStringAsFixed(2)} GB). Registering as active...');
      try {
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
          fileType: ModelFileType.litertlm,
        )
            .fromFile(modelFile.path)
            .install();
        return true;
      } catch (e) {
        debugPrint('⚠️ GemmaService: Failed to register existing model file: $e');
        return false;
      }
    }
    
    return false;
  }

  /// Download and install the Gemma 4 E2B model using a custom dart:io
  /// HTTP range-request downloader. This completely bypasses background_downloader's
  /// ETag validation (which fails on HuggingFace's CDN load balancers) and instead
  /// resumes directly from the existing file byte offset on every retry.
  Future<void> downloadModel() async {
    if (_downloadFuture != null) {
      debugPrint('📡 GemmaService: Download is already running. Waiting for completion...');
      await _downloadFuture;
      return;
    }

    if (_state == GemmaServiceState.loading ||
        _state == GemmaServiceState.generating) {
      throw StateError('Cannot start download while ${_state.name}.');
    }

    final completer = Completer<void>();
    _downloadFuture = completer.future;

    _state = GemmaServiceState.downloading;
    _error = null;
    notifyListeners();

    try {
      final absolutePath = await _downloadWithResume();

      debugPrint('📡 GemmaService: Installing model from: $absolutePath');
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      )
          .fromFile(absolutePath)
          .install();

      _state = GemmaServiceState.downloaded;
      notifyListeners();
      completer.complete();
    } catch (e) {
      _state = GemmaServiceState.error;
      _error = 'Download failed: $e';
      notifyListeners();
      completer.completeError(e);
      rethrow;
    } finally {
      _downloadFuture = null;
    }
  }

  /// Performs a resumable HTTP GET using dart:io HttpClient.
  ///
  /// Strategy:
  ///   1. Determine how many bytes already exist in the temp file (0 on first run).
  ///   2. Send `Range: bytes=<existingBytes>-` to continue from that offset.
  ///   3. Pipe the response body into the file in append mode.
  ///   4. Retry up to [maxAttempts] times on any network error, each time
  ///      re-reading the file size so we resume at the new offset.
  ///
  /// HuggingFace Cloudfront CDN returns different ETags across load-balanced
  /// servers, making background_downloader's ETag check always fail and reset
  /// to 0%. We skip ETag entirely — HTTP range-requests are enough for correct
  /// resumption because HuggingFace supports `Accept-Ranges: bytes`.
  Future<String> _downloadWithResume({int maxAttempts = 20}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tempFile = File('${docsDir.path}/gemma-model.litertlm');

    // --- Get total file size once from a HEAD request ---
    int totalBytes = 0;
    {
      final client = HttpClient();
      try {
        final req = await client.headUrl(Uri.parse(_modelUrl));
        req.headers.set(HttpHeaders.userAgentHeader, 'GemmaStudentApp/1.0');
        final res = await req.close();
        totalBytes = res.contentLength;
        debugPrint('📡 Resume downloader: Total size = ${(totalBytes / 1e9).toStringAsFixed(2)} GB');
      } finally {
        client.close();
      }
    }

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final existingBytes = await tempFile.exists() ? await tempFile.length() : 0;

      if (totalBytes > 0 && existingBytes >= totalBytes) {
        debugPrint('📡 Resume downloader: File already fully downloaded ($existingBytes bytes).');
        return tempFile.path;
      }

      debugPrint('📡 Resume downloader: Attempt $attempt/$maxAttempts — resuming from ${(existingBytes / 1e6).toStringAsFixed(1)} MB');

      final client = HttpClient()
        ..connectionTimeout = const Duration(minutes: 5)
        ..idleTimeout = const Duration(minutes: 10);

      try {
        final req = await client.getUrl(Uri.parse(_modelUrl));
        req.headers.set(HttpHeaders.userAgentHeader, 'GemmaStudentApp/1.0');
        if (existingBytes > 0) {
          req.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
          debugPrint('📡 Resume downloader: Sending Range: bytes=$existingBytes-');
        }

        final res = await req.close();
        debugPrint('📡 Resume downloader: HTTP ${res.statusCode}');

        // 200 = full content (new download), 206 = partial content (resume)
        if (res.statusCode != 200 && res.statusCode != 206) {
          throw HttpException('Unexpected HTTP status: ${res.statusCode}');
        }

        final sink = tempFile.openWrite(mode: existingBytes > 0 && res.statusCode == 206
            ? FileMode.append
            : FileMode.write);

        int receivedBytes = existingBytes > 0 && res.statusCode == 206 ? existingBytes : 0;

        try {
          await for (final chunk in res) {
            sink.add(chunk);
            receivedBytes += chunk.length;

            if (totalBytes > 0) {
              final progress = receivedBytes / totalBytes;
              // Only notify every ~0.3% to avoid flooding the UI.
              if ((progress * 1000).floor() != (_downloadProgress * 1000).floor()) {
                _downloadProgress = progress.clamp(0.0, 1.0);
                notifyListeners();
              }
            }
          }
          await sink.flush();
          debugPrint('📡 Resume downloader: Chunk complete. Total received: ${(receivedBytes / 1e6).toStringAsFixed(1)} MB');
        } finally {
          await sink.close();
        }

        // Verify the file is complete.
        final finalSize = await tempFile.length();
        if (totalBytes > 0 && finalSize < totalBytes) {
          debugPrint('⚠️ Resume downloader: File incomplete ($finalSize / $totalBytes bytes). Will retry...');
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        _downloadProgress = 1.0;
        notifyListeners();
        return tempFile.path;
      } on SocketException catch (e) {
        debugPrint('⚠️ Resume downloader: SocketException on attempt $attempt: $e. Retrying in 5s...');
        await Future.delayed(const Duration(seconds: 5));
      } on HttpException catch (e) {
        debugPrint('⚠️ Resume downloader: HttpException on attempt $attempt: $e. Retrying in 5s...');
        await Future.delayed(const Duration(seconds: 5));
      } on IOException catch (e) {
        debugPrint('⚠️ Resume downloader: IOException on attempt $attempt: $e. Retrying in 5s...');
        await Future.delayed(const Duration(seconds: 5));
      } finally {
        client.close();
      }
    }

    throw Exception('Download failed after $maxAttempts attempts.');
  }

  /// Load the model into memory and create a chat session.
  /// Call during splash screen for background warm-up.
  Future<void> loadModel() async {
    if (_state == GemmaServiceState.loading ||
        _state == GemmaServiceState.generating) {
      // Reset stuck loading state before retrying
      debugPrint('⚠️ GemmaService: loadModel() called while state=${_state.name}. Resetting state to allow retry.');
      _state = GemmaServiceState.uninitialized;
    }
    _state = GemmaServiceState.loading;
    _error = null;
    notifyListeners();

    try {
      // Attempt GPU first with a 120-second timeout so it can never hang forever.
      try {
        debugPrint('📡 GemmaService: Attempting to load model with PreferredBackend.gpu...');
        _model = await FlutterGemma.getActiveModel(
          maxTokens: _maxTokens,
          preferredBackend: PreferredBackend.gpu,
        ).timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw TimeoutException('GPU model load timed out after 120s'),
        );
        debugPrint('✅ GemmaService: Model loaded successfully with GPU backend.');
      } catch (gpuError) {
        debugPrint('⚠️ GemmaService: GPU backend failed: $gpuError. Retrying with CPU...');
        _model = await FlutterGemma.getActiveModel(
          maxTokens: _maxTokens,
          preferredBackend: PreferredBackend.cpu,
        ).timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw TimeoutException('CPU model load timed out after 120s'),
        );
        debugPrint('✅ GemmaService: Model loaded successfully with CPU backend fallback.');
      }

      _chat = await _model!.createChat(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        tokenBuffer: 256,
        modelType: ModelType.gemmaIt,
      );

      _state = GemmaServiceState.ready;
      notifyListeners();
    } catch (e) {
      _state = GemmaServiceState.error;
      _error = 'Model loading failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Pre-populates the native chat session history with stored messages
  /// from the SQLite database for a specific conversation.
  Future<void> loadConversationHistory(int conversationId) async {
    if (_chat == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }
    await _chat!.clearHistory();
    
    final messages = await DatabaseHelper.instance.getMessages(conversationId);
    for (final msg in messages) {
      final isUser = msg['sender_type'] == 'user';
      final text = msg['content_text'] as String;
      
      // Feed the messages directly into native chat history
      await _chat!.addQuery(Message.text(text: text, isUser: isUser));
    }
  }

  /// Send a message and stream back the response token by token.
  ///
  /// Supports:
  /// - Automatic System Prompt framing with student profile context
  /// - Real-time keyword local tools interception (Clinic hours, Insurance network)
  /// - Enforces [_maxGenerationTokens] limit to prevent thermal throttling.
  Stream<String> sendMessage(String text, {int? activeConversationId, List<Uint8List>? imageBytes}) async* {
    if (_chat == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }
    if (_state == GemmaServiceState.generating) {
      throw StateError('Already generating. Stop current generation first.');
    }

    _state = GemmaServiceState.generating;
    _tokensGenerated = 0;
    _lastGenerationTruncated = false;
    _error = null;
    _generationStopwatch.reset();
    _generationStopwatch.start();
    notifyListeners();

    try {
      final lowerText = text.toLowerCase();

      // ─── 1. CLINIC HOURS / COUNSELING / CRISIS ─────────────────────────────
      if (lowerText.contains('clinic') &&
          (lowerText.contains('hour') ||
              lowerText.contains('phone') ||
              lowerText.contains('open') ||
              lowerText.contains('time') ||
              lowerText.contains('contact') ||
              lowerText.contains('counseling') ||
              lowerText.contains('hotline') ||
              lowerText.contains('crisis'))) {
        final response = ClinicInsuranceTool.getClinicHoursText();
        yield* _streamWords(response, delayMs: 20);
        return;
      }

      // ─── 2–4. ALL HOSPITAL / CONDITION / INSURANCE QUERIES ─────────────────
      // These ALL route exclusively to the curated list of 10 Masoro-area
      // facilities. No Firestore lookup, no medication advice.
      final bool isHospitalQuery =
          lowerText.contains('hospital') ||
          lowerText.contains('clinic') ||
          lowerText.contains('doctor') ||
          lowerText.contains('where') ||
          lowerText.contains('emergency') ||
          lowerText.contains('insurance') ||
          lowerText.contains('near') ||
          lowerText.contains('close') ||
          lowerText.contains('nearest') ||
          lowerText.contains('recommend') ||
          lowerText.contains('facility') ||
          lowerText.contains('treat') ||
          lowerText.contains('er') ||
          lowerText.contains('refer');

      // Condition keywords that should trigger a facility recommendation
      const conditionKeywords = [
        'dental', 'teeth', 'tooth', 'mouth',
        'mental', 'psych', 'depression', 'anxiety', 'stress', 'counsel',
        'matern', 'pregnan', 'birth', 'gynec', 'obstet',
        'chest', 'heart', 'cardio', 'breath',
        'bone', 'fracture', 'joint', 'muscle',
        'eye', 'vision', 'skin', 'rash',
        'child', 'kid', 'pediatr',
        'accident', 'injury', 'bleeding', 'wound',
        'lab', 'diagnost', 'scan', 'test', 'x-ray',
        'pain', 'fever', 'sick', 'ill', 'feeling',
        'headache', 'stomach', 'diarrhea', 'vomit',
      ];

      String? detectedCondition;
      for (final kw in conditionKeywords) {
        if (lowerText.contains(kw)) {
          detectedCondition = kw;
          break;
        }
      }

      if (isHospitalQuery || detectedCondition != null) {
        final insurance = await DatabaseHelper.instance
            .getProfileValue('insurance', defaultValue: 'None');

        List<CuratedHospital> hospitals;
        String? conditionContext;

        if (detectedCondition != null) {
          hospitals = CuratedHospitals.forCondition(detectedCondition);
          conditionContext = detectedCondition;
        } else {
          hospitals = CuratedHospitals.forInsurance(insurance);
        }

        final response = CuratedHospitals.formatList(
          hospitals,
          insurance: insurance,
          conditionContext: conditionContext,
          maxShown: 3,
        );
        yield* _streamWords(response, delayMs: 15);
        return;
      }

      // ─── 5. GENERAL ON-DEVICE INFERENCE (hospital-guidance framing) ─────
      bool isFirstMessage = true;
      if (activeConversationId != null) {
        final messages = await DatabaseHelper.instance.getMessages(activeConversationId);
        isFirstMessage = messages.length <= 1;
      }

      String prompt = text;
      if (isFirstMessage) {
        final profileSummary = await DatabaseHelper.instance.generateStudentProfileSummary();
        prompt = '''[SYSTEM DIRECTION — READ CAREFULLY AND FOLLOW STRICTLY:

You are a Student Hospital Navigation & Price Comparison Guide for students near Masoro, Kigali, Rwanda.

YOUR MAIN FEATURE is to help students find the cheapest healthcare facility and compare prices for common services. You are NOT a doctor. You do NOT give medical diagnoses. You do NOT recommend, name, or describe any medications, drugs, tablets, syrups, or treatments. If a student asks about medication, painkillers, antibiotics, or any drug, you MUST redirect them to the appropriate facility below instead of naming any medicine.

APPROVED FACILITY & PRICE LIST (Uninsured / Base Cash Rates):
1. Nora Dental Clinic:
   - Specialist Consultation: 15,000 RWF
   - Dental Cleaning / Filling: 30,000 RWF
2. Caraes Ndera Neuropsychiatric Hospital:
   - General Consultation: 5,000 RWF
   - Specialist Consultation: 12,000 RWF
   - Inpatient Admission (ward rate): 20,000 RWF/day
3. Legacy Clinics & Diagnostics:
   - General Consultation: 18,000 RWF
   - Specialist Consultation: 28,000 RWF
   - Full Blood Count (Lab): 12,000 RWF
   - Abdominal/Obstetric Ultrasound: 30,000 RWF
   - Chest X-Ray: 22,000 RWF
4. Bella Vitae Medical Clinic:
   - General Consultation: 10,000 RWF
   - Full Blood Count (Lab): 8,000 RWF
   - Abdominal/Obstetric Ultrasound: 20,000 RWF
5. Rwanda Military Hospital (RMH):
   - General Consultation: 8,000 RWF
   - Specialist Consultation: 18,000 RWF
   - Full Blood Count (Lab): 6,000 RWF
   - Abdominal/Obstetric Ultrasound: 18,000 RWF
   - Chest X-Ray: 15,000 RWF
   - Inpatient Admission: 35,000 RWF/day
6. Alliance Arena Clinic:
   - General Consultation: 7,000 RWF
   - Full Blood Count (Lab): 5,000 RWF
   - Abdominal/Obstetric Ultrasound: 15,000 RWF
7. Kigali Medical Center (KMC):
   - General Consultation: 12,000 RWF
   - Specialist Consultation: 22,000 RWF
   - Full Blood Count (Lab): 9,000 RWF
   - Abdominal/Obstetric Ultrasound: 25,000 RWF
8. Ubuzima Polyclinic:
   - General Consultation: 10,000 RWF
   - Specialist Consultation: 20,000 RWF
   - Full Blood Count (Lab): 8,000 RWF
   - Abdominal/Obstetric Ultrasound: 22,000 RWF
9. Solace Medical Clinic:
   - General Consultation: 12,000 RWF
   - Specialist Consultation: 25,000 RWF
   - Abdominal/Obstetric Ultrasound: 25,000 RWF
   - Standard Maternity Delivery: 150,000 RWF
10. Masaka District Hospital:
   - General Consultation: 3,000 RWF
   - Specialist Consultation: 8,000 RWF
   - Full Blood Count (Lab): 2,500 RWF
   - Abdominal/Obstetric Ultrasound: 7,000 RWF
   - Chest X-Ray: 8,000 RWF
   - Inpatient Admission: 10,000 RWF/day

CO-PAYMENT & INSURANCE COVERAGE RULES (dataset/rwanda_insurance_financial_policies.md):
- Britam: Outpatient services (Consultations, Lab, Dental, Ultrasound, X-Ray) are EXCLUDED (100% patient copay applies). Inpatient services (Inpatient Admission, Standard Maternity Delivery) have 0% copay (fully covered).
- Old Mutual (UAP): 10% co-payment (90% covered) for all inpatient and outpatient services.
- None (No Insurance): 100% patient copay (fully out-of-pocket).

RULES:
- RECOMMEND EXACTLY THREE (3) FACILITIES from the list.
- When asked about prices, compare the copayment the student will owe based on their active plan:
  * Britam: out-of-pocket for consultations/lab/dental/scans; free (0 RWF) for inpatient/maternity admission.
  * Old Mutual: 10% of cash price.
  * None: full cash price.
- NEVER suggest any medication, drug, or treatment by name.
- Keep your response warm, clear, and concise.
- Always remind the student you are a navigation guide, not a medical professional.

Student Background: $profileSummary]

Student Question: $text''';
      }

      final Message message;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        message = Message.withImages(text: prompt, imageBytes: imageBytes, isUser: true);
      } else {
        message = Message.text(text: prompt, isUser: true);
      }
      await _chat!.addQuery(message);

      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          _tokensGenerated++;

          // Enforce generation token limit to prevent thermal throttling
          if (_tokensGenerated >= _maxGenerationTokens) {
            await _chat!.stopGeneration();
            _lastGenerationTruncated = true;
            yield response.token;
            break;
          }

          yield response.token;
        }
      }
    } catch (e) {
      _error = 'Generation failed: $e';
      notifyListeners();
      rethrow;
    } finally {
      _generationStopwatch.stop();
      _state = GemmaServiceState.ready;
      notifyListeners();
    }
  }

  /// Stop any in-progress generation.
  Future<void> stopGeneration() async {
    if (_chat != null && _state == GemmaServiceState.generating) {
      await _chat!.stopGeneration();
      _state = GemmaServiceState.ready;
      notifyListeners();
    }
  }

  /// Clear chat history and start fresh.
  Future<void> clearChat() async {
    if (_chat != null) {
      await _chat!.clearHistory();
      _tokensGenerated = 0;
      _generationStopwatch.reset();
      notifyListeners();
    }
  }

  /// Get the model description.
  /// Streams a pre-built [text] response word-by-word with a [delayMs] between
  /// each word, incrementing [_tokensGenerated] for perf tracking.
  Stream<String> _streamWords(String text, {int delayMs = 15}) async* {
    final words = text.split(' ');
    for (var i = 0; i < words.length; i++) {
      await Future.delayed(Duration(milliseconds: delayMs));
      _tokensGenerated++;
      yield words[i] + (i == words.length - 1 ? '' : ' ');
    }
  }

  String get backendInfo => 'Gemma 4 E2B';

  /// Tokens per second from the last generation.
  double get tokensPerSecond {
    if (_generationStopwatch.elapsedMilliseconds == 0) return 0;
    return _tokensGenerated / (_generationStopwatch.elapsedMilliseconds / 1000);
  }



  @override
  void dispose() {
    _chat?.close();
    _model?.close();
    super.dispose();
  }
}

enum GemmaServiceState {
  uninitialized,
  downloading,
  downloaded,
  loading,
  ready,
  generating,
  error,
}
