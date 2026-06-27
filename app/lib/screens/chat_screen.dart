import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/gemma_service.dart';
import '../services/performance_monitor.dart';
import '../services/database_helper.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/holographic_sphere.dart';
import 'speech_screen.dart';
import 'hospital_search_screen.dart';

// Color tokens matching the refined deep forest green theme
const _kBgColor = Color(0xFF081510);
const _kSurfaceColor = Color(0xFF0D1F14);
const _kElevatedColor = Color(0xFF132A1A);
const _kAccentColor = Color(0xFF3BE2B0);
const _kErrorColor = Color(0xFFE56B6B);
const _kDisabledColor = Color(0xFF0E2016);
const _kVioletColor = Color(0xFF926BFF);
const _kBorderColor = Color(0xFF1E3525);

/// Main chat interface for interacting with Gemma 4 E2B on-device.
class ChatScreen extends StatefulWidget {
  final GemmaService gemmaService;
  final PerformanceMonitor performanceMonitor;

  const ChatScreen({
    super.key,
    required this.gemmaService,
    required this.performanceMonitor,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();

  final List<_ChatMessage> _messages = [];
  bool _isGenerating = false;
  StreamSubscription<String>? _generationSub;

  // DB Session tracking
  int? _activeConversationId;
  List<Map<String, dynamic>> _conversations = [];
  String _studentName = 'Student';
  String _studentInsurance = 'None';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();
  String _contractSummary = '';

  @override
  void initState() {
    super.initState();
    _initAppSession();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _historyController.dispose();
    _nameController.dispose();
    _generationSub?.cancel();
    _ttsService.stop();
    super.dispose();
  }

  /// Initialize SQLite DB, load conversations, load profile details,
  /// and automatically start a default session if empty.
  Future<void> _initAppSession() async {
    final db = DatabaseHelper.instance;

    // Load student profile details
    final name = await db.getProfileValue(
      'student_name',
      defaultValue: 'Student',
    );
    final insurance = await db.getProfileValue(
      'insurance',
      defaultValue: 'None',
    );
    final historySummary = await db.getProfileValue(
      'history_summary',
      defaultValue: 'No prior health issues recorded.',
    );
    final contractSummary = await db.getProfileValue(
      'insurance_contract_summary',
      defaultValue: '',
    );

    // Validate that the loaded insurance is one of the valid dropdown items
    const validInsurances = [
      'None',
      'Mutuelle',
      'RSSB',
      'MMI',
      'Sanlam',
      'Britam',
      'UAP',
      'Radiant',
    ];
    final validatedInsurance = validInsurances.contains(insurance)
        ? insurance
        : 'None';
    if (validatedInsurance != insurance) {
      await db.setProfileValue('insurance', 'None');
    }

    setState(() {
      _studentName = name;
      _nameController.text = name;
      _studentInsurance = validatedInsurance;
      _historyController.text = historySummary;
      _contractSummary = contractSummary;
    });

    await _loadConversationsList();
  }

  Future<void> _loadConversationsList() async {
    final list = await DatabaseHelper.instance.getConversations();
    setState(() {
      _conversations = list;
    });

    if (list.isNotEmpty) {
      // Auto-load the most recent active conversation
      await _loadConversation(list.first['id'] as int);
    } else {
      // Create first chat session
      await _startNewConversation();
    }
  }

  /// Create a fresh consultation conversation
  Future<void> _startNewConversation() async {
    await _stopGeneration();
    final db = DatabaseHelper.instance;
    final id = await db.createConversation(
      'Consultation #${_conversations.length + 1}',
    );

    await _loadConversationsList();
    await _loadConversation(id);
  }

  /// Load a conversation, populate bubbles, and warm up Gemma history
  Future<void> _loadConversation(int conversationId) async {
    await _stopGeneration();
    await _ttsService.stop();

    setState(() {
      _activeConversationId = conversationId;
      _messages.clear();
    });

    final list = await DatabaseHelper.instance.getMessages(conversationId);

    setState(() {
      for (final msg in list) {
        _messages.add(
          _ChatMessage(
            text: msg['content_text'] as String,
            isUser: msg['sender_type'] == 'user',
            inputType: msg['input_type'] as String,
          ),
        );
      }
    });

    _scrollToBottom();

    // Warm up native Gemma model with this historical conversation
    try {
      await widget.gemmaService.loadConversationHistory(conversationId);
    } catch (_) {
      // Safe fallback if model warming has issues
    }
  }

  Future<void> _deleteConversation(int id) async {
    await DatabaseHelper.instance.deleteConversation(id);
    if (_activeConversationId == id) {
      _activeConversationId = null;
    }
    await _loadConversationsList();
  }

  Future<void> _saveStudentProfile() async {
    final db = DatabaseHelper.instance;
    final name = _nameController.text.trim();
    await db.setProfileValue(
      'student_name',
      name.isNotEmpty ? name : 'Student',
    );
    await db.setProfileValue('insurance', _studentInsurance);
    await db.setProfileValue('history_summary', _historyController.text.trim());

    setState(() {
      _studentName = name.isNotEmpty ? name : 'Student';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student profile details updated successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Threshold (in logical pixels) for scroll snapping
  static const double _autoScrollThreshold = 64.0;

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels <= _autoScrollThreshold;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _failGeneration(int aiMessageIndex) {
    if (!mounted) return;
    final hadPartial =
        aiMessageIndex < _messages.length &&
        _messages[aiMessageIndex].text.isNotEmpty;
    setState(() {
      _isGenerating = false;
      if (aiMessageIndex < _messages.length && !hadPartial) {
        _messages[aiMessageIndex] = const _ChatMessage(
          text:
              'I ran into an issue processing that on-device. Please try again.',
          isUser: false,
          inputType: 'text',
        );
      }
    });
    widget.performanceMonitor.endSession();
    if (hadPartial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generation interrupted. Partial response shown.'),
        ),
      );
    }
  }

  /// Sends standard user question to Gemma, transcribes, and saves locally
  Future<void> _sendMessage({
    String? customText,
    bool isVoiceInput = false,
  }) async {
    final rawText = customText ?? _textController.text;
    final text = rawText.trim();
    if (text.isEmpty || _isGenerating) return;

    if (widget.performanceMonitor.shouldReduceLoad) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.performanceMonitor.statusDescription)),
        );
      }
      return;
    }

    _textController.clear();
    _focusNode.requestFocus();
    await _ttsService.stop();

    // Ensure we have an active session
    if (_activeConversationId == null) {
      await _startNewConversation();
    }
    final conversationId = _activeConversationId!;

    // 1. Save User Message to Database
    final inputType = isVoiceInput ? 'audio' : 'text';
    await DatabaseHelper.instance.saveMessage(
      conversationId: conversationId,
      text: text,
      isUser: true,
      inputType: inputType,
    );

    // 2. Add to Chat Screen state
    setState(() {
      _messages.add(
        _ChatMessage(text: text, isUser: true, inputType: inputType),
      );
      _messages.add(
        const _ChatMessage(text: '', isUser: false, inputType: 'text'),
      );
      _isGenerating = true;
    });

    final aiMessageIndex = _messages.length - 1;
    _scrollToBottom();

    widget.performanceMonitor.startSession();

    try {
      final stream = widget.gemmaService.sendMessage(
        text,
        activeConversationId: conversationId,
      );
      _generationSub = stream.listen(
        (token) {
          if (!mounted) return;
          final shouldStick = _isNearBottom();
          setState(() {
            if (aiMessageIndex < _messages.length) {
              _messages[aiMessageIndex] = _ChatMessage(
                text: _messages[aiMessageIndex].text + token,
                isUser: false,
                inputType: 'text',
              );
            }
          });
          if (shouldStick) _scrollToBottom();
        },
        onDone: () async {
          if (!mounted) return;
          final truncated = widget.gemmaService.wasLastGenerationTruncated;
          final finalAiText = _messages[aiMessageIndex].text;

          // 3. Save Assistant Message to Database
          await DatabaseHelper.instance.saveMessage(
            conversationId: conversationId,
            text: finalAiText,
            isUser: false,
            inputType: 'text',
          );

          setState(() {
            _isGenerating = false;
            if (truncated && aiMessageIndex < _messages.length) {
              final msg = _messages[aiMessageIndex];
              _messages[aiMessageIndex] = _ChatMessage(
                text: msg.text,
                isUser: false,
                wasTruncated: true,
                inputType: 'text',
              );
            }
          });
          widget.performanceMonitor.endSession();

          // Speak Gemma's response automatically using text-to-speech if active and input was voice
          if (_ttsService.isEnabled && isVoiceInput) {
            await _ttsService.speak(finalAiText);
          }
        },
        onError: (_) async {
          await widget.gemmaService.stopGeneration();
          _failGeneration(aiMessageIndex);
        },
      );
    } catch (_) {
      await widget.gemmaService.stopGeneration();
      _failGeneration(aiMessageIndex);
    }
  }

  Future<void> _stopGeneration() async {
    final sub = _generationSub;
    _generationSub = null;
    await sub?.cancel();
    await widget.gemmaService.stopGeneration();
    widget.performanceMonitor.endSession();
    if (!mounted) return;
    setState(() => _isGenerating = false);
  }

  /// Triggers full overlay voice recording screen
  Future<void> _openSpeechScreen() async {
    await _ttsService.stop();

    if (!mounted) return;
    final transcript = await Navigator.push<String?>(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, _) =>
            SpeechScreen(speechService: _speechService),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
      ),
    );

    if (transcript != null && transcript.trim().isNotEmpty) {
      await _sendMessage(customText: transcript, isVoiceInput: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _kBgColor,
        appBar: _buildAppBar(),
        drawer: _buildStudentDrawer(),
        body: Column(
          children: [
            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(
                      studentName: _studentName,
                      onCardTap: (prompt) {
                        _textController.text = prompt;
                        _sendMessage();
                      },
                      onFindHospitals: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HospitalSearchScreen(
                              studentInsurance: _studentInsurance,
                            ),
                          ),
                        );
                      },
                    )
                  : SelectionArea(
                      child: ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isAwaitingFirstToken =
                              _isGenerating &&
                              index == _messages.length - 1 &&
                              !msg.isUser &&
                              msg.text.isEmpty;

                          if (isAwaitingFirstToken) {
                            return const TypingIndicator();
                          }

                          // Bouncy animated entry for the latest bubbles
                          final isLatestBubble = index >= _messages.length - 2;

                          Widget bubble = ChatBubble(
                            text: msg.text,
                            isUser: msg.isUser,
                            isStreaming:
                                _isGenerating &&
                                index == _messages.length - 1 &&
                                !msg.isUser,
                            wasTruncated: msg.wasTruncated,
                            onPlayAudio: !msg.isUser
                                ? () => _ttsService.speak(msg.text)
                                : null,
                          );

                          if (isLatestBubble &&
                              !msg.isUser &&
                              msg.text.isNotEmpty) {
                            bubble = bubble
                                .animate()
                                .fade(duration: 400.ms)
                                .slideY(
                                  begin: 0.08,
                                  end: 0.0,
                                  curve: Curves.easeOutBack,
                                );
                          }

                          return bubble;
                        },
                      ),
                    ),
            ),

            // Input Bar
            ListenableBuilder(
              listenable: Listenable.merge([
                widget.performanceMonitor,
                _textController,
              ]),
              builder: (context, _) {
                final hasText = _textController.text.trim().isNotEmpty;
                final canSend =
                    !_isGenerating &&
                    !widget.performanceMonitor.shouldReduceLoad;

                return _InputBar(
                  controller: _textController,
                  focusNode: _focusNode,
                  isGenerating: _isGenerating,
                  isThrottled: widget.performanceMonitor.shouldReduceLoad,
                  hasText: hasText,
                  canSend: canSend,
                  onSend: () => _sendMessage(),
                  onStop: _stopGeneration,
                  onMicTap: _openSpeechScreen,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _kBgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
        tooltip: 'Student Profile Context',
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
      centerTitle: true,
      title: const Text(
        'Ranga',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kAccentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _kAccentColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _kAccentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '100% Offline',
                    style: TextStyle(
                      color: _kAccentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sliding Drawer displaying persistent Student Profile Context & History List
  Widget _buildStudentDrawer() {
    return Drawer(
      backgroundColor: _kSurfaceColor.withValues(alpha: 0.6),
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kAccentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: _kAccentColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'On-Device AI Context Summary',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Student Name Editor
                const Text(
                  'YOUR NAME',
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    fillColor: _kElevatedColor,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: _kAccentColor,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: _kBorderColor,
                        width: 1,
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    _saveStudentProfile();
                  },
                ),
                const SizedBox(height: 20),

                // Student Insurance Picker (Lookups & Network Hospital Matching)
                const Text(
                  'YOUR INSURANCE PLAN',
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
                    border: Border.all(color: _kBorderColor, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _studentInsurance,
                      dropdownColor: _kElevatedColor,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _kAccentColor,
                      ),
                      isExpanded: true,
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _studentInsurance = newValue;
                          });
                          _saveStudentProfile();
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'None',
                          child: Text('No Insurance / Out-of-pocket'),
                        ),
                        DropdownMenuItem(
                          value: 'Britam',
                          child: Text('Britam Insurance'),
                        ),
                        DropdownMenuItem(
                          value: 'UAP',
                          child: Text('Old Mutual / UAP'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Persistent Medical / History Notes
                const Text(
                  'HISTORY SUMMARY NOTES',
                  style: TextStyle(
                    color: _kAccentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _historyController,
                  maxLines: 3,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Enter student habits, wellness goals, or chronic logs...',
                    fillColor: _kElevatedColor,
                    contentPadding: const EdgeInsets.all(12),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: _kAccentColor,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: _kBorderColor,
                        width: 1,
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    _saveStudentProfile();
                  },
                ),

                if (_contractSummary.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'GEMMA 4 CONTRACT SUMMARY',
                    style: TextStyle(
                      color: _kAccentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kElevatedColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorderColor, width: 1),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _contractSummary,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Historical Consultations Sessions List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PAST CONSULTATIONS',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _startNewConversation,
                      icon: const Icon(
                        Icons.add,
                        size: 14,
                        color: _kAccentColor,
                      ),
                      label: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),

                Expanded(
                  child: _conversations.isEmpty
                      ? const Center(
                          child: Text(
                            'No past consultations found.',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _conversations.length,
                          itemBuilder: (context, index) {
                            final conv = _conversations[index];
                            final convId = conv['id'] as int;
                            final isSelected = convId == _activeConversationId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _kElevatedColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                horizontalTitleGap: 8,
                                dense: true,
                                onTap: () {
                                  Navigator.pop(context); // Close Drawer
                                  _loadConversation(convId);
                                },
                                leading: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: isSelected
                                      ? _kAccentColor
                                      : Colors.white38,
                                ),
                                title: Text(
                                  conv['title'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 14,
                                    color: Colors.white24,
                                  ),
                                  tooltip: 'Delete session',
                                  onPressed: () {
                                    _deleteConversation(convId);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Personalized Empty State Dashboard (Replicating Screen 2 mockup)
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final String studentName;
  final ValueChanged<String> onCardTap;
  final VoidCallback onFindHospitals;

  const _EmptyState({
    required this.studentName,
    required this.onCardTap,
    required this.onFindHospitals,
  });

  @override
  Widget build(BuildContext context) {
    final initials = studentName.isNotEmpty
        ? studentName[0].toUpperCase()
        : 'S';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        children: [
          // Header Top Bar
          const SizedBox(height: 16),

          // Glowing holographic sphere in center (Floating and Pulsing)
          const HolographicSphere(size: 150),

          const SizedBox(height: 16),

          // Greeting Text Block
          Text(
                'Hello, $studentName',
                style: const TextStyle(
                  color: _kVioletColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              )
              .animate()
              .fade(delay: 150.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0.0),
          const SizedBox(height: 4),
          const Text(
                'How can I assist you right now?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              )
              .animate()
              .fade(delay: 250.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0.0),

          const SizedBox(height: 28),

          // 2x2 Grid of beautiful frosted glassmorphic cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.15,
            children: [
              _buildDashboardCard(
                icon: Icons.local_hospital_outlined,
                title: 'Campus Clinic Hours',
                subtitle: 'Find clinic contact, general hours, & hotlines.',
                color: _kAccentColor,
                onTap: () => onCardTap('What are the campus clinic hours?'),
              ).animate().scale(delay: 350.ms, curve: Curves.easeOutBack),
              _buildDashboardCard(
                icon: Icons.health_and_safety_outlined,
                title: 'In-Network Hospitals',
                subtitle: 'Find hospitals near you that accept your plan.',
                color: const Color(0xFFE2B0FF),
                onTap: onFindHospitals,
              ).animate().scale(delay: 450.ms, curve: Curves.easeOutBack),
              _buildDashboardCard(
                icon: Icons.spa_outlined,
                title: 'Stress & Anxiety Support',
                subtitle: 'Get warm wellness coping steps and guidance.',
                color: const Color(0xFFB0D2FF),
                onTap: () => onCardTap('How can I manage stress and anxiety?'),
              ).animate().scale(delay: 550.ms, curve: Curves.easeOutBack),
              _buildDashboardCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'General Wellness Plan',
                subtitle: 'Suggestions on daily hydration, sleep & habit logs.',
                color: const Color(0xFFFFDFB0),
                onTap: () =>
                    onCardTap('Give me a general daily wellness plan.'),
              ).animate().scale(delay: 650.ms, curve: Curves.easeOutBack),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kSurfaceColor.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row (Icon & Arrow outward)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Icon(
                  Icons.arrow_outward_rounded,
                  color: Colors.white30,
                  size: 14,
                ),
              ],
            ),
            // Title & Subtitle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating input bar
// ---------------------------------------------------------------------------
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final bool isThrottled;
  final bool hasText;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onMicTap;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.isThrottled,
    required this.hasText,
    required this.canSend,
    required this.onSend,
    required this.onStop,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomPadding),
      color: _kSurfaceColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Elegant microphone button next to input if text is empty
          if (!hasText && !isGenerating)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
              child: _ActionButton(
                onPressed: onMicTap,
                backgroundColor: _kAccentColor.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.mic_rounded,
                  color: _kAccentColor,
                  size: 22,
                ),
              ).animate().scale(duration: 150.ms),
            ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kElevatedColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kBorderColor, width: 1.0),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (canSend && hasText) onSend();
                },
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: _kAccentColor,
                decoration: InputDecoration(
                  hintText: 'Ask health guide...',
                  hintStyle: const TextStyle(
                    color: Colors.white30,
                    fontSize: 15,
                  ),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          if (isGenerating)
            _ActionButton(
              onPressed: onStop,
              backgroundColor: _kErrorColor,
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 22,
              ),
            )
          else if (hasText)
            _ActionButton(
              onPressed: canSend ? onSend : null,
              backgroundColor: canSend ? _kAccentColor : _kDisabledColor,
              child: Icon(
                Icons.arrow_upward_rounded,
                color: canSend ? _kBgColor : Colors.white30,
                size: 22,
              ),
            ).animate().scale(duration: 150.ms),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Widget child;

  const _ActionButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model representation
// ---------------------------------------------------------------------------
class _ChatMessage {
  final String text;
  final bool isUser;
  final bool wasTruncated;
  final String inputType;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.wasTruncated = false,
    required this.inputType,
  });
}
