import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContextPopup extends StatefulWidget {
  final List<Map<String, String>> contextList;

  const ContextPopup({super.key, required this.contextList});

  @override
  State<ContextPopup> createState() => _ContextPopupState();
}

class _ContextPopupState extends State<ContextPopup> {
  late List<Map<String, String>> _filtered;
  int _selectedIndex = 0;
  String _query = '';
  bool _wrap = true;
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.contextList);
  }

  void _applyFilter(String q) {
    setState(() {
      _query = q;
      if (q.trim().isEmpty) {
        _filtered = List.from(widget.contextList);
      } else {
        final ql = q.toLowerCase();
        _filtered = widget.contextList.where((m) {
          final role = (m['role'] ?? '').toLowerCase();
          final msg = (m['message'] ?? '').toLowerCase();
          return role.contains(ql) || msg.contains(ql);
        }).toList();
      }
      _selectedIndex = _filtered.isEmpty ? -1 : 0;
    });
  }

  void _copySelected() {
    if (_selectedIndex < 0 || _selectedIndex >= _filtered.length) return;
    final msg = _filtered[_selectedIndex]['message'] ?? '';
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied message to clipboard')),
    );
  }

  void _exportAll() {
    final all = widget.contextList
        .map((m) => '[${m['role'] ?? 'role'}] ${m['message'] ?? ''}')
        .join('\n\n---\n\n');
    Clipboard.setData(ClipboardData(text: all));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exported all context to clipboard')),
    );
  }

  Widget _roleBadge(String role, ColorScheme cs) {
    final r = (role).toLowerCase();
    Color bg;
    switch (r) {
      case 'assistant':
        bg = cs.primary.withOpacity(0.16);
        break;
      case 'system':
        bg = cs.tertiary.withOpacity(0.16);
        break;
      case 'user':
      default:
        bg = cs.secondary.withOpacity(0.16);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Size limits
    const double maxDialogWidth = 1100;
    const double maxDialogHeight = 780;
    const double minDialogWidth = 340;
    const double minDialogHeight = 360;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        double dialogW = screenW < minDialogWidth
            ? screenW
            : (screenW > maxDialogWidth ? maxDialogWidth : screenW * 0.92);

        double dialogH = screenH < minDialogHeight
            ? screenH
            : (screenH > maxDialogHeight ? maxDialogHeight : screenH * 0.88);

        final safeMinW = screenW * 0.8 < minDialogWidth
            ? screenW * 0.8
            : minDialogWidth;

        final safeMinH = screenH * 0.8 < minDialogHeight
            ? screenH * 0.8
            : minDialogHeight;

        dialogW = dialogW < safeMinW ? safeMinW : dialogW;
        dialogH = dialogH < safeMinH ? safeMinH : dialogH;

        final isWide = dialogW > 720;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(6),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: safeMinW,
              maxWidth: dialogW,
              minHeight: safeMinH,
              maxHeight: dialogH,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'LLM Context (Debug)',
                        style: textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SelectableText(
                        'Entries: ${widget.contextList.length}',
                        style: textTheme.bodySmall,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Export all (copy to clipboard)',
                        icon: const Icon(Icons.download_outlined),
                        onPressed: _exportAll,
                      ),
                      IconButton(
                        tooltip: _wrap ? 'Disable wrap' : 'Enable wrap',
                        icon: Icon(_wrap ? Icons.wrap_text : Icons.code),
                        onPressed: () => setState(() => _wrap = !_wrap),
                      ),
                      IconButton(
                        tooltip: 'Decrease font',
                        icon: const Icon(Icons.remove),
                        onPressed: () => setState(() {
                          _fontSize = (_fontSize - 1).clamp(10.0, 28.0);
                        }),
                      ),
                      Text('${_fontSize.toInt()}', style: textTheme.bodySmall),
                      IconButton(
                        tooltip: 'Increase font',
                        icon: const Icon(Icons.add),
                        onPressed: () => setState(() {
                          _fontSize = (_fontSize + 1).clamp(10.0, 28.0);
                        }),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40, // define your row height here
                          child: TextField(
                            decoration: InputDecoration(
                              hintText:
                                  'Search role or message (regex not supported)',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: cs.outline),
                              ),
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear),
                                      onPressed: () => _applyFilter(''),
                                    )
                                  : null,
                            ),
                            onChanged: _applyFilter,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      SizedBox(
                        height: 40, // SAME height
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _filtered = List.from(widget.contextList);
                              _query = '';
                              _selectedIndex = _filtered.isEmpty ? -1 : 0;
                            });
                          },
                          icon: Icon(Icons.refresh, size: 16),
                          label: Text('Reset'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: isWide
                        ? Row(
                            children: [
                              Flexible(
                                flex: 4,
                                child: _buildListPanel(cs, textTheme),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                flex: 7,
                                child: _buildDetailPanel(cs, textTheme),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildListPanel(cs, textTheme),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                flex: 6,
                                child: _buildDetailPanel(cs, textTheme),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  //------------------------------- LEFT PANE -----------------------------------
  Widget _buildListPanel(ColorScheme cs, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.06),
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: _filtered.isEmpty
          ? Center(
              child: Text(
                'No entries match your query',
                style: textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) =>
                  Divider(color: cs.outline.withOpacity(0.2)),
              itemBuilder: (context, i) {
                final e = _filtered[i];
                final role = e['role'] ?? 'unknown';
                final message = e['message'] ?? '';
                final preview = message.length > 160
                    ? '${message.substring(0, 160)}…'
                    : message;

                final isSelected = i == _selectedIndex;

                return InkWell(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    decoration: isSelected
                        ? BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _roleBadge(role, cs),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preview,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium!.copyWith(
                                  fontSize: _fontSize,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(role, style: textTheme.bodySmall),
                                  const SizedBox(width: 8),
                                  if (e.containsKey('time'))
                                    Text(
                                      ' • ${e['time']}',
                                      style: textTheme.bodySmall,
                                    ),
                                  if (e.containsKey('meta')) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      ' • ${e['meta']}',
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: 'Copy message',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: message));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied message'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailPanel(ColorScheme cs, TextTheme textTheme) {
    if (_selectedIndex < 0 || _selectedIndex >= _filtered.length) {
      return Center(child: Text('No selection', style: textTheme.bodyLarge));
    }

    final entry = _filtered[_selectedIndex];
    final role = entry['role'] ?? '';
    final message = entry['message'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _roleBadge(role, cs),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  role.isEmpty ? 'Entry' : role,
                  style: textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy message',
                icon: const Icon(Icons.copy_outlined),
                onPressed: _copySelected,
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.02),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  message,
                  style: textTheme.bodyMedium!.copyWith(fontSize: _fontSize),
                  maxLines: _wrap ? null : 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              TextButton.icon(
                onPressed: _copySelected,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
              const Spacer(),
              Text(
                'Filtered: ${_filtered.length} / ${widget.contextList.length}',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Convenience helper
Future<void> showContextPopup(
  BuildContext ctx,
  List<Map<String, String>> entries,
) {
  return showDialog(
    context: ctx,
    builder: (_) => ContextPopup(contextList: entries),
  );
}
