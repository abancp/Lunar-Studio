// lib/src/features/chat/presentation/panels/main_panel.dart
import 'dart:async';
import 'dart:math';
import 'package:LunarStudio/src/core/db/app_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:LunarStudio/src/ffi/llm_engine.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:motion_toast/motion_toast.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

// --- 1. DATA STRUCTURES (Unified) ---

enum ChunkType {
  plain,
  thinking,
  code,
  heading,
  bullet,
  table,
  blockquote,
  latexBlock,
}

enum SpanType { plain, bold, latexInline, inlineCode }

// Replaces the old _TextSpan class
class _Span {
  final String text;
  final SpanType type;
  const _Span(this.text, this.type);
}

class _Chunk {
  final List<_Span> spans; // STRICTLY uses _Span now
  final ChunkType type;
  final String? language;
  final Map<String, dynamic>? metadata;

  const _Chunk(this.spans, this.type, {this.language, this.metadata});
}

// --- 2. PARSING LOGIC ---

/// Unified parser: Handles **Bold**, \( Latex \), and `Inline Code`
List<_Span> _parseRichText(String text) {
  final List<_Span> spans = [];

  // Regex matches: \( ... \) OR ** ... ** OR ` ... `
  final regex = RegExp(r'(\\\(.*?\\\))|(\*\*.*?\*\*)|(`.*?`)');

  int start = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > start) {
      spans.add(_Span(text.substring(start, match.start), SpanType.plain));
    }

    final String matchText = match.group(0)!;

    if (matchText.startsWith(r'\(')) {
      // Inline Math: Remove \( and \)
      final cleanMath = matchText.substring(2, matchText.length - 2);
      spans.add(_Span(cleanMath, SpanType.latexInline));
    } else if (matchText.startsWith('`')) {
      // Inline Code: Remove ` and `
      final cleanCode = matchText.substring(1, matchText.length - 1);
      spans.add(_Span(cleanCode, SpanType.inlineCode));
    } else {
      // Bold: Remove ** and **
      final cleanBold = matchText.substring(2, matchText.length - 2);
      spans.add(_Span(cleanBold, SpanType.bold));
    }
    start = match.end;
  }

  if (start < text.length) {
    spans.add(_Span(text.substring(start), SpanType.plain));
  }

  return spans;
}

bool _hasOpenThinkTag(String text) => text.contains('<search>');

List<_Chunk> parseTextToChunks(String text) {
  final List<_Chunk> chunks = [];
  int idx = 0;
  while (idx < text.length) {
    final startTag = text.indexOf('<search>', idx);
    if (startTag == -1) {
      final rem = text.substring(idx);
      if (rem.isNotEmpty) chunks.addAll(_parseVisibleSegment(rem));
      break;
    }
    if (startTag > idx) {
      final plain = text.substring(idx, startTag);
      if (plain.isNotEmpty) chunks.addAll(_parseVisibleSegment(plain));
    }
    final endTag = text.indexOf('</search>', startTag + 7);
    if (endTag == -1) {
      final inner = text.substring(startTag + 7);
      if (inner.isNotEmpty)
        chunks.add(_Chunk(_parseRichText(inner), ChunkType.thinking));
      break;
    } else {
      final inner = text.substring(startTag + 7, endTag);
      if (inner.isNotEmpty)
        chunks.add(_Chunk(_parseRichText(inner), ChunkType.thinking));
      idx = endTag + 8;
    }
  }
  return chunks;
}

