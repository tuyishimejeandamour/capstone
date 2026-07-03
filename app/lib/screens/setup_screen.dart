import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

import '../services/gemma_service.dart';
import '../services/database_helper.dart';
import '../services/hospital_repository.dart';
import '../widgets/vector_robot.dart';
import '../widgets/holographic_sphere.dart';

// Soothing dark pastel design tokens
const _kBgColor = Color(0xFF0E141D);
const _kSurfaceColor = Color(0xFF17202C);
const _kElevatedColor = Color(0xFF202B3A);
const _kAccentColor = Color(0xFF3BE2B0);
const _kErrorColor = Color(0xFFE56B6B);
const _kVioletColor = Color(0xFF926BFF);
const _kTextPrimary = Color(0xFFFFFFFF);
const _kTextMuted = Color(0x80FFFFFF);

/// Reworked multi-stage Onboarding screen for registration, model download,
/// and GPU/CPU warm-up. Replicates Screen 1 of the reference mockup.
class SetupScreen extends StatefulWidget {
  final GemmaService gemmaService;
  final VoidCallback onSetupComplete;

  const SetupScreen({
    super.key,
    required this.gemmaService,
    required this.onSetupComplete,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // Wizard Stages:
  // 0 = Welcome Screen (Screen 1 mockup style)
  // 1 = Profile Registration Screen (Name, Insurance, History)
  // 2 = Engine Warm-up Screen (Holographic Orb, Loader, Download if needed)
  int _currentStage = 0;

  // Form Fields
  final TextEditingController _nameController = TextEditingController();
  String _selectedInsurance = 'None';
  final TextEditingController _goalsController = TextEditingController();

  // Contract File upload fields
  String? _contractFilePath;
  String? _contractFileName;
  int? _contractFileSize;
  bool _isContractUploading = false;

  // Engine Loader Status
  String _statusMessage = 'Checking model files...';
  bool _hasError = false;
  bool _isWorking = true;

  @override
  void initState() {
    super.initState();
    _checkExistingOnboarding();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  /// Check if the student has already filled out the onboarding forms in SQLite.
  /// If yes, skip Welcome & Registration stages and jump straight to the Engine warm-up.
  Future<void> _checkExistingOnboarding() async {
    final db = DatabaseHelper.instance;
    final complete = await db.getProfileValue('onboarding_complete', defaultValue: 'false');
    
    if (complete == 'true') {
      setState(() {
        _currentStage = 2; // Jump straight to Model Loading
      });
      _startEngineSetup();
    }
  }

  /// Begins downloading (resuming) and loading the on-device AI model.
  Future<void> _startEngineSetup() async {
    setState(() {
      _hasError = false;
      _isWorking = true;
      _statusMessage = 'Initializing on-device framework...';
    });

    try {
      // Step 0: Framework init
      await widget.gemmaService.initFramework();

      // Step 1: Check if model is already installed (validates file size ≥ 2.3 GB)
      final installed = await widget.gemmaService.isModelInstalled();

      if (!installed) {
        if (!mounted) return;
        setState(() => _statusMessage = 'Downloading Gemma 4 E2B...\nThis is a one-time, 2.59 GB download.');
        await widget.gemmaService.downloadModel();
      }

      // Step 2: Load model into CPU/GPU memory (has 120s timeout per backend)
      if (!mounted) return;
      setState(() => _statusMessage = 'Warming up AI engine on device...');
      await widget.gemmaService.loadModel();

      // Step 2.5: Sync hospital database from Firestore
      if (!mounted) return;
      setState(() => _statusMessage = 'Syncing hospital directories...');
      try {
        await HospitalRepository.instance.syncFromFirestore();
      } catch (e) {
        debugPrint('SetupScreen: Hospital sync failed: $e');
      }

      // Step 3: Analyze uploaded contract if present
      final db = DatabaseHelper.instance;
      final contractPath = await db.getProfileValue('insurance_contract_path');
      if (contractPath.isNotEmpty) {
        await _analyzeContractWithGemma();
      }

      // Done — transition to chat
      if (!mounted) return;
      setState(() => _isWorking = false);
      await Future.delayed(const Duration(milliseconds: 600));
      widget.onSetupComplete();

    } catch (e) {
      // Catches Dart exceptions, TimeoutException, StateError, AND PlatformException
      if (!mounted) return;
      final msg = e.toString();
      // Provide a friendlier message for the known LiteRT model corruption error
      final friendlyMsg = msg.contains('TF_LITE_PREFILL_DECODE') || msg.contains('Failed to create engine')
          ? 'Model file is corrupted or incomplete.\nTap “Delete Corrupted File\u201d below to remove it and re-download.'
          : 'Engine setup failed:\n$msg';
      setState(() {
        _hasError = true;
        _isWorking = false;
        _statusMessage = friendlyMsg;
      });
    } finally {
      // Safety net: always clear the working spinner, even if an unhandled
      // PlatformException bypassed the catch block.
      if (mounted && _isWorking) {
        setState(() {
          _isWorking = false;
          _hasError = true;
          if (!_statusMessage.contains('failed') && !_statusMessage.contains('corrupted')) {
            _statusMessage = 'Setup did not complete. Please retry.';
          }
        });
      }
    }
  }

  /// Deletes the corrupted/incomplete model file from device storage,
  /// then immediately restarts the engine setup to trigger a fresh download.
  Future<void> _deleteAndRetry() async {
    setState(() {
      _hasError = false;
      _isWorking = true;
      _statusMessage = 'Deleting corrupted model file...';
    });

    try {
      // Locate the app documents directory where flutter_gemma stores the model
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/gemma-model.litertlm');

      if (await modelFile.exists()) {
        await modelFile.delete();
        debugPrint('🗑️ Deleted corrupted model file: ${modelFile.path}');
      } else {
        debugPrint('ℹ️ No model file found at ${modelFile.path} — skipping delete.');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to delete model file: $e');
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = 'Model file removed. Starting fresh download...';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    _startEngineSetup();
  }

  /// Uses local Gemma 4 E2B model to process the uploaded contract (PDF or image).
  Future<void> _analyzeContractWithGemma() async {
    final path = _contractFilePath;
    if (path == null || path.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _statusMessage = 'Reading contract file...';
    });

    try {
      final isPdf = path.toLowerCase().endsWith('.pdf');
      String textContent = '';
      List<Uint8List>? imageBytes;

      if (isPdf) {
        // Use read_pdf_text API to extract text content
        textContent = await ReadPdfText.getPDFtext(path);
      } else {
        // Read file bytes as image bytes for Gemma 4 E2B
        imageBytes = [await File(path).readAsBytes()];
      }

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Analyzing contract with Gemma 4 E2B...';
      });

      // Construct prompt for Gemma 4 E2B analysis
      final insurance = _selectedInsurance;
      final prompt = isPdf 
          ? '''You are a Student Health Guide. The user has uploaded their insurance contract for $insurance. Here is the text content extracted from their PDF document:
$textContent

Please analyze this contract. Extract and summarize the key benefits, coverage limits, policy number, and co-pay structure in a clean, bulleted format. Keep the summary short and concise, and focus on what benefits a student can claim in Rwanda.'''
          : '''You are a Student Health Guide. The user has uploaded their insurance contract for $insurance as an image. Please analyze this image. Extract and summarize the key benefits, coverage limits, policy number, and co-pay structure in a clean, bulleted format. Keep the summary short and concise, and focus on what benefits a student can claim in Rwanda.''';

      // We call sendMessage and listen to the stream to build the summary.
      String summary = '';
      await for (final token in widget.gemmaService.sendMessage(prompt, imageBytes: imageBytes)) {
        summary += token;
      }

      if (summary.trim().isEmpty) {
        summary = 'Unable to extract detailed information from the contract. Provider is set to $insurance.';
      }

      // Save summary in profile
      final db = DatabaseHelper.instance;
      await db.setProfileValue('insurance_contract_summary', summary.trim());
      
      // Clear native chat history
      await widget.gemmaService.clearChat();

    } catch (e) {
      debugPrint('⚠️ Contract analysis failed: $e');
      final db = DatabaseHelper.instance;
      await db.setProfileValue('insurance_contract_summary', 'Uploaded contract file processing failed: $e. Provider is $_selectedInsurance.');
    }
  }

  Future<void> _pickContractFile() async {
    setState(() {
      _isContractUploading = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        setState(() {
          _contractFilePath = file.path;
          _contractFileName = file.name;
          _contractFileSize = file.size;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick file: $e'),
          backgroundColor: _kErrorColor,
        ),
      );
    } finally {
      setState(() {
        _isContractUploading = false;
      });
    }
  }

  void _removeContractFile() {
    setState(() {
      _contractFilePath = null;
      _contractFileName = null;
      _contractFileSize = null;
    });
  }

  Widget _buildContractPickerSection() {
    final hasFile = _contractFilePath != null;
    final fileSizeKb = _contractFileSize != null ? (_contractFileSize! / 1024).toStringAsFixed(1) : '0';
    final isPdf = _contractFileName?.toLowerCase().endsWith('.pdf') ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kElevatedColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222F3E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasFile) ...[
            GestureDetector(
              onTap: _isContractUploading ? null : _pickContractFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _kAccentColor.withValues(alpha: 0.3),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.02),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: _kAccentColor,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isContractUploading ? 'Opening Picker...' : 'Tap to Upload Picture or PDF',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Supports PDF, PNG, JPG',
                      style: TextStyle(
                        color: _kTextMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kAccentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    color: _kAccentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _contractFileName ?? 'Contract File',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$fileSizeKb KB',
                        style: const TextStyle(
                          color: _kTextMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _removeContractFile,
                  icon: const Icon(Icons.delete_outline_rounded, color: _kErrorColor, size: 20),
                  tooltip: 'Remove contract',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kAccentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kAccentColor.withValues(alpha: 0.15), width: 0.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: _kAccentColor, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Will be summarized offline by Gemma 4 E2B during warm-up.',
                      style: TextStyle(color: _kAccentColor, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Save captured profile fields to SQLite and transition to engine setup.
  Future<void> _submitProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name to personalize the guide.'),
          backgroundColor: _kErrorColor,
        ),
      );
      return;
    }

    final db = DatabaseHelper.instance;
    await db.setProfileValue('student_name', name);
    await db.setProfileValue('insurance', _selectedInsurance);
    if (_goalsController.text.trim().isNotEmpty) {
      await db.setProfileValue('history_summary', _goalsController.text.trim());
    }

    // Save contract file path if selected
    if (_contractFilePath != null) {
      await db.setProfileValue('insurance_contract_path', _contractFilePath!);
    } else {
      await db.setProfileValue('insurance_contract_path', '');
    }

    await db.setProfileValue('onboarding_complete', 'true');

    setState(() {
      _currentStage = 2; // Move to Engine Loading Stage
    });
    _startEngineSetup();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _buildStageContent(),
        ),
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_currentStage) {
      case 0:
        return _buildWelcomeStage();
      case 1:
        return _buildProfileStage();
      case 2:
      default:
        return _buildEngineStage();
    }
  }

  // ===========================================================================
  // STAGE 0: Welcome Screen (Mascot & Get Started)
  // ===========================================================================
  Widget _buildWelcomeStage() {
    return Padding(
      key: const ValueKey('welcome_stage'),
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        children: [
          const Spacer(flex: 3),
          // Heading (Meet Your Smart AI Assistant)
          const Text(
            'Meet Your\nSmart AI Assistant',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.25,
            ),
          ).animate().fade(duration: 500.ms).slideY(begin: -0.1, end: 0.0),
          const SizedBox(height: 12),
          // Gradient highlight sub-text (Free for all)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _kVioletColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kVioletColor.withValues(alpha: 0.3), width: 0.8),
            ),
            child: const Text(
              '100% Free & Fully Offline Wellness Guide',
              style: TextStyle(
                color: _kVioletColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ).animate().fade(delay: 200.ms),
          const Spacer(flex: 2),

          // Speech bubble above Mascot
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2837),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2E3E52), width: 1),
                ),
                child: const Text(
                  'Need help? We\'re\nready for you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                child: CustomPaint(
                  size: const Size(12, 12),
                  painter: _BubbleTrianglePainter(),
                ),
              ),
            ],
          ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),

          // Custom Painted Floating Robot Mascot
          const FloatingRobot(size: 190),

          const Spacer(flex: 3),
          // Slide-to-Start sliding button (Screen 1 style)
          _SlideToStartButton(
            onSlideComplete: () {
              setState(() {
                _currentStage = 1; // Go to Profile Form
              });
            },
          ).animate().fade(delay: 600.ms).slideY(begin: 0.1, end: 0.0),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  // ===========================================================================
  // STAGE 1: Profile Registration Screen
  // ===========================================================================
  Widget _buildProfileStage() {
    return SingleChildScrollView(
      key: const ValueKey('profile_stage'),
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Back Button
          GestureDetector(
            onTap: () {
              setState(() {
                _currentStage = 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: _kSurfaceColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Personalize Your Guide',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ).animate().fade(duration: 400.ms),
          const SizedBox(height: 8),
          const Text(
            'Enter details to tailor on-device wellness advice and hospital recommendations.',
            style: TextStyle(
              color: _kTextMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ).animate().fade(delay: 100.ms),
          const SizedBox(height: 32),

          // Glassmorphic Form Card
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _kSurfaceColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Name input
                const Text(
                  'YOUR FIRST NAME',
                  style: TextStyle(
                    color: _kAccentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. Jackson',
                    fillColor: _kElevatedColor,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _kAccentColor, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF222F3E), width: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Insurance Dropdown
                const Text(
                  'INSURANCE PLAN (FOR LOCAL TOOL LOOKUPS)',
                  style: TextStyle(
                    color: _kAccentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _kElevatedColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF222F3E), width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedInsurance,
                      dropdownColor: _kElevatedColor,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kAccentColor),
                      isExpanded: true,
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedInsurance = newValue;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'None', child: Text('No Insurance / Out-of-pocket')),
                        DropdownMenuItem(value: 'Britam', child: Text('Britam Insurance')),
                        DropdownMenuItem(value: 'UAP', child: Text('Old Mutual / UAP')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2.5. Upload Insurance Contract
                const Text(
                  'UPLOAD INSURANCE CONTRACT (IMAGE OR PDF)',
                  style: TextStyle(
                    color: _kAccentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                _buildContractPickerSection(),
                const SizedBox(height: 24),

                // 3. Wellness Goals Notes
                const Text(
                  'WELLNESS FOCUS OR ISSUES (OPTIONAL)',
                  style: TextStyle(
                    color: _kAccentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _goalsController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'e.g. struggles with sleep during exam weeks, stress management...',
                    fillColor: _kElevatedColor,
                    filled: true,
                    contentPadding: const EdgeInsets.all(14),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _kAccentColor, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF222F3E), width: 1),
                    ),
                  ),
                ),
              ],
            ),
          ))).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 36),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _submitProfile,
              style: TextButton.styleFrom(
                backgroundColor: _kAccentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'COMPLETE REGISTRATION',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16, color: Colors.black),
                ],
              ),
            ),
          ).animate().fade(delay: 350.ms),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // STAGE 2: Engine Warm-up Screen (Model Download/Load centered around Orb)
  // ===========================================================================
  Widget _buildEngineStage() {
    return Padding(
      key: const ValueKey('engine_stage'),
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        children: [
          const Spacer(flex: 3),
          // Header
          const Text(
            'Preparing Offline AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ).animate().fade(duration: 400.ms),
          const SizedBox(height: 8),
          const Text(
            'Syncing model files locally for 100% private health queries.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kTextMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ).animate().fade(delay: 100.ms),
          const Spacer(flex: 2),

          // Glowing holographic sphere in center
          ListenableBuilder(
            listenable: widget.gemmaService,
            builder: (context, _) {
              final isDownloading = widget.gemmaService.state == GemmaServiceState.downloading;
              final progress = widget.gemmaService.downloadProgress;

              return Stack(
                alignment: Alignment.center,
                children: [
                  const HolographicSphere(size: 190),
                  // Centered Circular progress indicator overlaying the Orb if downloading
                  if (isDownloading)
                    SizedBox(
                      width: 215,
                      height: 215,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        valueColor: const AlwaysStoppedAnimation<Color>(_kAccentColor),
                        backgroundColor: Colors.white10,
                      ),
                    ),
                ],
              );
            },
          ),
          const Spacer(flex: 2),

          // Status & Progress block
          ListenableBuilder(
            listenable: widget.gemmaService,
            builder: (context, _) {
              final isDownloading = widget.gemmaService.state == GemmaServiceState.downloading;
              final progress = widget.gemmaService.downloadProgress;
              final percent = '${(progress * 100).toStringAsFixed(1)}%';

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDownloading) ...[
                    Text(
                      percent,
                      style: const TextStyle(
                        color: _kAccentColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else if (_isWorking) ...[
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(_kAccentColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _hasError ? _kErrorColor : _kTextMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const Spacer(flex: 2),

          // Error action buttons
          if (_hasError) ...[
            const SizedBox(height: 4),
            // Primary: Delete corrupted file and re-download
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _deleteAndRetry,
                style: TextButton.styleFrom(
                  backgroundColor: _kErrorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'DELETE CORRUPTED FILE & RE-DOWNLOAD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Secondary: Simple retry (no delete)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _startEngineSetup,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: _kTextMuted,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
                  ),
                ),
                child: const Text(
                  'RETRY WITHOUT DELETING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 1),
          ],
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ===========================================================================
// Custom Vector Painters & Helpers
// ===========================================================================

class _BubbleTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E2837);
    final borderPaint = Paint()
      ..color = const Color(0xFF2E3E52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
    // Draw left & right border of bubble triangle tip
    canvas.drawLine(const Offset(0, 0), Offset(size.width * 0.5, size.height), borderPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width * 0.5, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slide-to-Start interactive gesture button replicating Screen 1
class _SlideToStartButton extends StatefulWidget {
  final VoidCallback onSlideComplete;
  const _SlideToStartButton({required this.onSlideComplete});

  @override
  State<_SlideToStartButton> createState() => _SlideToStartButtonState();
}

class _SlideToStartButtonState extends State<_SlideToStartButton> {
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        const knobSize = 50.0;
        final maxDragDistance = trackWidth - knobSize - 8.0;

        return Container(
          width: trackWidth,
          height: 60,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF161F2B),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF243346), width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Sliding track guide text
              const Center(
                child: Text(
                  'Get Started     > > >',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              
              // Slide Knob
              Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragOffset += details.primaryDelta!;
                      _dragOffset = _dragOffset.clamp(0.0, maxDragDistance);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() => _isDragging = false);
                    if (_dragOffset >= maxDragDistance * 0.85) {
                      // Slide complete! Snap to end & trigger callback
                      setState(() => _dragOffset = maxDragDistance);
                      Future.delayed(const Duration(milliseconds: 100), widget.onSlideComplete);
                    } else {
                      // Return to start
                      setState(() => _dragOffset = 0.0);
                    }
                  },
                  child: AnimatedContainer(
                    duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: knobSize,
                    height: knobSize,
                    decoration: const BoxDecoration(
                      color: _kVioletColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kVioletColor,
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_right_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
