import 'dart:io';

import 'package:LunarStudio/src/features/chat/presentation/panels/left_panel.dart';
import 'package:LunarStudio/src/features/chat/presentation/panels/main_panel.dart';
import 'package:LunarStudio/src/features/chat/presentation/panels/top_panel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:LunarStudio/src/ffi/llm_engine.dart';

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
        print("Copied successfully");
      } on Exception catch (_) {
        //TODO : Error toaster
        print("Error : Can't import model ");
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
        setState(() {
          engineReady = true;
          loadedModel = selectedModel;
          debugPrint("engine ready : $engineReady");
        });
      }
    } catch (e) {
      debugPrint('❌ Engine error: $e');
    }
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
                        child: LeftPanel(),
                      )
                    : SizedBox.shrink(),
                Expanded(
                  child: MainPanel(
                    engineReady: engineReady,
                    chatId: chatId,
                    setChatId: setChatId,
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
