import 'package:flutter/material.dart';
import 'package:LunarStudio/src/core/db/app_db.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.loadChats();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> newChat() async {
    final db = await AppDB.instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insert('chats', {
      'title': 'New Chat',
      'created_at': now,
      'updated_at': now,
    });

    await widget.loadChats();

    if (mounted) {
      setState(() {
        _selectedChatId = id;
      });
      widget.laodMessages(id);
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
      width: 260,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(color: cs.outline.withOpacity(0.5), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header with New Chat Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: SizedBox(
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: newChat,
                  borderRadius: BorderRadius.circular(12),
                  hoverColor: cs.primary.withOpacity(0.05),
                  splashColor: cs.primary.withOpacity(0.1),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cs.outline.withOpacity(0.8),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          BootstrapIcons.plus_lg,
                          color: cs.onSurface,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'New Chat',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
                          BootstrapIcons.chat_square,
                          size: 32,
                          color: cs.onSurface.withOpacity(0.2),
                        ),
                        const SizedBox(height: 12),
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
                : Theme(
                    data: Theme.of(context).copyWith(
                      scrollbarTheme: ScrollbarThemeData(
                        thumbVisibility: MaterialStateProperty.all(true),
                        thickness: MaterialStateProperty.all(4),
                        radius: const Radius.circular(10),
                        thumbColor: MaterialStateProperty.all(
                          cs.outline.withOpacity(0.3),
                        ),
                        minThumbLength: 48,
                      ),
                    ),
                    child: Scrollbar(
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
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  24,
                                  20,
                                  8,
                                ),
                                child: Text(
                                  groupName,
                                  style: TextStyle(
                                    color: cs.onSurface.withOpacity(0.4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              ...chats.map((chat) {
                                final chatId = chat['id'] as int;
                                final isSelected = _selectedChatId == chatId;

                                return _ChatListItem(
                                  chat: chat,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() => _selectedChatId = chatId);
                                    widget.laodMessages(chatId);
                                  },
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends StatefulWidget {
  final Map<String, dynamic> chat;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.chat,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutQuart,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? cs.primary.withOpacity(0.1)
                : _isHovered
                ? cs.onSurface.withOpacity(0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuart,
            style: TextStyle(
              color: widget.isSelected
                  ? cs.primary
                  : cs.onSurface.withOpacity(0.7),
              fontSize: 13.5,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.2,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
            child: Text(
              widget.chat['title'] ?? 'Untitled',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
