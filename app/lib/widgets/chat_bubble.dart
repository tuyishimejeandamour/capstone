import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// ─── Refined Dark Theme Design Tokens ────────────────────────────────────────
const _kUserBubbleColor = Color(0xFF1E87D9); // Gorgeous solid blue for user messages
const _kUserTextColor = Color(0xFFFFFFFF);
const _kAiTextColor = Color(0xE6FFFFFF); // Soft off-white for body text
const _kAiLabelColor = Color(0xFF3BE2B0); // Soothing wellness mint for the "Gemma" tag
const _kVioletColor = Color(0xFF926BFF); // Glowing violet for headings and bold texts
const _kBubbleRadius = 20.0;
const _kTailRadius = 4.0;

/// A chat message bubble with a slide-in entrance animation and native Markdown support.
/// User messages render in a beautiful blue rounded bubble.
/// AI (Gemma) responses render directly on the background, completely removing 
/// the rigid grey card container designs, and using tailored color highlights.
class ChatBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;
  final bool wasTruncated;
  final VoidCallback? onPlayAudio;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isStreaming = false,
    this.wasTruncated = false,
    this.onPlayAudio,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // User slides from right (+x), AI slides from left (-x).
    final beginOffset =
        widget.isUser ? const Offset(0.18, 0) : const Offset(-0.18, 0);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        // Fade completes in the first 60% of the slide duration.
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: widget.isUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            margin: EdgeInsetsDirectional.only(
              start: widget.isUser ? 48 : 8,
              end: widget.isUser ? 8 : 48,
              bottom: widget.isUser ? 10 : 20, // Give AI responses more breathing room
            ),
            padding: widget.isUser
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                : const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: widget.isUser
                ? BoxDecoration(
                    color: _kUserBubbleColor,
                    borderRadius: const BorderRadiusDirectional.only(
                      topStart: Radius.circular(_kBubbleRadius),
                      topEnd: Radius.circular(_kBubbleRadius),
                      bottomStart: Radius.circular(_kBubbleRadius),
                      bottomEnd: Radius.circular(_kTailRadius),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000), // rgba(0,0,0,0.08)
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  )
                : null, // COMPLETELY REMOVE THE CARD CONTAINER DESIGN FOR AI!
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gemma',
                          style: TextStyle(
                            color: _kAiLabelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (widget.onPlayAudio != null && !widget.isStreaming && widget.text.isNotEmpty)
                          GestureDetector(
                            onTap: widget.onPlayAudio,
                            child: const Icon(Icons.volume_up_rounded, size: 16, color: _kAiLabelColor),
                          ),
                      ],
                    ),
                  ),
                _BubbleText(
                  text: widget.text,
                  isUser: widget.isUser,
                  isStreaming: widget.isStreaming,
                ),
                if (widget.wasTruncated && !widget.isUser) ...[
                  const SizedBox(height: 10),
                  SelectionContainer.disabled(
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: _kAiLabelColor,
                          ),
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Response truncated at 512 tokens',
                            style: TextStyle(
                              color: _kAiLabelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bubble Body Text with Native Markdown Support & Blinking Cursor ──────────

class _BubbleText extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;

  const _BubbleText({
    required this.text,
    required this.isUser,
    required this.isStreaming,
  });

  @override
  State<_BubbleText> createState() => _BubbleTextState();
}

class _BubbleTextState extends State<_BubbleText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    );
    if (widget.isStreaming) _cursorController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_BubbleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming && !_cursorController.isAnimating) {
      _cursorController.repeat(reverse: true);
    } else if (!widget.isStreaming && _cursorController.isAnimating) {
      _cursorController.stop();
      _cursorController.value = 0;
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isUser ? _kUserTextColor : _kAiTextColor;

    if (widget.isUser) {
      return Text(
        widget.text,
        style: TextStyle(
          color: baseColor,
          fontSize: 15,
          height: 1.45,
        ),
      );
    }

    // AI Markdown Style Sheet - custom colors for headings, bold elements, & lists
    final markdownStyle = MarkdownStyleSheet(
      p: TextStyle(
        color: baseColor,
        fontSize: 14.5,
        height: 1.55,
      ),
      strong: const TextStyle(
        color: _kVioletColor, // Glowing violet for bold elements/titles!
        fontWeight: FontWeight.w800,
      ),
      em: const TextStyle(
        color: Color(0xFFE2B0FF), // Soft lavender for italics
        fontStyle: FontStyle.italic,
      ),
      listBullet: const TextStyle(
        color: _kAiLabelColor, // Glowing mint for bullet lists!
        fontWeight: FontWeight.bold,
      ),
      h1: const TextStyle(color: _kVioletColor, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
      h2: const TextStyle(color: _kVioletColor, fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
      h3: const TextStyle(color: _kAiLabelColor, fontSize: 16, fontWeight: FontWeight.bold, height: 1.4),
      listBulletPadding: const EdgeInsets.only(right: 6, top: 2),
      blockquoteDecoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      code: const TextStyle(
        color: _kAiLabelColor,
        backgroundColor: Colors.transparent,
        fontSize: 13,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1.0),
      ),
    );

    // If streaming, animate the terminal cursor at the end dynamically
    if (widget.isStreaming) {
      return AnimatedBuilder(
        animation: _cursorController,
        builder: (context, _) {
          final showCursor = _cursorController.value > 0.5;
          final textWithCursor = showCursor ? '${widget.text}▊' : '${widget.text} ';

          return MarkdownBody(
            data: textWithCursor,
            styleSheet: markdownStyle,
          );
        },
      );
    }

    return MarkdownBody(
      data: widget.text,
      styleSheet: markdownStyle,
    );
  }
}
