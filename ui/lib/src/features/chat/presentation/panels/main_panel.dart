// lib/src/features/chat/presentation/panels/main_panel.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:LunarStudio/src/ffi/llm_engine.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

enum ChunkType { plain, thinking, code, heading, bullet }

class _TextSpan {
  final String text;
  final bool isBold;

  const _TextSpan(this.text, this.isBold);
}

class _Chunk {
  final List<_TextSpan> spans;
  final ChunkType type;
  final String? language;

  const _Chunk(this.spans, this.type, {this.language});
}

/// Parse bold markdown (**text**) into spans
List<_TextSpan> _parseBoldText(String text) {
  final List<_TextSpan> spans = [];
  int idx = 0;

  while (idx < text.length) {
    final boldStart = text.indexOf('**', idx);
    if (boldStart == -1) {
      if (idx < text.length) {
        spans.add(_TextSpan(text.substring(idx), false));
      }
      break;
    }

    if (boldStart > idx) {
      spans.add(_TextSpan(text.substring(idx, boldStart), false));
    }

    final boldEnd = text.indexOf('**', boldStart + 2);
    if (boldEnd == -1) {
      spans.add(_TextSpan(text.substring(boldStart), false));
      break;
    }

    final boldText = text.substring(boldStart + 2, boldEnd);
    if (boldText.isNotEmpty) {
      spans.add(_TextSpan(boldText, true));
    }
    idx = boldEnd + 2;
  }

  return spans;
}

/// Parse full text including <think>...</think> and visible content.
List<_Chunk> parseTextToChunks(String text) {
  final List<_Chunk> chunks = [];
  int idx = 0;

  while (idx < text.length) {
    final startTag = text.indexOf('<think>', idx);
    if (startTag == -1) {
      final rem = text.substring(idx);
      if (rem.isNotEmpty) {
        chunks.addAll(_parseVisibleSegment(rem));
      }
      break;
    }

    if (startTag > idx) {
      final plain = text.substring(idx, startTag);
      if (plain.isNotEmpty) {
        chunks.addAll(_parseVisibleSegment(plain));
      }
    }

    final endTag = text.indexOf('</think>', startTag + 7);
    if (endTag == -1) {
      final inner = text.substring(startTag + 7);
      if (inner.isNotEmpty) {
        chunks.add(_Chunk(_parseBoldText(inner), ChunkType.thinking));
      }
      break;
    } else {
      final inner = text.substring(startTag + 7, endTag);
      if (inner.isNotEmpty) {
        chunks.add(_Chunk(_parseBoldText(inner), ChunkType.thinking));
      }
      idx = endTag + 8;
    }
  }

  return chunks;
}

/// Parse only visible text, handling ```code``` and markdown-like structure.
List<_Chunk> _parseVisibleSegment(String text) {
  final List<_Chunk> chunks = [];
  int idx = 0;

  while (idx < text.length) {
    final fenceStart = text.indexOf('```', idx);
    if (fenceStart == -1) {
      _splitPlainIntoLines(text.substring(idx), chunks);
      break;
    }

    if (fenceStart > idx) {
      _splitPlainIntoLines(text.substring(idx, fenceStart), chunks);
    }

    final langLineEnd = text.indexOf('\n', fenceStart + 3);
    if (langLineEnd == -1) {
      _splitPlainIntoLines(text.substring(fenceStart), chunks);
      break;
    }

    // Extract language
    final language = text.substring(fenceStart + 3, langLineEnd).trim();

    final fenceEnd = text.indexOf('```', langLineEnd + 1);
    if (fenceEnd == -1) {
      final code = text.substring(langLineEnd + 1);
      if (code.trim().isNotEmpty) {
        chunks.add(_Chunk(
          [_TextSpan(code.trimRight(), false)],
          ChunkType.code,
          language: language.isEmpty ? null : language,
        ));
      }
      break;
    } else {
      final code = text.substring(langLineEnd + 1, fenceEnd);
      if (code.trim().isNotEmpty) {
        chunks.add(_Chunk(
          [_TextSpan(code.trimRight(), false)],
          ChunkType.code,
          language: language.isEmpty ? null : language,
        ));
      }
      idx = fenceEnd + 3;
    }
  }

  return chunks;
}