List<_Chunk> _parseVisibleSegment(String text) {
  final List<_Chunk> chunks = [];
  int idx = 0;
  while (idx < text.length) {
    final fenceStart = text.indexOf('```', idx);
    if (fenceStart == -1) {
      _splitPlainIntoStructure(text.substring(idx), chunks);
      break;
    }
    if (fenceStart > idx) {
      _splitPlainIntoStructure(text.substring(idx, fenceStart), chunks);
    }
    final langLineEnd = text.indexOf('\n', fenceStart + 3);
    if (langLineEnd == -1) {
      _splitPlainIntoStructure(text.substring(fenceStart), chunks);
      break;
    }
    final language = text.substring(fenceStart + 3, langLineEnd).trim();
    final fenceEnd = text.indexOf('```', langLineEnd + 1);
    if (fenceEnd == -1) {
      final code = text.substring(langLineEnd + 1);
      if (code.trim().isNotEmpty) {
        // FIXED: Explicitly use _Span here
        chunks.add(
          _Chunk(
            [_Span(code.trimRight(), SpanType.plain)],
            ChunkType.code,
            language: language.isEmpty ? null : language,
          ),
        );
      }
      break;
    } else {
      final code = text.substring(langLineEnd + 1, fenceEnd);
      if (code.trim().isNotEmpty) {
        // FIXED: Explicitly use _Span here
        chunks.add(
          _Chunk(
            [_Span(code.trimRight(), SpanType.plain)],
            ChunkType.code,
            language: language.isEmpty ? null : language,
          ),
        );
      }
      idx = fenceEnd + 3;
    }
  }
  return chunks;
}

void _splitPlainIntoStructure(String text, List<_Chunk> chunks) {
  final lines = text.split('\n');
  List<String> tableBuffer = [];
  List<String> latexBuffer = [];
  bool inLatexBlock = false;

  void flushTable() {
    if (tableBuffer.isNotEmpty) {
      final cleanRows = tableBuffer.where((row) {
        final trimmed = row.trim();
        return trimmed.replaceAll(RegExp(r'[|\-\s]'), '').isNotEmpty ||
            trimmed.contains('|');
      }).toList();

      if (cleanRows.length > 1) {
        chunks.add(
          _Chunk(
            const [],
            ChunkType.table,
            metadata: {'rows': List<String>.from(tableBuffer)},
          ),
        );
      } else {
        for (var row in tableBuffer) {
          chunks.add(_Chunk(_parseRichText(row), ChunkType.plain));
        }
      }
      tableBuffer.clear();
    }
  }

  void flushLatex() {
    if (latexBuffer.isNotEmpty) {
      String math = latexBuffer.join('\n').trim();
      if (math.startsWith(r'\[')) math = math.substring(2);
      if (math.endsWith(r'\]')) math = math.substring(0, math.length - 2);

      chunks.add(
        _Chunk(const [], ChunkType.latexBlock, metadata: {'math': math.trim()}),
      );
      latexBuffer.clear();
    }
  }

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final trimmed = line.trim();

    if (trimmed.startsWith(r'\[')) {
      flushTable();
      inLatexBlock = true;
    }

    if (inLatexBlock) {
      latexBuffer.add(line);
      if (trimmed.endsWith(r'\]')) {
        inLatexBlock = false;
        flushLatex();
      }
      continue;
    }

    if (trimmed.startsWith('|')) {
      tableBuffer.add(line);
      continue;
    } else {
      flushTable();
    }

    if (line.isEmpty) continue;

    if (trimmed.startsWith('#### ')) {
      chunks.add(
        _Chunk(
          _parseRichText(trimmed.substring(4).trimLeft()),
          ChunkType.heading,
          metadata: {'level': 4},
        ),
      );
    } else if (trimmed.startsWith('### ')) {
      chunks.add(
        _Chunk(
          _parseRichText(trimmed.substring(3).trimLeft()),
          ChunkType.heading,
          metadata: {'level': 3},
        ),
      );
    } else if (trimmed.startsWith('## ')) {
      chunks.add(
        _Chunk(
          _parseRichText(trimmed.substring(2).trimLeft()),
          ChunkType.heading,
          metadata: {'level': 2},
        ),
      );
    } else if (trimmed.startsWith('# ')) {
      chunks.add(
        _Chunk(
          _parseRichText(trimmed.substring(1).trimLeft()),
          ChunkType.heading,
          metadata: {'level': 1},
        ),
      );
    } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      final bulletText = trimmed.substring(2).trimLeft();
      if (bulletText.isNotEmpty) {
        chunks.add(_Chunk(_parseRichText(bulletText), ChunkType.bullet));
      }
    } else if (trimmed.startsWith('>')) {
      chunks.add(
        _Chunk(
          _parseRichText(trimmed.substring(1).trimLeft()),
          ChunkType.blockquote,
        ),
      );
    } else {
      chunks.add(_Chunk(_parseRichText(line), ChunkType.plain));
    }
  }
  flushTable();
  flushLatex();
}

