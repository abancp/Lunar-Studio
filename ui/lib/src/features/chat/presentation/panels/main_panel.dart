// lib/src/features/chat/presentation/panels/main_panel.dart

import 'dart:async';
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
  final List<_ChatMessage> messages = [];
  
  bool engineReady = false;
  bool isGenerating = false;
  
  // Batch updates for smoother rendering
  Timer? _scrollTimer;
  int _tokensSinceScroll = 0;

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
    super.dispose();
  }

  void _scrollToBottom() {
    _tokensSinceScroll++;
    
    // Batch scroll updates (every 3 tokens or 50ms)
    if (_tokensSinceScroll < 3) {
      _scrollTimer?.cancel();
      _scrollTimer = Timer(const Duration(milliseconds: 50), _performScroll);
      return;
    }
    
    _performScroll();
  }

  void _performScroll() {
    _tokensSinceScroll = 0;
    if (!mounted || !scrollController.hasClients) return;
    
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
  }

  void _onSubmit() {
    if (!engineReady || isGenerating) return;

    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(_ChatMessage(role: 'user', content: text));
      isGenerating = true;
    });
    
    controller.clear();
    _performScroll();
    _runLLM(text);
  }

  void _runLLM(String prompt) {
    // Add placeholder for streaming
    setState(() {
      messages.add(const _ChatMessage(role: 'assistant', content: ''));
    });
    
    final int index = messages.length - 1;
    final buffer = StringBuffer();

    LLMEngine().generate(prompt, (String tok) {
      if (!mounted) return;
      
      buffer.write(tok);
      
      // Update UI (Flutter will batch this automatically)
      setState(() {
        messages[index] = _ChatMessage(
          role: 'assistant',
          content: buffer.toString(),
        );
      });
      
      _scrollToBottom();
    }).then((_) {
      if (mounted) {
        setState(() => isGenerating = false);
        _performScroll();
      }
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        messages[index] = _ChatMessage(
          role: 'assistant',
          content: 'Error: $e',
        );
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
                final isUser = msg.role == 'user';
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser 
                        ? cs.primary.withOpacity(0.16) 
                        : cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(color: cs.onSurface),
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
                            style: TextStyle(color: cs.onSurface),
                            decoration: InputDecoration(
                              hintText: isGenerating 
                                ? 'Generating...' 
                                : 'Send a message…',
                              hintStyle: TextStyle(
                                color: cs.onSurface.withOpacity(0.4),
                              ),
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
                              color: isGenerating 
                                ? cs.primary.withOpacity(0.5)
                                : cs.primary,
                              borderRadius: BorderRadius.circular(8),
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

class _ChatMessage {
  final String role;
  final String content;

  const _ChatMessage({required this.role, required this.content});
}