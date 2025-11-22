import 'package:LunarStudio/src/features/chat/presentation/panels/left_panel.dart';
import 'package:LunarStudio/src/features/chat/presentation/panels/main_panel.dart';
import 'package:LunarStudio/src/features/chat/presentation/panels/top_panel.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String selectedModel = "Qwen Selected";

  void updateModel(String model) {
    if (model == "Import Model") {
      
    } else {
      setState(() {
        selectedModel = model;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TopPanel(selectedModel: selectedModel, onModelChange: updateModel),
          Expanded(
            child: Row(
              children: [
                // SizedBox(
                //   width: 240, // side panel width
                //   child: LeftPanel(),
                // ),
                Expanded(child: MainPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