/// Split plain text into lines and classify as heading, bullet, or plain.
void _splitPlainIntoLines(String text, List<_Chunk> chunks) {
  final lines = text.split('\n');
  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    if (line.isEmpty) continue;
    final trimmedLeft = rawLine.trimLeft();

    if (line.startsWith('### ')) {
      chunks.add(_Chunk(_parseBoldText(line.substring(4).trimLeft()), ChunkType.heading));
    } else if (line.startsWith('## ')) {
      chunks.add(_Chunk(_parseBoldText(line.substring(3).trimLeft()), ChunkType.heading));
    } else if (line.startsWith('# ')) {
      chunks.add(_Chunk(_parseBoldText(line.substring(2).trimLeft()), ChunkType.heading));
    } else if (trimmedLeft.startsWith('- ') || trimmedLeft.startsWith('* ')) {
      final bulletText = trimmedLeft.substring(2).trimLeft();
      if (bulletText.isNotEmpty) {
        chunks.add(_Chunk(_parseBoldText(bulletText), ChunkType.bullet));
      }
    } else {
      chunks.add(_Chunk(_parseBoldText(line), ChunkType.plain));
    }
  }
}

class MainPanel extends StatefulWidget {
  final bool engineReady;

  const MainPanel({super.key, required this.engineReady});

  @override
  State<MainPanel> createState() => _MainPanelState();
}

class _MainPanelState extends State<MainPanel> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode keyboardFocus = FocusNode();
  final FocusNode textFieldFocus = FocusNode();

  final List<_ChatMessage> messages = [];

  bool get engineReady => widget.engineReady;
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    keyboardFocus.requestFocus();
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    keyboardFocus.dispose();
    textFieldFocus.dispose();
    for (final m in messages) {
      m.dispose();
    }
    super.dispose();
  }

  void _performScroll() {
    if (!mounted || !scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _onSubmit() {
    if (!engineReady || isGenerating) return;

    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(_ChatMessage.fromPlain(role: 'user', plain: text));
      isGenerating = true;
    });

    controller.clear();
    _performScroll();
    _runLLM(text);
  }

  void _runLLM(String prompt) {
    final assistantMsg = _ChatMessage.emptyAssistant();
    setState(() {
      messages.add(assistantMsg);
    });

    final buffer = StringBuffer();

    LLMEngine()
        .generate(prompt, (String tok) {
          if (!mounted) return;
          buffer.write(tok);
          final parsed = parseTextToChunks(buffer.toString());
          assistantMsg.updateChunks(parsed);
          _performScroll();
        })
        .then((_) {
          if (!mounted) return;
          setState(() {
            isGenerating = false;
          });
          _performScroll();
        })
        .catchError((e) {
          if (!mounted) return;
          assistantMsg.updateChunks(
            [_Chunk([const _TextSpan('Error while generating response.', false)], ChunkType.plain)],
          );
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

    final TextStyle plainStyle = TextStyle(
      color: cs.onSurface,
      fontSize: 14,
      height: 1.5,
      letterSpacing: 0.2,
    );
    final TextStyle thinkingStyle = TextStyle(
      color: cs.onSurface.withOpacity(0.55),
      fontStyle: FontStyle.italic,
      fontSize: 14,
      height: 1.5,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surfaceVariant.withOpacity(0.35),
            cs.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final bool isUser = msg.role == 'user';

                final maxWidth = min(width * 0.9, 900);

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: RepaintBoundary(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth.toDouble(),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: EdgeInsets.zero,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isUser
                              ? cs.primary.withOpacity(0.12)
                              : cs.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cs.outline.withOpacity(0.6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: MessageBubble(
                            msg: msg,
                            plainStyle: plainStyle,
                            thinkingStyle: thinkingStyle,
                          ),
                        ),
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
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.85),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.background.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
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
                              hintText: isGenerating
                                  ? 'Generating response...'
                                  : 'Send a message…',
                              hintStyle: TextStyle(
                                color: cs.onSurface.withOpacity(0.4),
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                            ),
                            onSubmitted: (_) => _onSubmit(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: isGenerating ? null : _onSubmit,
                          child: Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primary,
                                  cs.primary.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                if (!isGenerating)
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                              color: cs.onPrimary,
                            ),
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
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.4),
                        fontSize: 10,
                      ),
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

  Widget _buildRichText(List<_TextSpan> spans, TextStyle baseStyle) {
    return RichText(
      text: TextSpan(
        children: spans.map((span) {
          return TextSpan(
            text: span.text,
            style: span.isBold
                ? baseStyle.copyWith(fontWeight: FontWeight.w700)
                : baseStyle,
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: msg.updateStream,
      initialData: 0,
      builder: (context, snapshot) {
        final chunks = msg.chunks;
        if (chunks.isEmpty) return const SizedBox.shrink();

        final List<Widget> children = <Widget>[];

        for (int i = 0; i < chunks.length; i++) {
          final c = chunks[i];
          final bool isLast = i == chunks.length - 1;

          switch (c.type) {
            case ChunkType.thinking:
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildRichText(c.spans, thinkingStyle),
                      ),
                      if (isLast) const SizedBox(width: 8),
                      if (isLast) const StreamingCursor(),
                    ],
                  ),
                ),
              );
              break;

            case ChunkType.code:
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CodeBlockWidget(
                    code: c.spans.map((s) => s.text).join(),
                    language: c.language ?? 'plaintext',
                  ),
                ),
              );
              break;

            case ChunkType.heading:
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                  child: _buildRichText(
                    c.spans,
                    plainStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16.5,
                    ),
                  ),
                ),
              );
              break;

            case ChunkType.bullet:
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: plainStyle.color?.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildRichText(c.spans, plainStyle),
                      ),
                    ],
                  ),
                ),
              );
              break;

            case ChunkType.plain:
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildRichText(c.spans, plainStyle),
                      ),
                      if (isLast) const SizedBox(width: 4),
                      if (isLast) const StreamingCursor(),
                    ],
                  ),
                ),
              );
              break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      },
    );
  }
}

