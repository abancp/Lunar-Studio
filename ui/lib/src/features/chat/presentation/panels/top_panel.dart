import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:LunarStudio/src/features/chat/presentation/widgets/model_select_dropdown.dart';

class TopPanel extends StatefulWidget {
  final String selectedModel;
  final ValueChanged<String> onModelChange;
  final Future<void> Function() onLoadModel;

  const TopPanel({
    super.key,
    required this.selectedModel,
    required this.onModelChange,
    required this.onLoadModel,
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
        border: Border(
          bottom: BorderSide(color: cs.outline, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28),
            icon: Icon(
              BootstrapIcons.layout_sidebar,
              size: 16,
              color: cs.onSurface,
            ),
            onPressed: () {},
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
                  child:  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: cs.outline, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(BootstrapIcons.eject,
                            size: 12, color: cs.onSurface),
                        const SizedBox(width: 4),
                        Text(
                          "Load",
                          style:
                              TextStyle(color: cs.onSurface, fontSize: 12),
                        ),
                      ],
                    ),
                    
                  ),
                  onTap:(){ 
                    widget.onLoadModel();
                  },
                 )
                ],
              ),
            ),
          ),

          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28),
            icon: Icon(
              BootstrapIcons.gear,
              size: 16,
              color: cs.onSurface,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