// --- 3. WIDGETS ---

class MainPanel extends StatefulWidget {
  final bool engineReady;
  final int chatId;
  final void Function(int) setChatId;
  final String loadedModel;
  final void Function(String, int, String, int, void Function(int))
  addMessageToChat;

  const MainPanel({
    super.key,
    required this.engineReady,
    required this.chatId,
    required this.setChatId,
    required this.loadedModel,
    required this.addMessageToChat,
  });

  @override
  State<MainPanel> createState() => MainPanelState();
}

class MainPanelState extends State<MainPanel> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode keyboardFocus = FocusNode();
  final FocusNode textFieldFocus = FocusNode();
  final List<_ChatMessage> messages = [];
  bool get engineReady => widget.engineReady;
  bool isGenerating = false;
  int seq = 0;

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

  void loadMessages(int chatId) async {
    final db = await AppDB.instance;
    final rawMessages = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'sequence ASC',
    );

    setState(() {
      messages.clear();
    });

    widget.setChatId(chatId);
    for (final m in rawMessages) {
      setState(() {
        messages.add(
          _ChatMessage.fromPlain(
            role: m['role'].toString(),
            plain: m['content'].toString(),
          ),
        );
      });
    }
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
    if (widget.loadedModel == "") {
      if (!mounted) return;
      MotionToast.info(description: Text("Load a Model")).show(context);
      return;
    }
    if (!engineReady || isGenerating) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(_ChatMessage.fromPlain(role: 'user', plain: text));
      isGenerating = true;
    });
    widget.addMessageToChat(
      text,
      widget.chatId,
      "user",
      seq + 1,
      widget.setChatId,
    );
    seq++;
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
          assistantMsg.updateFromText(buffer.toString());
          _performScroll();
        })
        .then((res) {
          if (!mounted) return;
          widget.addMessageToChat(
            res,
            widget.chatId,
            'assistant',
            seq + 1,
            widget.setChatId,
          );
          seq++;
          setState(() {
            isGenerating = false;
          });
          _performScroll();
        })
        .catchError((e) {
          if (!mounted) return;
          assistantMsg.updateFromText('Error while generating response.');
          setState(() {
            isGenerating = false;
          });
        });
  }

  EdgeInsets _getResponsivePadding(double width) {
    if (width < 600)
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 20);
    else if (width < 900)
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    else if (width < 1200)
      return const EdgeInsets.symmetric(horizontal: 80, vertical: 28);
    else if (width < 1600)
      return const EdgeInsets.symmetric(horizontal: 150, vertical: 32);
    else
      return const EdgeInsets.symmetric(horizontal: 280, vertical: 32);
  }

  EdgeInsets _getInputBarPadding(double width) {
    if (width < 600)
      return const EdgeInsets.fromLTRB(16, 1, 16, 3);
    else if (width < 900)
      return const EdgeInsets.fromLTRB(32, 1, 32, 3);
    else if (width < 1200)
      return const EdgeInsets.fromLTRB(80, 1, 80, 3);
    else if (width < 1600)
      return const EdgeInsets.fromLTRB(150, 1, 150, 3);
    else
      return const EdgeInsets.fromLTRB(280, 1, 280, 3);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final chatPadding = _getResponsivePadding(width);
    final inputPadding = _getInputBarPadding(width);

    final TextStyle plainStyle = TextStyle(
      color: cs.onSurface,
      fontSize: width < 600 ? 14 : 15.5,
      height: 1.6,
      letterSpacing: 0.2,
    );

    final TextStyle thinkingStyle = TextStyle(
      color: cs.onSurface.withOpacity(0.55),
      fontStyle: FontStyle.italic,
      fontSize: width < 600 ? 13 : 14,
      height: 1.6,
    );

    return Container(
      decoration: BoxDecoration(
        color: cs.background, // Clean solid background
      ),
      child: messages.isNotEmpty
          ? Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: chatPadding,
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final bool isUser = msg.role == 'user';
                      final maxWidth = width < 600
                          ? width * 0.95
                          : width < 900
                          ? width * 0.85
                          : min(width * 0.75, 900.0);

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: RepaintBoundary(
                          child: Container(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            margin: EdgeInsets.symmetric(
                              vertical: width < 600 ? 6 : 8,
                            ),
                            child: DecoratedBox(
                              decoration: isUser
                                  ? BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          cs.primary.withOpacity(0.2),
                                          cs.primary.withOpacity(0.05),
                                        ],
                                        begin: Alignment.topRight,
                                        end: Alignment.bottomLeft,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        width < 600 ? 12 : 16,
                                      ),
                                      border: Border.all(
                                        color: cs.primary.withOpacity(0.3),
                                      ),
                                    )
                                  : const BoxDecoration(),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: width < 600 ? 12 : 16,
                                  vertical: width < 600 ? 10 : 12,
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
                _buildInputArea(cs, inputPadding, width, plainStyle),
              ],
            )
          : _buildInputAreaCentered(cs, inputPadding, width, plainStyle),
    );
  }

  Widget _buildInputArea(
    ColorScheme cs,
    EdgeInsets padding,
    double width,
    TextStyle style,
  ) {
    return RawKeyboardListener(
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
        padding: padding,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: width < 600 ? 10 : 12,
                vertical: width < 600 ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24), // More rounded
                border: Border.all(
                  color: cs.outline.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                      maxLines: width < 600 ? 6 : 8,
                      keyboardType: TextInputType.multiline,
                      style: style,
                      decoration: InputDecoration(
                        hintText: isGenerating
                            ? 'Generating response...'
                            : 'Send a message…',
                        hintStyle: TextStyle(
                          color: cs.onSurface.withOpacity(0.4),
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: width < 600 ? 8 : 10,
                        ),
                      ),
                      onSubmitted: (_) => _onSubmit(),
                    ),
                  ),
                  SizedBox(width: width < 600 ? 6 : 8),
                  GestureDetector(
                    onTap: isGenerating ? null : _onSubmit,
                    child: Container(
                      height: width < 600 ? 34 : 38,
                      width: width < 600 ? 34 : 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.primary.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          20,
                        ), // Rounded submit button
                      ),
                      child: Icon(
                        BootstrapIcons.arrow_up, // Cleaner arrow icon
                        size: 20,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                'Responses from AI may be incorrect.',
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.4),
                  fontSize: width < 600 ? 9 : 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputAreaCentered(
    ColorScheme cs,
    EdgeInsets padding,
    double width,
    TextStyle style,
  ) {
    return Flex(
      direction: Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Center(child: _buildInputArea(cs, padding, width, style))],
    );
  }
}

