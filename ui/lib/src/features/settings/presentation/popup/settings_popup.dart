import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:LunarStudio/src/features/settings/presentation/panels/context_settings.dart';

class SettingsPopup extends StatefulWidget {
  final List<Map<String, String>> contextList;

  const SettingsPopup({super.key, required this.contextList});

  @override
  State<SettingsPopup> createState() => _SettingsPopupState();
}

class _SettingsPopupState extends State<SettingsPopup> {
  int _selectedNavIndex = 0;

  final List<Map<String, dynamic>> _navItems = [
    {'icon': BootstrapIcons.journal_code, 'label': 'Context', 'id': 'context'},
    {'icon': BootstrapIcons.palette, 'label': 'Appearance', 'id': 'appearance'},
    {'icon': BootstrapIcons.gear, 'label': 'General', 'id': 'general'},
    // To add a new setting:
    // 1. Add a new item here: {'icon': IconData, 'label': 'Name', 'id': 'unique_id'}
    // 2. Add a new case in _buildContent() below matching the 'id' (by index or id logic)
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Size limits (similar to previous layout)
    const double maxDialogWidth = 1200;
    const double maxDialogHeight = 850;
    const double minDialogWidth = 600;
    const double minDialogHeight = 400;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        double dialogW = screenW * 0.9;
        double dialogH = screenH * 0.9;

        dialogW = dialogW.clamp(minDialogWidth, maxDialogWidth);
        dialogH = dialogH.clamp(minDialogHeight, maxDialogHeight);

        return Dialog(
          backgroundColor: cs.surface,
          elevation: 0,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outline.withOpacity(0.2)),
          ),
          child: Container(
            width: dialogW,
            height: dialogH,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                // Left Panel - Navigation
                Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.3),
                    border: Border(
                      right: BorderSide(color: cs.outline.withOpacity(0.2)),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(BootstrapIcons.sliders, color: cs.primary),
                            const SizedBox(width: 12),
                            Text(
                              'Settings',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Nav List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _navItems.length,
                          itemBuilder: (context, index) {
                            final item = _navItems[index];
                            final isSelected = _selectedNavIndex == index;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Material(
                                color: isSelected
                                    ? cs.primary.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () =>
                                      setState(() => _selectedNavIndex = index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item['icon'],
                                          size: 18,
                                          color: isSelected
                                              ? cs.primary
                                              : cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          item['label'],
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: isSelected
                                                ? cs.primary
                                                : cs.onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Footer / Version?
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'v1.0.0',
                          style: textTheme.labelSmall?.copyWith(
                            color: cs.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Panel - Content
                Expanded(
                  child: Column(
                    children: [
                      // Close button header
                      Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.all(8),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          splashRadius: 20,
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: _buildContent(cs),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(ColorScheme cs) {
    switch (_selectedNavIndex) {
      case 0: // Context
        return ContextSettings(contextList: widget.contextList);
      case 1: // Appearance
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                BootstrapIcons.palette,
                size: 48,
                color: cs.outline.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Appearance settings coming soon',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      case 2: // General
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                BootstrapIcons.gear,
                size: 48,
                color: cs.outline.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'General settings coming soon',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// Helper to show the popup
Future<void> showSettingsPopup(
  BuildContext context,
  List<Map<String, String>> contextList,
) {
  return showDialog(
    context: context,
    builder: (context) => SettingsPopup(contextList: contextList),
  );
}
