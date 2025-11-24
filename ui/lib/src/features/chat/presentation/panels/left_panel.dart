import 'package:flutter/material.dart';
import 'package:LunarStudio/src/core/db/app_db.dart';

class LeftPanel extends StatefulWidget {
  final List<Map<String, dynamic>> chats;
  final Future<void> Function() loadChats;
  final void Function(int) laodMessages;

  const LeftPanel({
    super.key,
    required this.chats,
    required this.loadChats,
    required this.laodMessages,
  });

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  @override
  void initState() {
    super.initState();
    widget.loadChats();
  }

  Future<void> newChat() async {
    final db = await AppDB.instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('chats', {
      'title': 'New Chat',
      'created_at': now,
      'updated_at': now,
    });

    widget.loadChats();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(right: BorderSide(color: cs.outline, width: 1)),
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
              itemCount: widget.chats.length,
              itemBuilder: (ctx, i) {
                final chat = widget.chats[i];

                final updated = DateTime.fromMillisecondsSinceEpoch(
                  chat['updated_at'] as int,
                );

                return InkWell(
                  onTap: () {
                    debugPrint(chat['id'].toString());
                    widget.laodMessages(chat['id'] as int);
                  },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      chat['title'] ?? 'Untitled',
                      style: TextStyle(color: cs.onSurface, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