class MessageBubble extends StatefulWidget {
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
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  Widget _buildRichText(List<_Span> spans, TextStyle baseStyle) {
    return RichText(
      text: TextSpan(
        children: spans.map((span) {
          if (span.type == SpanType.latexInline) {
            return WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Math.tex(
                  span.text,
                  textStyle: baseStyle.copyWith(
                    fontSize: (baseStyle.fontSize ?? 14) * 0.95,
                  ),
                ),
              ),
            );
          } else if (span.type == SpanType.bold) {
            return TextSpan(
              text: span.text,
              style: baseStyle.copyWith(fontWeight: FontWeight.w800),
            );
          } else {
            return TextSpan(text: span.text, style: baseStyle);
          }
        }).toList(),
      ),
    );
  }

  Widget _buildTable(
    List<String> rawRows,
    TextStyle baseStyle,
    ColorScheme cs,
  ) {
    if (rawRows.isEmpty) return const SizedBox.shrink();

    List<List<String>> processedRows = [];
    int maxCols = 0;

    for (String row in rawRows) {
      if (row.contains('---')) continue;
      String cleanRow = row.trim();
      if (cleanRow.startsWith('|')) cleanRow = cleanRow.substring(1);
      if (cleanRow.endsWith('|'))
        cleanRow = cleanRow.substring(0, cleanRow.length - 1);

      List<String> cells = cleanRow.split('|');
      if (cells.length > maxCols) maxCols = cells.length;
      processedRows.add(cells);
    }

    if (processedRows.isEmpty || maxCols == 0) return const SizedBox.shrink();

    List<TableRow> rows = [];
    for (int i = 0; i < processedRows.length; i++) {
      final List<String> cells = processedRows[i];
      final bool isHeader = i == 0;
      List<Widget> cellWidgets = [];

      for (var cell in cells) {
        cellWidgets.add(
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color: isHeader ? cs.primary.withOpacity(0.08) : null,
              child: _buildRichText(
                _parseRichText(cell.trim()), // Uses the new Parser
                baseStyle.copyWith(
                  fontSize: baseStyle.fontSize! - 1,
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }

      while (cellWidgets.length < maxCols) {
        cellWidgets.add(
          const TableCell(
            child: Padding(padding: EdgeInsets.all(8.0), child: Text("")),
          ),
        );
      }
      if (cellWidgets.length > maxCols)
        cellWidgets = cellWidgets.sublist(0, maxCols);

      rows.add(
        TableRow(
          decoration: isHeader
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: cs.outline.withOpacity(0.3)),
                  ),
                )
              : null,
          children: cellWidgets,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.symmetric(
              inside: BorderSide(color: cs.outline.withOpacity(0.2)),
            ),
            children: rows,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<int>(
      stream: widget.msg.updateStream,
      initialData: 0,
      builder: (context, snapshot) {
        final chunks = widget.msg.chunks;
        if (chunks.isEmpty) return const SizedBox.shrink();

        final List<Widget> children = [];
        bool hasThinking = false;

        for (int i = 0; i < chunks.length; i++) {
          final c = chunks[i];
          switch (c.type) {
            case ChunkType.thinking:
              hasThinking = true;
              break;
            case ChunkType.code:
              children.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: CodeBlockWidget(
                    code: c.spans.map((s) => s.text).join(),
                    language: c.language ?? 'plaintext',
                  ),
                ),
              );
              break;
            case ChunkType.heading:
              final level = c.metadata?['level'] ?? 1;
              double fontSize = 24.0;
              if (level == 2) fontSize = 20.0;
              if (level == 3) fontSize = 18.0;
              if (level == 3) fontSize = 17.0;
              children.add(
                Padding(
                  padding: EdgeInsets.only(
                    bottom: 8,
                    top: i == 0 ? 0 : (level == 1 ? 24 : 16),
                  ),
                  child: _buildRichText(
                    c.spans,
                    widget.plainStyle.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: fontSize,
                      height: 1.3,
                    ),
                  ),
                ),
              );
              break;
            case ChunkType.table:
              if (c.metadata != null && c.metadata!['rows'] != null) {
                children.add(
                  _buildTable(
                    c.metadata!['rows'] as List<String>,
                    widget.plainStyle,
                    cs,
                  ),
                );
              }
              break;
            case ChunkType.latexBlock:
              if (c.metadata != null && c.metadata!['math'] != null) {
                children.add(
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Math.tex(
                        c.metadata!['math'],
                        textStyle: widget.plainStyle.copyWith(fontSize: 16),
                      ),
                    ),
                  ),
                );
              }
              break;
            case ChunkType.blockquote:
              children.add(
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
                  // Removed the border decoration as per user request to remove the "|" bar
                  child: _buildRichText(
                    c.spans,
                    widget.plainStyle.copyWith(
                      fontStyle: FontStyle.italic,
                      color: widget.plainStyle.color?.withOpacity(0.8),
                    ),
                  ),
                ),
              );
              break;
            case ChunkType.bullet:
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: widget.plainStyle.color?.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildRichText(c.spans, widget.plainStyle),
                      ),
                    ],
                  ),
                ),
              );
              break;
            case ChunkType.plain:
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRichText(c.spans, widget.plainStyle),
                ),
              );
              break;
          }
        }

        if (hasThinking || widget.msg.isThinkingActive) {
          // We pass the "isThinkingActive" state to the section
          // The section itself will handle the minimum duration logic and visibility
          // But we need to keep it in the tree if we want it to animate out gracefully or hold presence
          // However, for "minimum 1s", the widget needs to stay mounted.

          // If 'hasThinking' is true, it means there are thinking chunks (which we hide content of)
          // If 'isThinkingActive' from msg is true, we are generating thought.

          // We rely on ThinkingSection to decide whether to render nothing or the label
          children.insert(
            0,
            ThinkingSection(
              key: ValueKey('thinking_${widget.msg.hashCode}'),
              isThinkingActive: widget.msg.isThinkingActive,
            ),
          );
          if (widget.msg.isThinkingActive) {
            children.insert(1, const SizedBox(height: 8));
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

class ThinkingSection extends StatefulWidget {
  final bool isThinkingActive;

  const ThinkingSection({required this.isThinkingActive, super.key});

  @override
  State<ThinkingSection> createState() => _ThinkingSectionState();
}

class _ThinkingSectionState extends State<ThinkingSection> {
  bool _isVisible = false;
  Timer? _minDisplayTimer;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    if (widget.isThinkingActive) {
      _isVisible = true;
      _startTime = DateTime.now();
    }
  }

  @override
  void didUpdateWidget(ThinkingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isThinkingActive && !oldWidget.isThinkingActive) {
      // Started thinking
      _isVisible = true;
      _startTime = DateTime.now();
      _minDisplayTimer?.cancel();
    } else if (!widget.isThinkingActive && oldWidget.isThinkingActive) {
      // Stopped thinking. Check if we need to keep showing it.
      final duration = DateTime.now().difference(_startTime!);
      if (duration.inMilliseconds < 1000) {
        // Less than 1 second, keep showing until then
        final remaining = 1000 - duration.inMilliseconds;
        _minDisplayTimer = Timer(Duration(milliseconds: remaining), () {
          if (mounted) {
            setState(() {
              _isVisible = false;
            });
          }
        });
      } else {
        _isVisible = false;
      }
    }
  }

  @override
  void dispose() {
    _minDisplayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _AnimatedSearchingLabel(colorScheme: cs),
    );
  }
}

