// lib/src/features/chat/presentation/panels/main_panel.dart
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:LunarStudio/src/ffi/llm_ffi.dart';

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

  bool modelInitialized = false;

  List<_ChatMessage> messages = [];

  @override
  void dispose() {
    controller.dispose();
    keyboardFocus.dispose();
    textFieldFocus.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // Load model once in background
  void _loadModelInBackground() async {
    await Isolate.spawn(_modelLoadEntry, null);
  }

  static void _modelLoadEntry(dynamic _) {
    LLMEngine().loadModel();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onSubmit() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    // First user message → load model now
    if (!modelInitialized) {
      modelInitialized = true;
      _loadModelInBackground();
    }

    setState(() {
      messages.add(_ChatMessage(role: "user", content: text));
    });

    controller.clear();
    _scrollToBottom();

    _runModelIsolate(text);
  }

  // Create isolate which runs LLMEngine.generate (blocking C++ call)
  void _runModelIsolate(String prompt) async {
    final receive = ReceivePort();
    final exitPort = ReceivePort();

    final isolate = await Isolate.spawn<_IsolateArgs>(
      _isolateEntry,
      _IsolateArgs(prompt, receive.sendPort),
      onExit: exitPort.sendPort,
      errorsAreFatal: false,
    );

    bool firstToken = true;

    final sub = receive.listen((dynamic token) {
      if (token is String) {
        setState(() {
          if (firstToken) {
            messages.add(_ChatMessage(role: "assistant", content: token));
            firstToken = false;
          } else {
            final last = messages.last;
            messages[messages.length - 1] =
                _ChatMessage(role: last.role, content: last.content + token);
          }
        });
        _scrollToBottom();
      }
    });

    exitPort.listen((_) {
      sub.cancel();
      receive.close();
      exitPort.close();
      isolate.kill(priority: Isolate.immediate);
    });
  }

  // Entry for LLM token streaming
  static void _isolateEntry(_IsolateArgs args) {
    final prompt = args.prompt;
    final sendPort = args.sendPort;

    // NO loadModel here → loaded earlier
    LLMEngine().generate(prompt, (tok) {
      sendPort.send(tok);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    double hPad = 16;
    double tPad = 10;
    double bPad = 14;

    if (width > 1200) {
      hPad = 32;
      bPad = 24;
    } else if (width > 1600) {
      hPad = 48;
      bPad = 32;
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
                final isUser = msg.role == "user";

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isUser ? cs.primary.withOpacity(0.16) : cs.surface,
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
            onKey: (event) {
              if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
                if (event.isShiftPressed) return;
                if (event is RawKeyDownEvent) _onSubmit();
              }
            },
            child: Container(
              padding: EdgeInsets.fromLTRB(hPad, tPad, hPad, bPad),
              color: Colors.transparent,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                            minLines: 1,
                            maxLines: 8,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(color: cs.onSurface),
                            decoration: InputDecoration(
                              hintText: "Send a message…",
                              hintStyle: TextStyle(
                                color: cs.onSurface.withOpacity(0.4),
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _onSubmit,
                          child: Container(
                            height: 34,
                            width: 34,
                            decoration: BoxDecoration(
                              color: cs.primary,
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
                      "Responses from AI may be incorrect.",
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
  _ChatMessage({required this.role, required this.content});
}

class _IsolateArgs {
  final String prompt;
  final SendPort sendPort;
  _IsolateArgs(this.prompt, this.sendPort);
}
