import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContextSettings extends StatefulWidget {
  final List<Map<String, String>> contextList;

  const ContextSettings({super.key, required this.contextList});

  @override
  State<ContextSettings> createState() => _ContextSettingsState();
}

class _ContextSettingsState extends State<ContextSettings> {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // We decide if we want split view based on available width in the main panel
        final isWide = constraints.maxWidth > 720;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar
            Row(
              children: [
                Text(
                  'LLM Context',
                  style: textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.contextList.length} entries',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Export all',
                  icon: const Icon(Icons.download_outlined, size: 20),
                  onPressed: _exportAll,
                ),
                IconButton(
                  tooltip: _wrap ? 'Disable wrap' : 'Enable wrap',
                  icon: Icon(_wrap ? Icons.wrap_text : Icons.code, size: 20),
                  onPressed: () => setState(() => _wrap = !_wrap),
                ),
                IconButton(
                  tooltip: 'Decrease font',
                  icon: const Icon(Icons.remove, size: 20),
                  onPressed: () => setState(() {
                    _fontSize = (_fontSize - 1).clamp(10.0, 28.0);
                  }),
                ),
                SizedBox(
                  width: 24,
                  child: Center(
                    child: Text(
                      '${_fontSize.toInt()}',
                      style: textTheme.bodySmall,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Increase font',
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => setState(() {
                    _fontSize = (_fontSize + 1).clamp(10.0, 28.0);
                  }),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Search Bar
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search role or message...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: cs.outline.withOpacity(0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: cs.outline.withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: cs.primary),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => _applyFilter(''),
                              )
                            : null,
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: _applyFilter,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _filtered = List.from(widget.contextList);
                        _query = '';
                        _selectedIndex = _filtered.isEmpty ? -1 : 0;
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: cs.outline.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Main Content Area
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          flex: 4,
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
        );
      },
    );
  }

  Widget _buildListPanel(ColorScheme cs, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: _filtered.isEmpty
          ? Center(
              child: Text(
                'No entries found',
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: cs.outline.withOpacity(0.15),
              ),
              itemBuilder: (context, i) {
                final e = _filtered[i];
                final role = e['role'] ?? 'unknown';
                final message = e['message'] ?? '';
                final preview = message.length > 120
                    ? '${message.substring(0, 120)}…'
                    : message;

                final isSelected = i == _selectedIndex;

                return InkWell(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Container(
                    color: isSelected ? cs.primary.withOpacity(0.08) : null,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _roleBadge(role, cs),
                            const Spacer(),
                            if (e.containsKey('time'))
                              Text(
                                e['time']!,
                                style: textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
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
      return Center(
        child: Text(
          'Select an item to view details',
          style: textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    final entry = _filtered[_selectedIndex];
    final role = entry['role'] ?? '';
    final message = entry['message'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cs.outline.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                _roleBadge(role, cs),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Message Details',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy message',
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: _copySelected,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                message,
                style: textTheme.bodyMedium!.copyWith(
                  fontSize: _fontSize,
                  height: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