class _AnimatedSearchingLabel extends StatefulWidget {
  final ColorScheme colorScheme;

  const _AnimatedSearchingLabel({required this.colorScheme});

  @override
  State<_AnimatedSearchingLabel> createState() =>
      _AnimatedSearchingLabelState();
}

class _AnimatedSearchingLabelState extends State<_AnimatedSearchingLabel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _shimmerController = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.colorScheme.onSurface.withOpacity(0.3),
                widget.colorScheme.primary,
                widget.colorScheme.onSurface.withOpacity(0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(_shimmerController.value - 1.0, 0.0),
              end: Alignment(_shimmerController.value + 1.0, 0.0),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                BootstrapIcons.search,
                size: 14,
                color: widget.colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                'Searching...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                  color: widget.colorScheme.onSurface,
                ),
              ),
            ],
          ),
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
      if (mounted)
        setState(() {
          _copied = false;
        });
    });
  }

  final theme = {
    ...vs2015Theme,
    'root': (vs2015Theme['root'] as TextStyle).copyWith(
      backgroundColor: Colors.transparent,
    ),
  };
  String _getDisplayLanguage() =>
      widget.language.isEmpty ? "CODE" : widget.language.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width < 600 ? 10 : 12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: width < 600 ? 12 : 14,
              vertical: width < 600 ? 8 : 10,
            ),
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
                  size: width < 600 ? 14 : 16,
                  color: Colors.white.withOpacity(0.6),
                ),
                SizedBox(width: width < 600 ? 6 : 8),
                Text(
                  _getDisplayLanguage(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: width < 600 ? 11 : 12,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: width < 600 ? 8 : 10,
                        vertical: width < 600 ? 4 : 5,
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
                            _copied
                                ? Icons.check_rounded
                                : Icons.content_copy_rounded,
                            size: width < 600 ? 12 : 14,
                            color: _copied
                                ? Colors.green.shade300
                                : Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(width: width < 600 ? 4 : 6),
                          Text(
                            _copied ? 'Copied!' : 'Copy',
                            style: TextStyle(
                              color: _copied
                                  ? Colors.green.shade300
                                  : Colors.white.withOpacity(0.7),
                              fontSize: width < 600 ? 11 : 12,
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
          Container(
            color: const Color(0xFF0d1117),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                widget.code,
                language: widget.language,
                theme: theme,
                padding: EdgeInsets.all(width < 600 ? 12 : 14),
                textStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: width < 600 ? 13 : 14,
                  height: 1.5,
                  color: null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final List<_Chunk> _chunks = [];
  final StreamController<int> _updateController = StreamController.broadcast();
  bool _isThinkingActive = false;
  DateTime? _thinkingStartTime;
  double _thinkingDuration = 0.0;
  _ChatMessage._(this.role);
  factory _ChatMessage.fromPlain({
    required String role,
    required String plain,
  }) {
    final msg = _ChatMessage._(role);
    msg.updateFromText(plain);
    return msg;
  }
  factory _ChatMessage.emptyAssistant() => _ChatMessage._('assistant');
  void updateFromText(String fullText) {
    final wasThinking = _isThinkingActive;
    final parsed = parseTextToChunks(fullText);
    _chunks.clear();
    // FIXED: Uses _Span for empty chunk to prevent type error
    _chunks.addAll(
      parsed.isEmpty
          ? [
              _Chunk(const [_Span('', SpanType.plain)], ChunkType.plain),
            ]
          : parsed,
    );
    final hasOpenTag = _hasOpenThinkTag(fullText);
    if (hasOpenTag) {
      final lastOpenIndex = fullText.lastIndexOf('<search>');
      final lastCloseIndex = fullText.lastIndexOf('</search>');
      _isThinkingActive = lastCloseIndex < lastOpenIndex;
    } else {
      _isThinkingActive = false;
    }
    if (!wasThinking && _isThinkingActive) {
      _thinkingStartTime = DateTime.now();
      _thinkingDuration = 0.0;
    } else if (wasThinking &&
        !_isThinkingActive &&
        _thinkingStartTime != null) {
      final endTime = DateTime.now();
      _thinkingDuration =
          endTime.difference(_thinkingStartTime!).inMilliseconds / 1000.0;
      _thinkingStartTime = null;
    } else if (!_isThinkingActive && !wasThinking) {
      _thinkingStartTime = null;
    }
    _updateController.add(_chunks.length);
  }

  List<_Chunk> get chunks => _chunks;
  Stream<int> get updateStream => _updateController.stream;
  bool get isThinkingActive => _isThinkingActive;
  double get thinkingDuration => _thinkingDuration;
  void dispose() => _updateController.close();
}
