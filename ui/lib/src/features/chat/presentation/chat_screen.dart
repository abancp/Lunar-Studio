import 'package:LunarStudio/src/features/chat/presentation/panels/left_panel.dart';
import 'package:LunarStudio/src/features/chat/presentation/panels/main_panel.dart';
import 'package:LunarStudio/src/features/chat/presentation/panels/top_panel.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TopPanel(),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 240, // side panel width
                  child: LeftPanel(),
                ),
                Expanded(
                  child: MainPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