class CodeBlockWidget extends StatefulWidget {
  final String code;
  final String language;

  const CodeBlockWidget({
    required this.code,
    required this.language,
    super.key,
  });

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _copied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() {
      _copied = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  String _getDisplayLanguage() {
    final lang = widget.language.toLowerCase();
    final langMap = {
      'dart': 'Dart',
      'python': 'Python',
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
      'java': 'Java',
      'cpp': 'C++',
      'c': 'C',
      'csharp': 'C#',
      'go': 'Go',
      'rust': 'Rust',
      'kotlin': 'Kotlin',
      'swift': 'Swift',
      'ruby': 'Ruby',
      'php': 'PHP',
      'html': 'HTML',
      'css': 'CSS',
      'json': 'JSON',
      'yaml': 'YAML',
      'bash': 'Bash',
      'shell': 'Shell',
      'sql': 'SQL',
    };
    return langMap[lang] ?? lang.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1b26),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  _getDisplayLanguage(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _copyToClipboard,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _copied
                            ? Colors.green.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _copied
                              ? Colors.green.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied ? Icons.check_rounded : Icons.content_copy_rounded,
                            size: 14,
                            color: _copied
                                ? Colors.green.shade300
                                : Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _copied ? 'Copied!' : 'Copy',
                            style: TextStyle(
                              color: _copied
                                  ? Colors.green.shade300
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Code content with syntax highlighting
          Container(
            color: const Color(0xFF0d1117),
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                widget.code,
                language: widget.language,
                theme: monokaiSublimeTheme,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StreamingCursor extends StatefulWidget {
  const StreamingCursor({super.key});

  @override
  State<StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2.5,
        height: 18,
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final List<_Chunk> _chunks = [];
  final StreamController<int> _updateController = StreamController<int>.broadcast();

  _ChatMessage._(this.role, List<_Chunk> initialChunks) {
    _chunks.addAll(initialChunks);
  }

  factory _ChatMessage({required String role, required List<_Chunk> chunks}) {
    return _ChatMessage._(role, chunks);
  }

  factory _ChatMessage.fromPlain({
    required String role,
    required String plain,
  }) {
    final parsed = parseTextToChunks(plain);
    return _ChatMessage._(
      role,
      parsed.isEmpty
          ? [_Chunk([const _TextSpan('', false)], ChunkType.plain)]
          : parsed,
    );
  }

  factory _ChatMessage.emptyAssistant() {
    return _ChatMessage._('assistant', <_Chunk>[
      _Chunk([const _TextSpan('', false)], ChunkType.plain),
    ]);
  }

  void updateChunks(List<_Chunk> newChunks) {
    _chunks.clear();
    _chunks.addAll(newChunks);
    _updateController.add(_chunks.length);
  }

  List<_Chunk> get chunks => _chunks;
  Stream<int> get updateStream => _updateController.stream;

  void dispose() => _updateController.close();
}