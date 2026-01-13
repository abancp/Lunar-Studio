import 'package:LunarStudio/src/ffi/llm_engine.dart';
import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:LunarStudio/src/features/chat/presentation/widgets/model_select_dropdown.dart';
import 'package:LunarStudio/src/features/settings/presentation/popup/settings_popup.dart';

class TopPanel extends StatefulWidget {
  final String selectedModel;
  final String loadedModel;
  final ValueChanged<String> onModelChange;
  final Future<void> Function() onLoadModel;
  final void Function() toggleShowLeftPanel;

  const TopPanel({
    super.key,
    required this.selectedModel,
    required this.onModelChange,
    required this.onLoadModel,
    required this.loadedModel,
    required this.toggleShowLeftPanel,
  });

  @override
  State<TopPanel> createState() => _TopPanelState();
}

class _TopPanelState extends State<TopPanel> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.symmetric(vertical: 4),
            constraints: const BoxConstraints(minWidth: 28),
            icon: Icon(
              BootstrapIcons.layout_sidebar,
              size: 16,
              color: cs.onSurface,
            ),
            onPressed: widget.toggleShowLeftPanel,
          ),

          // Center section
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 28,
                    child: ModelDropdown(
                      selectedModel: widget.selectedModel,
                      onSelect: widget.onModelChange,
                    ),
                  ),

                  const SizedBox(width: 8),

                  GestureDetector(
                    child: Opacity(
                      opacity: widget.selectedModel == "Select Model" ? 0.3 : 1,
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: widget.selectedModel == widget.loadedModel
                              ? Colors.transparent
                              : cs.primary,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.selectedModel == widget.loadedModel
                                ? cs.outline
                                : cs.primary,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.selectedModel == widget.loadedModel
                                  ? BootstrapIcons.stop_circle
                                  : BootstrapIcons.play_circle,
                              size: 12,
                              color: widget.selectedModel == widget.loadedModel
                                  ? cs.onSurface
                                  : cs.onPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.selectedModel == widget.loadedModel
                                  ? "Eject"
                                  : "Load",
                              style: TextStyle(
                                color:
                                    widget.selectedModel == widget.loadedModel
                                    ? cs.onSurface
                                    : cs.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    onTap: () {
                      widget.onLoadModel();
                    },
                  ),
                ],
              ),
            ),
          ),

          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28),
            icon: Icon(BootstrapIcons.gear, size: 16, color: cs.onSurface),
            onPressed: () async {
              List<Map<String, String>> ctx = [];
              try {
                ctx = await LLMEngine().getContext();
              } catch (_) {
                // Engine not ready or other error
              }

              if (context.mounted) {
                showSettingsPopup(context, ctx);
              }
            },
          ),
        ],
      ),
    );
  }
}
