import 'package:flutter/material.dart';
import 'package:LunarStudio/src/core/db/app_db.dart';

class LeftPanel extends StatefulWidget {
  const LeftPanel({super.key});

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  List<Map<String, dynamic>> chats = [];

  @override
  void initState() {
    super.initState();
    loadChats();
  }

  Future<void> loadChats() async {
    final db = await AppDB.instance;

    final data = await db.query(
      'chats',
      orderBy: 'updated_at DESC', // recent chats first
    );

    setState(() => chats = data);
  }

  Future<void> newChat() async {
    final db = await AppDB.instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('chats', {
      'title': 'New Chat',
      'created_at': now,
      'updated_at': now,
    });

    loadChats();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(color: cs.outline, width: 1),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: newChat,
              child: const Text("New Chat"),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: chats.length,
              itemBuilder: (ctx, i) {
                final chat = chats[i];

                final updated = DateTime.fromMillisecondsSinceEpoch(
                  chat['updated_at'] as int,
                );

                return Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    chat['title'] ?? 'Untitled',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
