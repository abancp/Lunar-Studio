// lib/src/features/chat/presentation/panels/main_panel.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:LunarStudio/src/ffi/llm_engine.dart';

class MainPanel extends StatefulWidget {
  const MainPanel({super.key});

  @override
  State<MainPanel> createState() => _MainPanelState();
}

class _MainPanelState extends State<MainPanel> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode keyboardFocus = FocusNode();
  final FocusNode textFieldFocus = FocusNode();

  // messages will contain ChatMessage instances that hold their own notifiers
  final List<_ChatMessage> messages = [];

  bool engineReady = false;
  bool isGenerating = false;

  // Batch updates for smoother rendering
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    keyboardFocus.requestFocus();
    _startEngine();
  }

  Future<void> _startEngine() async {
    try {
      await LLMEngine().start(
        '/home/abancp/Projects/localGPT1.0/build/liblunarstudio.so',
      );
      if (mounted) setState(() => engineReady = true);
    } catch (e) {
      debugPrint('❌ Engine error: $e');
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    controller.dispose();
    scrollController.dispose();
    keyboardFocus.dispose();
    textFieldFocus.dispose();
    // dispose notifiers in messages
    for (final m in messages) {
      m.dispose();
    }
    super.dispose();
  }

  void _scrollToBottom() {
    _performScroll();
  }

  void _performScroll() {
    if (!mounted || !scrollController.hasClients) return;

    try {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    } catch (_) {
      // ignore if layout not ready
    }
  }

  void _onSubmit() {
    if (!engineReady || isGenerating) return;

    final text = controller.text.trim();
    if (text.isEmpty) return;

    // Add user message quickly
    setState(() {
      messages.add(_ChatMessage.fromPlain(role: 'user', plain: text));
      isGenerating = true;
    });

    controller.clear();
    _performScroll();
    _runLLM(text);
  }

  List<_Chunk> _parseChunks(String text) {
    final List<_Chunk> chunks = [];
    int idx = 0;
    while (idx < text.length) {
      final startTag = text.indexOf('<think>', idx);
      if (startTag == -1) {
        final rem = text.substring(idx);
        if (rem.isNotEmpty) chunks.add(_Chunk(rem, isThinking: false));
        break;
      }
      if (startTag > idx) {
        final plain = text.substring(idx, startTag);
        if (plain.isNotEmpty) chunks.add(_Chunk(plain, isThinking: false));
      }
      final endTag = text.indexOf('</think>', startTag + 7);
      if (endTag == -1) {
        final inner = text.substring(startTag + 7);
        if (inner.isNotEmpty) chunks.add(_Chunk(inner, isThinking: true));
        break;
      } else {
        final inner = text.substring(startTag + 7, endTag);
        if (inner.isNotEmpty) chunks.add(_Chunk(inner, isThinking: true));
        idx = endTag + 8;
      }
    }
    return chunks;
  }

  void _runLLM(String prompt) {
    // Add assistant placeholder message with its own notifier
    final assistantMsg = _ChatMessage.emptyAssistant();
    setState(() {
      messages.add(assistantMsg);
    });

    final int index = messages.length - 1;
    final buffer = StringBuffer();

    LLMEngine().generate(prompt, (String tok) {
      if (!mounted) return;
      buffer.write(tok);
      final parsed = _parseChunks(buffer.toString());
      // Update only the assistant's notifier — avoids setState per token
      assistantMsg.updateChunks(parsed);
    }).then((_) {
      if (!mounted) return;
      // Stop generation state and finalize: if there are no chunks, keep empty string
      setState(() {
        isGenerating = false;
      });
      _performScroll();
    }).catchError((e) {
      if (!mounted) return;
      assistantMsg.updateChunks([_Chunk('Error: $e', isThinking: false)]);
      setState(() {
        isGenerating = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    double hPad = 16;
    double tPad = 10;
    double bPad = 14;

    if (width > 1600) {
      hPad = 48;
      bPad = 32;
    } else if (width > 1200) {
      hPad = 32;
      bPad = 24;
    }

    // Reusable styles to avoid allocations each build
    final TextStyle plainStyle = TextStyle(color: cs.onSurface, fontSize: 14);
    final TextStyle thinkingStyle = TextStyle(
      color: cs.onSurface.withOpacity(0.55),
      fontStyle: FontStyle.italic,
      fontSize: 14,
    );

    return Container(
      color: cs.background,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final bool isUser = msg.role == 'user';

                // compute dynamic max width: up to 90% of screen or 900px max
                final maxWidth = min(width * 0.9, 900);

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: RepaintBoundary(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxWidth.toDouble()),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? cs.primary.withOpacity(0.16) : cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outline),
                      ),
                      child: MessageBubble(
                        msg: msg,
                        plainStyle: plainStyle,
                        thinkingStyle: thinkingStyle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          RawKeyboardListener(
            focusNode: keyboardFocus,
            autofocus: true,
            onKey: (event) {
              if (event is RawKeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  !event.isShiftPressed) {
                _onSubmit();
              }
            },
            child: Container(
              padding: EdgeInsets.fromLTRB(hPad, tPad, hPad, bPad),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: textFieldFocus,
                            controller: controller,
                            enabled: !isGenerating,
                            minLines: 1,
                            maxLines: 8,
                            keyboardType: TextInputType.multiline,
                            style: plainStyle,
                            decoration: InputDecoration(
                              hintText: isGenerating ? 'Generating...' : 'Send a message…',
                              hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.4)),
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onSubmitted: (_) => _onSubmit(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: isGenerating ? null : _onSubmit,
                          child: Container(
                            height: 34,
                            width: 34,
                            decoration: BoxDecoration(
                              color: isGenerating ? cs.primary.withOpacity(0.5) : cs.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.arrow_upward_rounded, size: 20, color: cs.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Responses from AI may be incorrect.',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget that shows a single message bubble's content. Listens to the message's notifier
/// and rebuilds only when that message's chunks change.
class MessageBubble extends StatelessWidget {
  final _ChatMessage msg;
  final TextStyle plainStyle;
  final TextStyle thinkingStyle;

  const MessageBubble({
    required this.msg,
    required this.plainStyle,
    required this.thinkingStyle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<_Chunk>>(
      valueListenable: msg.chunksNotifier,
      builder: (context, chunks, _) {
        // Build a column of chunks; thinking chunks include dots when they are last and marked thinking.
        final List<Widget> children = <Widget>[];

        for (int i = 0; i < chunks.length; i++) {
          final c = chunks[i];
          if (c.isThinking) {
            final bool isLastThinking = i == chunks.length - 1;
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(c.text, style: thinkingStyle)),
                    if (isLastThinking)
                      const SizedBox(width: 8),
                    if (isLastThinking)
                      ThinkingDots(),
                  ],
                ),
              ),
            );
          } else {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(c.text, style: plainStyle),
              ),
            );
          }
        }

        if (children.isEmpty) return const SizedBox.shrink();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }
}

/// Small widget that runs its own lightweight animation for dots and auto-starts/stops.
class ThinkingDots extends StatefulWidget {
  const ThinkingDots({super.key});

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // short loop, lightweight
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final TextStyle dotStyle = TextStyle(color: cs.onSurface.withOpacity(0.55), fontStyle: FontStyle.italic, fontSize: 14);

    return SizedBox(
      width: 36,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final step = (_controller.value * 3).floor();
          final dots = '.' * (step + 1);
          return Text(dots, style: dotStyle, maxLines: 1, overflow: TextOverflow.clip);
        },
      ),
    );
  }
}

/// Small immutable chunk (plain or thinking)
class _Chunk {
  final String text;
  final bool isThinking;

  const _Chunk(this.text, {required this.isThinking});
}

/// Message object that owns a ValueNotifier for per-message updates.
class _ChatMessage {
  final String role;
  final ValueNotifier<List<_Chunk>> chunksNotifier;

  _ChatMessage._(this.role, List<_Chunk> initial) : chunksNotifier = ValueNotifier<List<_Chunk>>(initial);

  factory _ChatMessage({required String role, required List<_Chunk> chunks}) {
    return _ChatMessage._(role, chunks);
  }

  factory _ChatMessage.fromPlain({required String role, required String plain}) {
    final parsed = _parsePlain(plain);
    return _ChatMessage._(role, parsed);
  }

  factory _ChatMessage.emptyAssistant() {
    return _ChatMessage._('assistant', <_Chunk>[_Chunk('', isThinking: false)]);
  }

  void updateChunks(List<_Chunk> newChunks) {
    // Replace entire list atomically — ValueNotifier will notify listeners.
    chunksNotifier.value = List<_Chunk>.unmodifiable(newChunks);
  }

  List<_Chunk> get chunks => chunksNotifier.value;

  void dispose() => chunksNotifier.dispose();

  static List<_Chunk> _parsePlain(String text) {
    final List<_Chunk> chunks = [];
    int idx = 0;
    while (idx < text.length) {
      final startTag = text.indexOf('<think>', idx);
      if (startTag == -1) {
        final rem = text.substring(idx);
        if (rem.isNotEmpty) chunks.add(_Chunk(rem, isThinking: false));
        break;
      }
      if (startTag > idx) {
        final plain = text.substring(idx, startTag);
        if (plain.isNotEmpty) chunks.add(_Chunk(plain, isThinking: false));
      }
      final endTag = text.indexOf('</think>', startTag + 7);
      if (endTag == -1) {
        final inner = text.substring(startTag + 7);
        if (inner.isNotEmpty) chunks.add(_Chunk(inner, isThinking: true));
        break;
      } else {
        final inner = text.substring(startTag + 7, endTag);
        if (inner.isNotEmpty) chunks.add(_Chunk(inner, isThinking: true));
        idx = endTag + 8;
      }
    }
    return chunks;
  }
}
