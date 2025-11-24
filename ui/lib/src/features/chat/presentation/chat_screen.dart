import 'dart:io';

import 'package:LunarStudio/src/core/db/app_db.dart';
import 'package:LunarStudio/src/features/chat/presentation/panels/left_panel.dart';
import 'package:LunarStudio/src/features/chat/presentation/panels/main_panel.dart';
import 'package:LunarStudio/src/features/chat/presentation/panels/top_panel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:LunarStudio/src/ffi/llm_engine.dart';
import 'package:motion_toast/motion_toast.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String selectedModel = "Select Model";
  bool importing = false;
  bool engineReady = false;
  String loadedModel = "";
  bool showLeftPanel = true;
  int chatId = -1;
  List<Map<String, dynamic>> chats = [];
  final mainPanelKey = GlobalKey<MainPanelState>();

  @override
  void initState() {
    super.initState();
    LLMEngine().init(
      "/home/abancp/Projects/Lunar-Studio/build/liblunarstudio.so",
    );
  }

  void toggleShowLeftPanel() {
    setState(() {
      showLeftPanel = !showLeftPanel;
    });
  }

  void setChatId(int id) {
    setState(() {
      chatId = id;
    });
  }

  Future<void> updateModel(String model) async {
    if (model == "Import Model") {
      try {
        importing = true;
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ["gguf"],
        );

        if (picked == null) return;
        final selectedFile = File(picked.files.single.path!);

        final dir = await getApplicationSupportDirectory();
        final modelDir = Directory("${dir.path}/models");

        if (!await modelDir.exists()) {
          await modelDir.create(recursive: true);
        }

        final fileName = p.basename(selectedFile.path);
        final destination = File("${modelDir.path}/$fileName");

        await selectedFile.copy(destination.path);

        setState(() {
          selectedModel = fileName;
        });
        importing = false;
      } on Exception catch (_) {
        if (!mounted) return;
        MotionToast.error(
          description: Text("Can't Import Model"),
        ).show(context);
        debugPrint("Error : Can't import model ");
      } finally {
        importing = false;
      }
    } else {
      setState(() {
        selectedModel = model;
      });
    }
  }

  Future<void> loadModel() async {
    try {
      if (selectedModel == "" || selectedModel == "Select Model") {
        MotionToast.info(
          description: Text("Select Model to Load"),
        ).show(context);
        return;
      }
      final dir = await getApplicationSupportDirectory();
      final modelDir = Directory("${dir.path}/models");

      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final fileName = p.basename(selectedModel);
      final destination = File("${modelDir.path}/$fileName");
      debugPrint("Loading Model from :");
      debugPrint(destination.path);
      await LLMEngine().load(destination.path);
      if (mounted) {
        MotionToast.success(
          description: Text("Model Loaded Successfully!"),
        ).show(context);
        setState(() {
          engineReady = true;
          loadedModel = selectedModel;
          debugPrint("engine ready : $engineReady");
        });
      }
    } catch (e) {
      //TODO : toast for evry error
      debugPrint('❌ Engine error: $e');
    }
  }

  Future<void> loadChats() async {
    final db = await AppDB.instance;

    final data = await db.query('chats', orderBy: 'updated_at DESC');

    setState(() => chats = data);
  }

  void addMessageToChat(
    String content,
    int chatId,
    String role,
    int seq,
    void Function(int) setChatId,
  ) async {
    final db = await AppDB.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    int id = chatId;
    if (chatId == -1) {
      id = await db.insert('chats', {
        'title': content.substring(
          0,
          content.length > 10 ? 10 : content.length,
        ),
        'created_at': now,
        'updated_at': now,
      });
      setChatId(id);
      loadChats();
    }

    await db.insert('messages', {
      'chat_id': id,
      'role': role,
      'content': content,
      'sequence': seq,
      'created_at': now,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TopPanel(
            selectedModel: selectedModel,
            onModelChange: updateModel,
            onLoadModel: loadModel,
            loadedModel: loadedModel,
            toggleShowLeftPanel: toggleShowLeftPanel,
          ),
          Expanded(
            child: Row(
              children: [
                showLeftPanel
                    ? SizedBox(
                        width: 240, // side panel width
                        child: LeftPanel(
                          chats: chats,
                          loadChats: loadChats,
                          laodMessages: (int id) {
                            mainPanelKey.currentState?.loadMessages(id);
                          },
                        ),
                      )
                    : SizedBox.shrink(),
                Expanded(
                  child: MainPanel(
                    key:mainPanelKey,
                    engineReady: engineReady,
                    chatId: chatId,
                    setChatId: setChatId,
                    loadedModel: loadedModel,
                    addMessageToChat: addMessageToChat,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
