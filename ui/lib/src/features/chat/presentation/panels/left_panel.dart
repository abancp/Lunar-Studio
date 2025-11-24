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

class _LeftPanelState extends State<LeftPanel>
    with SingleTickerProviderStateMixin {
  int? _selectedChatId;
  int? _hoveredChatId;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    widget.loadChats();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabController.dispose();
    super.dispose();
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

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}w ago';
    } else {
      return '${(diff.inDays / 30).floor()}mo ago';
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupChatsByDate() {
    final groups = <String, List<Map<String, dynamic>>>{
      'Today': [],
      'Yesterday': [],
      'Previous 7 Days': [],
      'Previous 30 Days': [],
      'Older': [],
    };

    final now = DateTime.now();
    for (final chat in widget.chats) {
      final updated = DateTime.fromMillisecondsSinceEpoch(
        chat['updated_at'] as int,
      );
      final diff = now.difference(updated);

      if (diff.inDays == 0) {
        groups['Today']!.add(chat);
      } else if (diff.inDays == 1) {
        groups['Yesterday']!.add(chat);
      } else if (diff.inDays < 7) {
        groups['Previous 7 Days']!.add(chat);
      } else if (diff.inDays < 30) {
        groups['Previous 30 Days']!.add(chat);
      } else {
        groups['Older']!.add(chat);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groupedChats = _groupChatsByDate();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(
            color: cs.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header with New Chat Button
          Container(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: newChat,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: cs.onPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'New Chat',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Chat List
          Expanded(
            child: widget.chats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: cs.outline.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No chats yet',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a new conversation',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: groupedChats.length,
                      itemBuilder: (ctx, groupIndex) {
                        final groupEntry = groupedChats.entries.elementAt(
                          groupIndex,
                        );
                        final groupName = groupEntry.key;
                        final chats = groupEntry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                groupName,
                                style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            ...chats.map((chat) {
                              final chatId = chat['id'] as int;
                              final isSelected = _selectedChatId == chatId;
                              final isHovered = _hoveredChatId == chatId;
                              final updated =
                                  DateTime.fromMillisecondsSinceEpoch(
                                    chat['updated_at'] as int,
                                  );

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: MouseRegion(
                                  onEnter: (_) {
                                    setState(() => _hoveredChatId = chatId);
                                  },
                                  onExit: (_) {
                                    setState(() => _hoveredChatId = null);
                                  },
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        setState(
                                          () => _selectedChatId = chatId,
                                        );
                                        debugPrint(chatId.toString());
                                        widget.laodMessages(chatId);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? cs.primary
                                              : isHovered
                                              ? cs.surfaceContainerHighest
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                chat['title'] ?? 'Untitled',
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? cs.onPrimary
                                                      : cs.onSurface,
                                                  fontSize: 13,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _getRelativeTime(updated),
                                              style: TextStyle(
                                                color: isSelected
                                                    ? cs.onPrimary.withOpacity(
                                                        0.7,
                                                      )
                                                    : cs.onSurface.withOpacity(
                                                        0.4,
                                                      ),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
