import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'clinic_insurance_tool.dart';
import 'hospital_navigation_tool.dart';

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
  Future<bool> isModelInstalled() async {
    if (FlutterGemma.hasActiveModel()) {
      return true;
    }
    
    // Check if the model file is already present on disk in applicationDocumentsDirectory
    final docsDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${docsDir.path}/gemma-model.litertlm');
    
    if (await modelFile.exists() && await modelFile.length() > 1000 * 1024 * 1024) {
      debugPrint('📡 GemmaService: Model file found on disk (${(await modelFile.length() / 1e9).toStringAsFixed(2)} GB). Registering as active...');
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
      throw StateError('Cannot load while ${_state.name}.');
    }
    _state = GemmaServiceState.loading;
    _error = null;
    notifyListeners();

    try {
      try {
        debugPrint('📡 GemmaService: Attempting to load model with PreferredBackend.gpu...');
        _model = await FlutterGemma.getActiveModel(
          maxTokens: _maxTokens,
          preferredBackend: PreferredBackend.gpu,
        );
        debugPrint('✅ GemmaService: Model loaded successfully with GPU backend.');
      } catch (gpuError) {
        debugPrint('⚠️ GemmaService: Failed to load model with GPU backend: $gpuError. Retrying with PreferredBackend.cpu...');
        _model = await FlutterGemma.getActiveModel(
          maxTokens: _maxTokens,
          preferredBackend: PreferredBackend.cpu,
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
      
      // ─── 1. INTERCEPT FOR LOCAL CLINIC / HEALTH CENTER TOOL ───
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
        final words = response.split(' ');
        
        for (var i = 0; i < words.length; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          _tokensGenerated++;
          yield words[i] + (i == words.length - 1 ? '' : ' ');
        }
        return;
      }

      // ─── 2. INTERCEPT FOR LOCAL INSURANCE / HOSPITAL TOOL ───
      if (lowerText.contains('hospital') || 
          lowerText.contains('insurance') || 
          lowerText.contains('er') || 
          lowerText.contains('emergency') || 
          lowerText.contains('aetna') || 
          lowerText.contains('blue') || 
          lowerText.contains('cigna') || 
          lowerText.contains('united')) {
        
        final insurance = await DatabaseHelper.instance.getProfileValue('insurance', defaultValue: 'None');
        final response = ClinicInsuranceTool.getHospitalRecommendation(insurance);
        final words = response.split(' ');
        
        for (var i = 0; i < words.length; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          _tokensGenerated++;
          yield words[i] + (i == words.length - 1 ? '' : ' ');
        }
        return;
      }

      // ─── 3. INTERCEPT FOR NEAREST / LOCATION-BASED HOSPITALS ───
      if (lowerText.contains('nearest hospital') || 
          lowerText.contains('close to me') || 
          lowerText.contains('hospitals near') ||
          lowerText.contains('hospital near') ||
          lowerText.contains('closest hospital') ||
          lowerText.contains('nearby hospital')) {
        
        final insurance = await DatabaseHelper.instance.getProfileValue('insurance', defaultValue: 'None');
        final coverageBlock = HospitalNavigationTool.getInsuranceCoverageBlock(insurance);
        
        // Fn1: Get location
        final loc = await HospitalNavigationTool.getCurrentLocation();
        
        // Fn2: Get nearby hospitals
        final nearby = await HospitalNavigationTool.getNearbyHospitals(loc['lat']!, loc['lng']!, 0, coverageBlock);
        
        // Fn4: Rank hospitals
        final ranked = HospitalNavigationTool.rankHospitalsByPriorityAndCost(nearby, coverageBlock);
        
        final response = _formatRankedHospitals(ranked, insurance);
        final words = response.split(' ');
        
        for (var i = 0; i < words.length; i++) {
          await Future.delayed(const Duration(milliseconds: 15));
          _tokensGenerated++;
          yield words[i] + (i == words.length - 1 ? '' : ' ');
        }
        return;
      }

      // ─── 4. INTERCEPT FOR CONDITION-BASED HOSPITALS ───
      String? matchedCondition;
      const conditions = [
        'chest', 'heart', 'cardio', 'eye', 'vision', 'see', 'bone', 'fracture', 
        'joint', 'muscle', 'mental', 'depression', 'anxiety', 'stress', 'teeth', 
        'tooth', 'dental', 'child', 'kid', 'pediatr', 'pregnancy', 'pregnant', 
        'gyn', 'skin', 'rash', 'dermat', 'emergency', 'accident', 'injury'
      ];
      
      for (final cond in conditions) {
        if (lowerText.contains(cond)) {
          matchedCondition = cond;
          break;
        }
      }

      if (matchedCondition != null && (lowerText.contains('hospital') || lowerText.contains('doctor') || lowerText.contains('clinic') || lowerText.contains('where') || lowerText.contains('treat'))) {
        final insurance = await DatabaseHelper.instance.getProfileValue('insurance', defaultValue: 'None');
        final coverageBlock = HospitalNavigationTool.getInsuranceCoverageBlock(insurance);
        
        // Fn1: Get location for distance context
        final loc = await HospitalNavigationTool.getCurrentLocation();
        
        // Fn3: Search hospitals by condition
        final results = await HospitalNavigationTool.searchHospitalsByCondition(
          matchedCondition, 
          coverageBlock, 
          lat: loc['lat'], 
          lng: loc['lng']
        );
        
        // Fn4: Rank hospitals
        final ranked = HospitalNavigationTool.rankHospitalsByPriorityAndCost(results, coverageBlock);
        
        final response = _formatRankedHospitals(
          ranked, 
          insurance, 
          conditionContext: matchedCondition
        );
        final words = response.split(' ');
        
        for (var i = 0; i < words.length; i++) {
          await Future.delayed(const Duration(milliseconds: 15));
          _tokensGenerated++;
          yield words[i] + (i == words.length - 1 ? '' : ' ');
        }
        return;
      }

      // ─── 5. NORMAL ON-DEVICE INFERENCE WITH SYSTEM FRAMING ───
      // If it's the first message in this conversation, prepopulate or wrap with system context.
      bool isFirstMessage = true;
      if (activeConversationId != null) {
        final messages = await DatabaseHelper.instance.getMessages(activeConversationId);
        // Only 1 user message means this is the first exchange
        isFirstMessage = messages.length <= 1; 
      }

      String prompt = text;
      if (isFirstMessage) {
        final profileSummary = await DatabaseHelper.instance.generateStudentProfileSummary();
        prompt = '''[SYSTEM DIRECTION: You are a Student Health Guide. You are NOT a doctor or medical professional. You DO NOT diagnose illnesses, prescribe treatments, or provide clinical medical advice. Your role is to answer health-related questions with general information, suggest safe next steps (e.g. hydration, rest, stress management, counseling, or clinic hours), and direct to proper medical care if necessary. Keep responses warm, clear, and reassuring. Always highlight that you are an AI guide, not a physician.
Student Background Context: $profileSummary]

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
  String get backendInfo => 'Gemma 4 E2B';

  /// Tokens per second from the last generation.
  double get tokensPerSecond {
    if (_generationStopwatch.elapsedMilliseconds == 0) return 0;
    return _tokensGenerated / (_generationStopwatch.elapsedMilliseconds / 1000);
  }

  /// Formats the ranked hospitals list into a highly readable markdown response.
  String _formatRankedHospitals(List<RankedHospitalResult> ranked, String insurance, {String? conditionContext}) {
    if (ranked.isEmpty) {
      return '🏥 **No matching hospitals found.**\n\n'
          'We couldn\'t find any hospitals matching your criteria. For general concerns, we recommend visiting the nearest public clinic or CHUK in central Kigali.';
    }

    final buffer = StringBuffer();
    if (conditionContext != null) {
      buffer.writeln('🏥 **Hospital recommendations for specialized condition: "$conditionContext"**\n');
    } else {
      buffer.writeln('🏥 **Hospitals near your location**\n');
    }
    buffer.writeln('Using your profile insurance: **$insurance**\n');

    // Show top 3 recommended hospitals
    final limit = ranked.length < 3 ? ranked.length : 3;
    for (var i = 0; i < limit; i++) {
      final r = ranked[i];
      final h = r.result.hospital;
      final networkStatus = r.result.isInNetwork ? '✅ In-Network' : '⚠️ Out-of-Network';
      
      buffer.writeln('### ${i + 1}. ${h.name}');
      buffer.writeln('📍 **Location:** ${h.address} (${h.district}, ${h.province}) — **${r.result.distanceKm.toStringAsFixed(1)} km away**');
      buffer.writeln('🛡️ **Insurance:** $networkStatus');
      buffer.writeln('💵 **Estimated Patient Copay:** ${r.estimatedCopayRwf} RWF');
      
      final ratingStr = h.ratingCount > 0 
          ? '⭐ ${h.averageRating.toStringAsFixed(1)} (${h.ratingCount} reviews)'
          : '⭐ No community reviews yet';
      buffer.writeln('💬 **Community Rating:** $ratingStr');
      buffer.writeln('⏰ **Hours:** ${h.openingHours ?? "N/A"}');
      if (h.phone != null) {
        buffer.writeln('📞 **Phone:** ${h.phone}');
      }
      buffer.writeln('🔬 **Specialties:** ${h.specialties.join(", ")}');
      buffer.writeln('📝 *${r.scoreExplanation}*');
      
      // Verification code for rating/cost submission
      final verificationCode = HospitalNavigationTool.generateVerificationCode();
      buffer.writeln('\n✍️ *To submit a rating or actual cost for this hospital, use verification code:* **`$verificationCode`**');
      buffer.writeln('\n---');
    }

    if (ranked.length > 3) {
      buffer.writeln('\nOther nearby facilities include:');
      for (var i = 3; i < ranked.length; i++) {
        final r = ranked[i];
        final h = r.result.hospital;
        buffer.writeln('- **${h.name}** (${r.result.distanceKm.toStringAsFixed(1)} km away) | Est. Copay: ${r.estimatedCopayRwf} RWF');
      }
    }

    return buffer.toString();
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
